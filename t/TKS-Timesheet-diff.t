use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 5;

use_ok('TKS::Timesheet');

my $a = TKS::Timesheet->from_string("2009-06-03\n61538 4.75 comment");
my $b = TKS::Timesheet->from_string("2009-06-03\n61538 4.50 comment");

is($a->time, 4.75, 'Timesheet A - correct total');
is($b->time, 4.50, 'Timesheet B - correct total');
is($a->diff($b)->time, -0.25, 'Timesheet A diff B - correct total');
is($b->diff($a)->time, 0.25 , 'Timesheet B diff A - correct total');
