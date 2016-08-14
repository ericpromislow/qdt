package QDT;

use strict;
use warnings;

# Return a tagged array of segments:
# Tags:
# TEXT
# LOGIC
# OUTPUT

use constant SEG_TEXT => 1;
use constant SEG_LOGIC => 2;
use constant SEG_OUTPUT => 3;

use constant TAG_NONE => 1;
use constant TAG_CODE => 2;
use constant TAG_EMIT => 3;
use constant TAG_COMMENT => 4;

use constant MSG_WARNING => 1;
use constant MSG_ERROR => 1;

use Exporter;
our @ISA = qw/Exporter/;
our @EXPORT_OK = qw/checkErrors parseDoc processOutput removeExtraWhiteSpace/;

our $verbose = 0;

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
		# Do nothing
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
	push @errors, [MSG_WARNING, "Unmatched <% at pos " . getPos($text, $lastTagStartPos)];
    }
    return [\@segments, \@errors];
}

sub removeExtraWhiteSpace {
    my $segments = shift;
    my $leadingWS = 0;
    my ($tagType, $text, $seg);
    my $i = 0;
    my $lim = 0+@$segments;
    while ($i < $lim) {
	$seg = $segments->[$i];
	if ($seg->[0] == SEG_TEXT) {
	    # Take the trailing whitespace and determine if we should squelch it
	    $text = $seg->[1];
	    if ($text =~ m{ \A (.* \n) [ \t]* \z}sx) {
		my $t1 = $1;
		my $res = shouldStripLogicalWhiteSpace($segments, $i + 1, $lim);
		if ($res) {
		    $seg->[1] = $t1;
		    my $j = $res->[0];
		    my $replaceText = $res->[1];
		    $segments->[$j][1] = $replaceText;
		}
	    }
	}
	$i += 1;
    }
    return $segments;
}

sub shouldStripLogicalWhiteSpace {
    my ($segments, $i, $lim) = @_;
    my ($tagType, $text, $seg);
    while ($i < $lim) {
	$seg = $segments->[$i];
	if (($tagType = $seg->[0]) == SEG_OUTPUT) {
	    return;
	} elsif ($tagType == SEG_TEXT) {
	    if (($text = $seg->[1]) =~ m{ \A [ \t]* \n (.*) }sx) {
		return [$i, $1];
	    } elsif ($text =~ /[^ \t]/) {
		return;
	    }
	    # Otherwise if it contains only tabs and spaces keep going
	}
	$i += 1;
    }
    # Otherwise if it's SEG_LOGIC just keep looking for the next thing.
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

sub processOutput {
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
	    "\nprint '$segText';"
	} else {
	    die "Unexpected segType of $segType" if $segType != SEG_OUTPUT;
	    "\nprint($segText);";
    }
    } @segments;
    print join("\n", map {"*>> $_"} @codeSegments) . "\n" if $verbose;
    my $code = join("", @codeSegments);
    dump_code($code) if $verbose;
    {
	no strict;
	eval($code);
    }
    if ($@) {
	die "Error in your code: $@";
    }
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