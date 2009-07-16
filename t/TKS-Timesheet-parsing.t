use strict;
use warnings;

use Test::More;
use File::Slurp;
use List::Util qw(sum);

plan tests => 16;

use_ok('TKS::Timesheet');

# Date tests
eval {
    my $f = TKS::Timesheet->from_file('t/dates.tks');
    is(ref $f, 'TKS::Timesheet', 'dates: created TKS::Timesheet object');
    is(scalar($f->entries), 4, 'dates: correct number of entries');
    is('2009-05-19 2009-05-18 2009-05-20 2009-05-17', join(' ', map { $_->{date} } $f->entries ), 'dates: dates parsed correctly, and in correct order');
    is('2009-05-17 2009-05-18 2009-05-19 2009-05-20', join(' ', sort map { $_->{date} } $f->entries ), 'dates: when post-sorted, are in correct order');
    my $as_string = $f->as_string;
    my @dates;
    foreach my $match ( $as_string =~ /\b(\d\d\d\d-\d\d-\d\d)\b/g ) {
        push @dates, $match;
    }
    is('2009-05-17 2009-05-18 2009-05-19 2009-05-20', join(' ', @dates), 'dates: as_string function outputs dates in correct order');
};

# Hours mode
eval {
    my $f = TKS::Timesheet->from_file('t/hours.tks');
    is(ref $f, 'TKS::Timesheet', 'hours: created TKS::Timesheet object');
    is(scalar($f->entries), 5, 'hours: correct number of entries');
    is($f->time, 6.5, 'hours: total time correct');
    is($f->filter_request(1)->time, 1.625, 'hours: WR 1 correct time');
    is($f->filter_request(2)->time, 2.875, 'hours: WR 2 correct time');
    is($f->filter_request(3)->time, 2    , 'hours: WR 3 correct time');
};

# No date specified
eval { TKS::Timesheet->from_file('t/no-date.tks') };
chomp $@;
is($@, 't/no-date.tks: line 4: Encountered timesheet entry before a date was specified', 'Error for no date specified reported correctly');

# No comment specified
eval { TKS::Timesheet->from_file('t/missing-comment.tks') };
chomp $@;
is($@, "t/missing-comment.tks: line 6: Failed to parse line\n1 1 ", 'Syntax errors correctly detected');

# Negative time
eval { TKS::Timesheet->from_file('t/negative-time.tks') };
chomp $@;
is($@, q{t/negative-time.tks: line 6: Start time can't be after end time in '12:30-1:15'}, 'Negative time is not allowed');

# Missing end time
eval { TKS::Timesheet->from_file('t/missing-endtime.tks') };
chomp $@;
is($@, q{t/missing-endtime.tks: line 4: Got end of file before a finish time in entry}, 'Missing end date reported correctly');
