use strict;
use warnings;

use Test::More;

use lib "./lib";
use QDT;

my $tests = [
    ["<% # show rest of line %>appears-1,<%= \"appears-2,\" %>\nappears-3",
     "appears-1,appears-2,\nappears-3"],
    ['<% $abc = "<\%"; %><%= $abc %>', "<%"],
    [q/<%= 'abc' . "def" . qq[ghi] . q[jkl] %>/, "abcdefghijkl"],
    ["<%= \"abc\" . # blah \n\"def\" %>", "abcdef" ],
    ];
plan tests => 3 * @$tests;
$QDT::verbose = 0;
for my $test (@$tests) {
    my ($input, $expected) = @$test;
    my $res = parseDoc($input);
    my $errors = $res->[1];
    is(0+@$errors, 0);
    $res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
    if ($res->[1]) {
	print "**** Compilation failure: $res->[1]\n";
	next;
    }
    is($res->[1], undef);
    is(join("", @{$res->[0]}), $expected);
}

