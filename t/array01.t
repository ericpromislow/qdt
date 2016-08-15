use strict;
use warnings;

use Test::More tests => 8;

use lib "./lib";
use QDT;

# Use ENV to create global variables.
$ENV{LDAP_ENABLED} = 1;
$ENV{LDAP_HOST} = "192.168.1.2";
$ENV{LDAP_PORT} = 1389;
$ENV{LDAP_PORT} = 1389;

my $doc = <<'_EOT_';

<% if (get_p("LDAP_ENABLED", 0)) { %>
ldap:
  ldapdebug: 'Ldap configured through UAA'
  profile:
    file: ldap/ldap-search-and-bind.xml
  ssl:
    skipverification: <%= get_p("LDAP_SKIP_VERIFICATION", "false") %>
  base:
    url: <%= get_p("LDAP_PROTOCOL", "ldap") %>://<%= get_p("LDAP_HOST", "localhost") %>:<%= get_p("LDAP_PORT", 389) %>
    <% if ($val = get_p("LDAP_EMAIL_DOMAINS", 0)) {
	$domains = eval($val); %>
    emailDomain:
      <% for my $domain (@$domains) { %>
    - <%= $domain %>
      <% } %>
    <% } %>
<% } %>
_EOT_

my $expected = <<'_EOT_';

ldap:
  ldapdebug: 'Ldap configured through UAA'
  profile:
    file: ldap/ldap-search-and-bind.xml
  ssl:
    skipverification: false
  base:
    url: ldap://192.168.1.2:1389
_EOT_

my $res = parseDoc($doc);
my $errors = $res->[1];
is(0+@$errors, 0);
$res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
is($res->[1], undef);
isnt(0+@{$res->[0]}, 0);
is(join("", @{$res->[0]}), $expected);

# Now set the email domains

$ENV{LDAP_EMAIL_DOMAINS} = '["angstrom", "securing"]';
$expected = <<'_EOT_';

ldap:
  ldapdebug: 'Ldap configured through UAA'
  profile:
    file: ldap/ldap-search-and-bind.xml
  ssl:
    skipverification: false
  base:
    url: ldap://192.168.1.2:1389
    emailDomain:
    - angstrom
    - securing
_EOT_

$res = parseDoc($doc);
$errors = $res->[1];
is(0+@$errors, 0);
$res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
is($res->[1], undef);
isnt(0+@{$res->[0]}, 0);
is(join("", @{$res->[0]}), $expected);


