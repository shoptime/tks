use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 8;

use_ok('TKS::Timesheet');

my $a = TKS::Timesheet->from_string("2009-06-03\n1 5 request\n2009-06-04\n2 6 request2");
my $b = TKS::Timesheet->from_string("2009-06-03\n2009-06-04\n2 6 request2");

#use Data::Dumper;
#print Dumper $a;
#print Dumper $b;

is($a->time, 11, 'Timesheet A - correct total');
is($b->time, 6, 'Timesheet B - correct total');

ok(scalar $a->mentioned_dates == 2 && grep(/^2009-06-03$/, $a->mentioned_dates) && grep(/^2009-06-04$/, $a->mentioned_dates), 'Timesheet A - correct dates detected');
ok(scalar $b->mentioned_dates == 2 && grep(/^2009-06-03$/, $b->mentioned_dates) && grep(/^2009-06-04$/, $b->mentioned_dates), 'Timesheet B - correct dates detected');
my $expected_output = "2009-06-03 # Wednesday\n#  Day mentioned only; no entries\n\n";
ok($b->as_string(0) =~ /\Q$expected_output\E/, 'Timesheet B - as_string lists empty day only');
my $diff_a = $a->diff($b);
my $diff_b = $b->diff($a);
#print $a->as_string(1);
#print $b->as_string(1);
#print Dumper ($a->dates);
#print Dumper ($b->dates);
#print Dumper $diff_a;
#print Dumper $diff_b;

is($a->diff($b)->time, -5, 'Timesheet A diff B - correct total');
is($b->diff($a)->time, 5 , 'Timesheet B diff A - correct total');

