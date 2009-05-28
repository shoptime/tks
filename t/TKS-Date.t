use strict;
use warnings;

use POSIX;
use Test::More;

plan tests => 38;

use_ok('TKS::Date');

my @tests = (
    {
        datespecs => [qw(today tomorrow^1 today..tomorrow^1 today,tomorrow^1)],
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
);

foreach my $test ( @tests ) {
    foreach my $datespec ( @{$test->{datespecs}} ) {
        if ( $test->{expected_count} ) {
            is(TKS::Date->new($datespec)->dates, $test->{expected_count}, "Count correct: $datespec");
        }
        is(TKS::Date->new($datespec)->mindate, $test->{expected_first}, "First date correct: $datespec");
        is(TKS::Date->new($datespec)->maxdate, $test->{expected_last}, "Last date correct: $datespec");
    }
}
