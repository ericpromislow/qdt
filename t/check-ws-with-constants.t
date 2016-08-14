use strict;
use warnings;

use Test::More tests => 4;

use lib "./lib";
use QDT;

my $doc = <<'_EOT_';
start:
<% if (1) { %>
  <% if (2) { %> # Visible comment here
    <% if (3) { %><%# shouldn't see this in the output%>
  - stuff
    <% } %>
  <% } %>
 <% } %>
  - end
_EOT_

#$QDT::verbose = 1;

my $res = parseDoc($doc);
my $errors = $res->[1];
is(0+@$errors, 0);
$res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
is($res->[1], undef);
isnt(0+@{$res->[0]}, 0);
is(join("", @{$res->[0]}), <<'_EOT_');
start:
   # Visible comment here
  - stuff
  - end
_EOT_

