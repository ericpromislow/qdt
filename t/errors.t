use strict;
use warnings;

use Test::More;

use lib "./lib";
use QDT;

$ENV{abc} = 1;

my $tests = [
    ["<%= \"abc\" . # blah \"def\" %>", qr{syntax error at \(eval \d+\) line 2, at EOF}],
    # Missing brace
    [<<_EOT_,
<% if ($ENV{abc}) { %>
oops, we commented-out the close-brace:
<% # } %>
_EOT_
qr{Missing right curly or square bracket}s],
    ];

plan tests => 2 * @$tests;
for my $test (@$tests) {
    my ($input, $expected, $verbose) = @$test;
    $QDT::verbose = $verbose;
    my $res = parseDoc($input);
    my $errors = $res->[1];
    is(0+@$errors, 0);
    $res = evaluateCode(generateCode(removeExtraWhiteSpace($res->[0])));
    if ($res->[1]) {
	like($res->[1], $expected);
    } else {
	fail("No error evaluating $input");
    }
	
}

