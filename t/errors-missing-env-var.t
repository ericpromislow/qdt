use strict;
use warnings;

use Test::More tests => 2;

use lib "./lib";
use QDT;

my $input = '<%= get_p("gorniplatz") %>';
my $res = parseDoc($input);
my $errors = $res->[1];
is(0+@$errors, 0);
$res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
if ($res->[1]) {
    like($res->[1], qr{Undefined environment variable: gorniplatz at .*?QDT.pm line \d+});
} else {
    fail("No error evaluating $input");
}
