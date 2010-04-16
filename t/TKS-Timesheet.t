use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 13;

use_ok('TKS::Timesheet');

my $timesheet = TKS::Timesheet->new();

is($timesheet->time, 0, 'Empty timesheet should return 0 time (not undef)');
is($timesheet->as_string, "# no entries in this timesheet\n", 'Empty timesheet stringifies correctly');

my $a = TKS::Timesheet->from_file('t/dates.tks');
my $b = $a->clone;

isnt($a, $b, 'Clone creates a new object');
is($a->as_string, $b->as_string, 'Clone creates identical object');

is($a->size, $a->invert->size, 'Invert keeps same number of entries');
is($a->time, -$a->invert->time, 'Invert has total time inverse to original');

is($a->invert->negative_to_zero->time, 0, 'invert => negative_to_zero produces 0 time');

$a->addtimesheet($b);
is($a->time, $b->time * 2, 'Adding timesheet doubles time');
is($a->size, $b->size * 2, 'Adding timesheet doubles entries');
$a->subtimesheet($b);
is($a->time, $b->time, 'Subtracting timesheet gives correct time');
is($a->size, $b->size * 3, 'Subtracting timesheet correct entries');
$a = $a->compact;
is($a->size, $b->size, 'Subtracting timesheet correct entries, after compact');


