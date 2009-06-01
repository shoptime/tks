use strict;
use warnings;

use Test::More;

plan tests => 2;

use_ok('TKS::Timesheet');
my $ts = TKS::Timesheet->from_file('t/rounding.tks');
like($ts->as_string, qr/Total hours: 9\.67\b/, 'No rounding error present');
