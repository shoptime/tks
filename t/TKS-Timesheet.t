use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 2;

use_ok('TKS::Timesheet');

my $timesheet = TKS::Timesheet->new();

is($timesheet->time, 0, 'Empty timesheet should return 0 time (not undef)');
