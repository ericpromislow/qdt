#!/usr/bin/env perl

package QDT;

use strict;
use warnings;

use constant SEG_TEXT => 1;
use constant SEG_LOGIC => 2;
use constant SEG_OUTPUT => 3;
use constant SEG_COMMENT => 4;

use constant TAG_NONE => 1;
use constant TAG_CODE => 2;
use constant TAG_EMIT => 3;
use constant TAG_COMMENT => 4;

use constant MSG_WARNING => 1;
use constant MSG_ERROR => 1;

use Exporter;
our @ISA = qw/Exporter/;
our @EXPORT = qw/checkErrors evaluateCode generateCode parseDoc removeExtraWhiteSpace/;

our $verbose = 0;

# Use this function in templates:
sub get_p {
    my $name = shift;
    my $default = shift;
    if (!defined $ENV{$name}) {
	return $default if (defined $default);
	die "Undefined environment variable: $name";
    }
    return $ENV{$name};
}


sub quoteEscape {
    my $s = shift;
    $s =~ s/\\/\\\\/g;
    $s =~ s/'/'\\/g;
    $s;
}

sub getLocn {
    my ($allText, $textPos) = @_;
    my $text = substr($allText, 0, $textPos);
    my $lastNL = rindex($text, "\n");
    my ($init, $rest);
    if ($text =~ m{\A(.*\n)([^\n]*)\z}sx) {
	$init = $1;
	$rest = $2;
    } else {
	$init = "";
	$rest = $text;
    }
    return sprintf("Line %d, column %d", 1 + ($init =~ tr/\n//), length($rest));
}

# The QDT templating language:
# <%...%>: logic
# <%# ... %>: comment - pulled out
# <%= ... -?%>: eval and emit -- trailing - squelches a newline
# <<%#%>% : emits a literal "<%"
# <<%#%># : emits a literal "<#"
# %> that isn't preceded by a <% is emitted as is
# Everything else is emitted as is.

# Returns a tagged array of pieces of text

sub parseDoc {
    my $text = shift;
    return [] if !$text;
    my @pieces = split(/(<%[=\#]?|-?%>)/, $text);

    my @segments = ();
    my $textPos = 0;
    my $t;
    my @errors = ();
    my $tagType = TAG_NONE;
    my $lastCode = "";
    my $lastTagStartPos;
    while (0+@pieces) {
	# First piece will always be text, could be empty
	$t = shift @pieces;
	if ($t =~ m{\A(-?)\%>\z}) {
	    if ($tagType == TAG_NONE) {
		push @segments, [SEG_TEXT, $t];
		push @errors, [MSG_WARNING, "Unmatched %> treated verbatim at " . getLocn];
	    } elsif (substr($t, 1, 0) eq '-' && 0+@pieces) {
		$pieces[0] =~ s{\A(\s*\n)}{};
		$textPos += length($1);
	    }
	    $tagType = TAG_NONE;
	} elsif ($t =~ m{\A<\%(.?)\z}) {
	    my $tagTypeChar = $1;
	    $lastTagStartPos = $textPos;
	    if (!$tagTypeChar) {
		$tagType = TAG_CODE;
	    } elsif ($tagTypeChar eq "#") {
		$tagType = TAG_COMMENT;
	    } elsif ($tagTypeChar eq "=") {
		$tagType = TAG_EMIT;
	    } else {
		die "Unexpected tag type char: $tagTypeChar";
	    }
	} else {
	    if ($tagType == TAG_COMMENT) {
		push @segments, [SEG_COMMENT, $t];
	    } elsif ($tagType == TAG_CODE) {
		push @segments, [SEG_LOGIC, $t];
	    } elsif ($tagType == TAG_EMIT) {
		$t =~ s{\A\s+}{};
		$t =~ s{\s+\z}{};
		push @segments, [SEG_OUTPUT, $t];
	    } elsif ($t) {
		push @segments, [SEG_TEXT, $t];
	    }
	}
	$textPos += length($t);
    }
    if ($tagType != TAG_NONE) {
	push @errors, [MSG_ERROR, "Unmatched <% at pos " . getLocn($text, $lastTagStartPos)];
    }
    return [\@segments, \@errors];
}

sub xp {
    map{sprintf("%s: %d", $_, ord $_) }split(//, shift);
}

=begin

removeExtraWhiteSpace - basically we want to remove the whitespace surrounding a <% ... %>
tag, including the trailing newline, if there's no other non-whitespace text next to it.
Because the parser isn't line-oriented, it's easier to walk through the array of segments
and use context to figure out what to do.  See tests like t/check-white-space.t to see
examples of how this works.

=cut

sub removeExtraWhiteSpace {
    my $segments = shift;
    my $leadingWS = 0;
    my ($tagType, $text, $seg, $res);
    my $i = 0;
    my $lim = 0+@$segments;
    while ($i < $lim) {
	$seg = $segments->[$i];
	if (($tagType = $seg->[0]) == SEG_TEXT) {
	    # Take the trailing whitespace and determine if we should squelch it
	    $text = stripTextBeforeLogic($seg->[1]);
	    if (defined $text) {
		$res = shouldStripLogicalWhiteSpace($segments, $i + 1, $lim);
		if ($res) {
		    $seg->[1] = $text;
		    my $j = $res->[0];
		    my $replaceText = $res->[1];
		    $segments->[$j][1] = $replaceText;
		    $i = $j - 1; # Skip ahead to the string we just adjusted
		}
	    }
	} elsif ($tagType == SEG_LOGIC || $tagType == SEG_COMMENT ) {
	    # We aren't following leading white-space, but does the sequence of code blocks end
	    # with squelchable trailing white-space or a newline?
	    $res = shouldStripLogicalWhiteSpace($segments, $i + 1, $lim);
	    if ($res) {
		my $j = $res->[0];
		my $replaceText = $res->[1];
		$segments->[$j][1] = $replaceText;
		$i = $j - 1; # Skip ahead to the string we just adjusted
	    }
	}
	$i += 1;
    }
    return $segments;
}

sub stripTextBeforeLogic {
    my $text = shift;
    if ($text =~ m{ \A ([ \t]+) \z}x ) {
	return "";
    } elsif ($text =~ m{ \A (.* \n) [ \t]* \z}sx) {
	return $1;
    }
    undef;
}

sub stripTextAfterLogic {
    my $text = shift;
    if ($text =~ m{ \A [ \t]+ \z }x) {
	return "";
    } elsif ($text =~ m{ \A [ \t]* \n (.*) }sx) {
	return $1;
    }
    undef;
}

sub shouldStripLogicalWhiteSpace {
    my ($segments, $i, $lim) = @_;
    my ($tagType, $text, $seg, $res);
    while ($i < $lim) {
	$seg = $segments->[$i];
	if (($tagType = $seg->[0]) == SEG_OUTPUT) {
	    return;
	} elsif ($tagType == SEG_TEXT) {
	    $res = stripTextAfterLogic(($text = $seg->[1]));
	    if (defined $res) {
		return [$i, $res];
	    } elsif ($text =~ /[^ \t]/) {
		return;
	    }
	    # Otherwise if it contains only tabs and spaces keep going
	}
	# Otherwise if it's SEG_LOGIC or SEG_COMMENT just keep looking for the next thing.
	$i += 1;
    }
    undef;
}

sub checkErrors {
    my $e = shift;
    my @errors = @$e;
    if (0+@errors) {
	my $sawError = 0;
	for (@errors) {
	    my $eType = $_->[0];
	    my $eStr = $_->[1];
	    my $eCode;
	    if ($eType == MSG_ERROR) {
		$eCode = "Error";
		$sawError = 1;
	    } else {
		$eCode = "Warning";
	    }
	    print STDERR "$eCode: $eStr\n";
	}
	exit 1 if $sawError;
    }
}

sub generateCode {
    my $res = shift;
    my @segments = @{$res};
    #print join("\n", map {">> @$_"} @segments) . "\n";
    my @codeSegments = map {
	my $segment = $_;
	#print "@$segment\n";
	my $segType = $segment->[0];
	my $segText = $segment->[1];
	if ($segType == SEG_LOGIC) {
	    $segText;
	} elsif ($segType == SEG_TEXT) {
	    $segText =~ s{\\}{\\\\}g;
	    $segText =~ s{'}{\\'}g;
	    "\n" . "push(\@__collector, '$segText');"
	} elsif ($segType == SEG_COMMENT) {
	    # Do nothing
	} else {
	    die "Unexpected segType of $segType" if $segType != SEG_OUTPUT;
	    "\n" . "push(\@__collector, $segText);"
    }
    } @segments;
    print join("\n", map {"*>> $_"} @codeSegments) . "\n" if $verbose;
    my $code = join("", @codeSegments);
    dump_code($code) if $verbose;
    return $code;
}

=begin

The emitted code is a mixture of Perl logic and updates to an array
of strings called "@__collector". This var should probably be put
in a package to make it harder for templates to collide with it, but
it's an unlikely enough name.

Returns a Go-like array, of either [nil, error-message] or [the contents
of the @__collector array, followed by nil.

=cut

sub evaluateCode {
    my $__code = shift;
    my @__collector;
    {
	no strict;
	eval($__code);
    }
    return $@ ? [undef, $@] : [\@__collector, undef];
}

sub dump_code {
    my $code = shift . "\n";
    my $i = 0;
    print "**************** CODE: \n";
    while ($code =~ m{([^\n]*?)\n}gx) {
	$i += 1;
	printf("%4d %s\n", $i, $1);
    }
    print "**************** \n";
}

1;
