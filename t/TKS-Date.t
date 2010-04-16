use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 56;

use_ok('TKS::Date');

my $date = TKS::Date->new('2010-04-09..2010-04-15');
isnt($date, TKS::Date->new($date), 'Cloning produces new object');
is(join(',',$date->dates), join(',',TKS::Date->new($date)->dates), 'Cloning produces same date list');

isnt($date, $date->new($date), 'Cloning (via method) produces new object');
is(join(',',$date->dates), join(',',$date->new($date)->dates), 'Cloning (via method) produces same date list');

my $current_month = strftime('%B', localtime);
my $current_day   = strftime('%A', localtime);

my @tests = (
    {
        datespecs => ['today', 'tomorrow^1', 'today..tomorrow^1', 'today,tomorrow^1', $current_day, "today,$current_day"],
        expected_count => 1,
        expected_first => strftime('%F', localtime()),
        expected_last => strftime('%F', localtime()),
    },
    {
        datespecs => [qw(week^^ lastweek^ lastweek^1 nextweek^3 nextweek^^^)],
        expected_count => 7,
        expected_first => TKS::Date->new('week^2')->mindate,
        expected_last => TKS::Date->new('week^2')->maxdate,
    },
    {
        datespecs => [qw(month^^ lastmonth^ lastmonth^1 nextmonth^3 nextmonth^^^)],
        expected_first => TKS::Date->new('month^2')->mindate,
        expected_last => TKS::Date->new('month^2')->maxdate,
    },
    {
        datespecs => ["$current_day^"],
        expected_count => 1,
        expected_first => TKS::Date->new('today^7')->mindate,
        expected_last => TKS::Date->new('today^7')->maxdate,
    },
    {
        datespecs => ["$current_month"],
        expected_first => TKS::Date->new('month')->mindate,
        expected_last => TKS::Date->new('month')->maxdate,
    },
);

foreach my $test ( @tests ) {
    foreach my $datespec ( @{$test->{datespecs}} ) {
        if ( $test->{expected_count} ) {
            is(eval { TKS::Date->new($datespec)->dates }, $test->{expected_count}, "Count correct: $datespec");
        }
        is(eval { TKS::Date->new($datespec)->mindate }, $test->{expected_first}, "First date correct: $datespec");
        is(eval { TKS::Date->new($datespec)->maxdate }, $test->{expected_last}, "Last date correct: $datespec");
    }
}

eval { TKS::Date->new('abc') };
like($@, qr/^Unable to parse 'abc' as a date/, 'Invalid date "abc" causes error');

eval { TKS::Date->new('06/80/2009') };
like($@, qr{^Invalid date '06/80/2009'.*date out of range}, 'Invalid date "06/80/2009" causes error');

eval { TKS::Date->new('2010-04-09..2010-04-10..2010-04-11') };
like($@, qr{^Couldn't parse date component.*too many occurances of '\.\.'}, 'Too many .. occurances in range causes error');
