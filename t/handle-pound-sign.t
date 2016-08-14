use strict;
use warnings;

use Test::More tests => 4;

use lib "./lib";
use QDT;

my $doc = <<'_EOT_';
start:
<% if (1) { %> # Visible comment here
  - stuff
 <% } %>
  - end
_EOT_

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

