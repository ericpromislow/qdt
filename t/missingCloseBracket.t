use strict;
use warnings;

use Test::More tests => 3;

use lib "./lib";
use QDT qw/parseDoc/;

my $doc = <<_EOT_;
Missing close-delim: <%= "blah"
_EOT_

my $res = parseDoc($doc);
my $errors = $res->[1];
is(0+@$errors, 1, "should be 1 error");
is($errors->[0][0], QDT::MSG_ERROR, "fault type");
is($errors->[0][1], "Unmatched <% at pos Line 1, column " . index($doc, "<%"), "e msg");

