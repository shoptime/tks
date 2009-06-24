use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 2;

use_ok('TKS::Timesheet');

my $ts = TKS::Timesheet->from_string("2009-06-03\n61538 1.00 comment\n61538 2.00 [review] comment\n61538 4.00 [review] comment\n61538 8.00 comment");

is(scalar($ts->compact->entries), 2, 'Compact works correctly');
