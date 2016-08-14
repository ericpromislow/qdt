use strict;
use warnings;

use Test::More tests => 4;

use lib "./lib";
use QDT;

# Use ENV to create global variables.
$ENV{dog} = "woof";
my $doc = '<%= $ENV{dog} %>';

my $res = parseDoc($doc);
my $errors = $res->[1];
is(0+@$errors, 0);
$res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
is($res->[1], undef);
is(0+@{$res->[0]}, 1);
is($res->[0][0], "woof");

