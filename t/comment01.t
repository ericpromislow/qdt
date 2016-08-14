use strict;
use warnings;

use Test::More tests => 4;

use lib "./lib";
use QDT;

my $doc = "v1: [<<%#%>%] v2: [%<%#%>>]\n";

my $res = parseDoc($doc);
my $errors = $res->[1];
is(0+@$errors, 0);
$res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
is($res->[1], undef);
isnt(0+@{$res->[0]}, 0);
is(join("", @{$res->[0]}), "v1: [<%] v2: [%>]\n");

