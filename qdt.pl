#!/usr/bin/env perl

# qdt.pl -- quick-and-dirty templater

package main;

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

sub processOutput {
    my $res = shift;
    my @segments = @{$res->[0]};
    my @errors = @{$res->[1]};
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
	return if $sawError;
    }
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
    #print join("\n", map {"*>> $_"} @codeSegments) . "\n";
    my $code = join("", @codeSegments);
    dump_code($code);
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

processOutput(parseDoc(<<'_EOF_'));
<%
sub ep {
  my ($name, $default) = @_;
  if (defined $ENV{$name}) {
    return $ENV{$name}
  } elsif (defined $default) {
    return $default;
  } else {
    print STDERR "No value for enviroment var $name\n";
    return "** $name **";
  }
}

%>

spring_profiles: postgresql<% if (ep("LDAP_ENABLED", 0)) { %>
database:
  driverClassName: 'org.\'postgresql.Driver'

  url: jdbc:postgresql://<%= ep("DB_ADDR") %>:<%= ep 'DB_PORT' %>/<%=ep("DB_ENV_DB", "uaa") %>?ssl=true&sslmode=verify-full
<% } else {# LDAP_ENABLED check %>
chuck:
   yambo: no ldap here : <%= $ENV{HOME} %>
<% } # LDAP_ENABLED check %>

oauth:
  clients:
    things: 33

array_here:
   bink: 3
   <% if ($val = ep("LIST", 0)) {
     $val = eval($val);
     if ($@) {
       print STDERR "Error eval'ing var LIST => $val: $@\n";
     } else { %>
   list:
       <% for $x (@$val) { -%>
     - '<%= quoteEscape($x) %>'
       <% } -%>
     <% } # end if error %>
   <% } # end if list %>

 <% if ($val = ep("HASH", 0)) { %>
hash_here:
    bink: 4
    <%
    $val = eval($val);
    if ($@) {
      print STDERR "Error eval'ing var LIST => $val: $@\n";
    } else { %>
    stuff:
      <% while( ($k, $v) = each %$val) { %>
       <%= $k %>: '<%= quoteEscape($v) %>'
      <% } %>
    <% } %>
<% } %>

_EOF_
