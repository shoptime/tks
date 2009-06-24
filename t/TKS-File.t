use strict;
use warnings;

use Test::More;
use File::Slurp;
use List::Util qw(sum);

plan tests => 15;

use_ok('TKS::File');

# Date tests
eval {
    my $f = TKS::File->new('t/dates.tks');
    is(ref $f, 'TKS::File', 'dates: created TKS::File object');
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
    my $f = TKS::File->new('t/hours.tks');
    is(ref $f, 'TKS::File', 'hours: created TKS::File object');
    is(scalar($f->entries), 5, 'hours: correct number of entries');
    is(sum(map { $_->{time} } $f->entries), 6.5, 'hours: total time correct');
    my $time_for = sub {
        my $wr = shift;
        sum(map { $_->{time} } grep { $_->{wr} == $wr } $f->entries)
    };
    is($time_for->(1), 1.625, 'hours: WR 1 correct time');
    is($time_for->(2), 2.875, 'hours: WR 2 correct time');
    is($time_for->(3), 2    , 'hours: WR 3 correct time');
};

# No date specified
eval { TKS::File->new('t/no-date.tks') };
chomp $@;
is($@, 't/no-date.tks:4 Encountered timesheet entry before a date was specified', 'Error for no date specified reported correctly');

# No comment specified
eval { TKS::File->new('t/missing-comment.tks') };
chomp $@;
is($@, 't/missing-comment.tks:6 Failed to parse line', 'Syntax errors correctly detected');

# Negative time
eval { TKS::File->new('t/negative-time.tks') };
chomp $@;
is($@, q{t/negative-time.tks:6 Start time can't be after end time in '12:30-1:15'}, 'Negative time is not allowed');

