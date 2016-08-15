use strict;
use warnings;

use Test::More tests => 4;

use lib "./lib";
use QDT;

my $doc = <<'_EOT_';
<%
sub emitCompoundObject {
    if (0+(@_) < 3) {
	my $msg = "$0: dev-postgresql.yml: emitCompoundObject: Not enough args: @_";
	print STDERR "$msg\n";
	die $msg;
    }
    my ($envVar, $ws, $header) = @_;
    my $sval = get_p($envVar, 0);
    return "" if !$sval;
    my $val = eval($sval);
    die "$0: dev-postgresql.yml: $@" if $@;
    my $valType = ref $val;
    # The header is already preceded by the right amount of white-space from the template.
    my $lines = ["$header:"];
    if ($valType =~ /^ARRAY/) {
	push(@$lines, "\n");
	emitArray($val, $ws, $lines);
    } elsif ($valType =~ /^HASH/) {
	push(@$lines, "\n");
	emitHash($val, "  $ws", $lines);
    } else {
       push(@$lines, " $val");
    }
    # And pull the last newline off
    chomp($lines->[$#$lines]);
    return join("", @$lines);
}

sub emitCompoundObjectFromVar {
    my ($val, $ws, $lines) = @_;
    my $valType = ref $val;
    if ($valType =~ /^ARRAY/) {
	emitArray($val, $ws, $lines);
    } elsif ($valType =~ /^HASH/) {
	emitHash($val, "  $ws", $lines);
    } else {
       push(@$lines, "$ws$val\n");
    }
    return $t;
}

sub emitArray {
    my ($vals, $ws, $lines) = @_;
    foreach my $val (@$vals) {
	my $valType = ref $val;
	if ($valType =~ /^ARRAY/) {
	    push(@$lines, "$ws-\n");
	    emitArray($val, "  $ws", $lines);
	} elsif ($valType =~ /^HASH/) {
	    push(@$lines, "$ws-\n");
	    emitHash($val, "  $ws", $lines);
	} else {
	    push(@$lines, "$ws- $val\n");
	}
    }
}

sub emitHash {
    my ($hash, $ws, $lines) = @_;
    # Sorting the keys makes it easier to test.
    my @keys = sort keys %$hash;
    foreach my $k (@keys) {
        my $v = $hash->{$k};
	if (ref $v) {
	    push(@$lines, "$ws$k:\n");
	    emitCompoundObjectFromVar($v, "$ws", $lines);
	} else {
	    push(@$lines, "$ws$k: $v\n");
	}
    }
}
%>
ldap:
  base:
    referral: <%= get_p("LDAP_REFERRAL", "follow") %>
    <%= emitCompoundObject("LDAP_EMAIL_DOMAIN", "    ", "emailDomain") %>
    <%= emitCompoundObject("LDAP_EXTERNAL_GROUPS_WHITE_LIST", "    ", "externalGroupsWhitelist") %>
    <%= emitCompoundObject("LDAP_ATTRIBUTE_MAPPINGS", "    ", "attributeMappings") %>
    end: stop
_EOT_

my $expected = <<'_EOT_';
ldap:
  base:
    referral: follow
    emailDomain:
    - fish1.com
    - fish2.com
    
    attributeMappings:
      array1:
      - 1
      - 2
      - 3
      -
        can: we
        do: nested
        hashes: ?
      family_name: chic
      given_name: joe
      phone_number: 123-4567
      user.attribute.name-of-attribute-in-uaa-id-token: name-of-attribute-in-ldap-record
    end: stop
_EOT_

$ENV{LDAP_EMAIL_DOMAIN} = "['fish1.com', 'fish2.com']";
$ENV{LDAP_ATTRIBUTE_MAPPINGS} = '{given_name => "joe", family_name=>"chic", phone_number => "123-4567","user.attribute.name-of-attribute-in-uaa-id-token" => "name-of-attribute-in-ldap-record", "array1" => [1, 2, 3, {"can" => "we", "do" => "nested", "hashes" => "?"}],  }';

my $res = parseDoc($doc);
my $errors = $res->[1];
is(0+@$errors, 0);
$res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
is($res->[1], undef);
isnt(0+@{$res->[0]}, 0);
is(join("", @{$res->[0]}), $expected);

