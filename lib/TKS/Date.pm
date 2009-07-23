# Copyright (C) 2009 Catalyst IT Ltd (http://www.catalyst.net.nz)
#
# This file is distributed under the same terms as tks itself.
package TKS::Date;

use strict;
use warnings;
use POSIX;
use List::Util qw(maxstr minstr);
use List::MoreUtils qw(uniq);
use Date::Calc qw(Add_Delta_Days Add_Delta_YM Days_in_Month Mktime);
use UNIVERSAL;

my %month_for;

foreach my $month ( 1..12 ) {
    my $month_name = strftime('%B', localtime(Mktime(2009, $month, 1, 0, 0, 0)));
    $month_for{lc $month_name} = sprintf('%02d', $month);
}

sub new {
    my ($self, $datespec) = @_;

    if ( UNIVERSAL::isa($datespec, __PACKAGE__) ) {
        return $datespec->clone;
    }

    my $class = ref $self || $self;

    $self = bless {}, $class;

    $self->{dates} = [];
    $self->{dateshash} = {};

    $self->add_datespec($datespec);

    return $self;
}

sub dates {
    my ($self) = @_;

    return @{$self->{dates}};
}

sub mindate {
    my ($self) = @_;

    return $self->{dates}[0];
}

sub maxdate {
    my ($self) = @_;

    return $self->{dates}[-1];
}

sub contains {
    my ($self, $tksdate) = @_;

    $tksdate = $self->new($tksdate) unless UNIVERSAL::isa($tksdate, __PACKAGE__);

    foreach my $date ( $tksdate->dates ) {
        return unless exists $self->{dateshash}{$date};
    }

    return 1;
}

sub add_datespec {
    my ($self, $datespec) = @_;

    $self->{dates} = [ sort(uniq(@{$self->{dates}}, $self->parse_datespec($datespec))) ];
    $self->{dateshash} = { map { $_ => 1 } @{$self->{dates}} };
}

sub clone {
    my ($self) = @_;

    my $newobj = $self->new();

    $newobj->{dates} = [ @{$self->{dates}} ];
    $newobj->{dateshash} = { map { $_ => 1 } @{$self->{dates}} };

    return $newobj;
}

sub parse_datespec {
    my ($self, $datespec) = @_;

    return () unless $datespec;

    my @dates;
    my @components = split /\s*,\s*/, $datespec;

    foreach my $component ( @components ) {
        my @range = split /\s*\.\.\s*/, $component;
        if ( @range == 1 ) {
            push @dates, $self->_parse_datecomponent($range[0])
        }
        elsif ( @range == 2 ) {
            push @dates, $self->_make_range(@range);
        }
        else {
            die "Couldn't parse date component '$component': too many occurances of '..'";
        }
    }

    return uniq(sort(@dates));
}

sub _make_range {
    my ($self, $start, $end) = @_;
    $start = minstr $self->_parse_datecomponent($start);
    $end = maxstr $self->_parse_datecomponent($end);

    die "Invalid range '$start .. $end', can't have end before start" unless $start le $end;

    my @dates = ($start);

    while ( $start ne $end ) {
        $start = $self->_date(1, $start);
        push @dates, $start;
    }

    return @dates;
}

sub _parse_datecomponent {
    my ($self, $component) = @_;

    if ( $component =~ m{ \A \d\d\d\d - \d\d - \d\d \z }xms ) {
        return $component;
    }

    if ( $component =~ m{ \A ( \d\d\d\d )  / ( \d\d ) / ( \d\d ) \z }xms ) {
        return "$1-$2-$3";
    }

    if ( $component =~ m{ \A ( \d\d )  / ( \d\d ) / ( \d\d (?: \d\d )?) \z }xms ) {
        my $year = $3;
        if ( length($year) == 2 ) {
            $year += 2000;
        }
        return "$year-$2-$1";
    }

    # Day stuff
    if ( $component =~ m{ \A (day|today|yesterday|tomorrow) (?: ( \^ ) ( \d* ) | ( \^+ ) )? \z }ixms ) {
        my $days_ago = 0;
        if ( $2 ) {
            $days_ago = $3 || 1;
        }
        if ( $4 ) {
            $days_ago = length($4);
        }
        $days_ago++ if lc $1 eq 'yesterday';
        $days_ago-- if lc $1 eq 'tomorrow';
        return $self->_date(-$days_ago);
    }

    # Week stuff
    if ( $component =~ m{ \A (week|thisweek|lastweek|nextweek) (?: ( \^ ) ( \d* ) | ( \^+ ) )? \z }ixms ) {
        my $weeks_ago = 0;
        if ( $2 ) {
            $weeks_ago = $3 || 1;
        }
        if ( $4 ) {
            $weeks_ago = length($4);
        }
        $weeks_ago++ if lc $1 eq 'lastweek';
        $weeks_ago-- if lc $1 eq 'nextweek';
        my $week_start = $self->_date( -strftime('%u',localtime) + 1 - ( 7 * $weeks_ago ) );
        return $self->_make_range($week_start, $self->_date(+6, $week_start));
    }

    # Month stuff
    if ( $component =~ m{ \A (month|thismonth|lastmonth|nextmonth) (?: ( \^ ) ( \d* ) | ( \^+ ) )? \z }ixms ) {
        my $months_ago = 0;
        if ( $2 ) {
            $months_ago = $3 || 1;
        }
        if ( $4 ) {
            $months_ago = length($4);
        }
        $months_ago++ if lc $1 eq 'lastmonth';
        $months_ago-- if lc $1 eq 'nextmonth';

        my $month_start = $self->_date( -strftime('%d',localtime) + 1 );
        $month_start = sprintf('%04d-%02d-%02d', Add_Delta_YM($self->_date_parts($month_start), 0, -$months_ago));
        return $self->_make_range($month_start, $self->_date(Days_in_Month(($self->_date_parts($month_start))[0..1])-1, $month_start));
    }

    # Days by locale day name
    if ( $component =~ m{ \A (\w+) ( \^ \d* | \^+ )? \z }ixms ) {
        my @dates = $self->new('week' . ($2 || '' ))->dates;
        my @result = ();
        foreach my $date ( @dates ) {
            my $day_name = strftime('%A', localtime(Mktime(split('-',$date), 0, 0, 0)));
            push @result, $date if lc $1 eq lc $day_name;
        }
        return @result if @result;
    }

    # Months by locale month name
    if ( $component =~ m{ \A (\w+) (?: ( \^ ) ( \d* ) | ( \^+ ) )? \z }ixms and exists $month_for{lc $1} ) {
        my $years_ago = 0;
        if ( $2 ) {
            $years_ago = $3 || 1;
        }
        if ( $4 ) {
            $years_ago = length($4);
        }
        my $month_start = sprintf('%04d-%02d-01', strftime('%Y', localtime) - $years_ago, $month_for{lc $1});
        return $self->_make_range($month_start, $self->_date(Days_in_Month(($self->_date_parts($month_start))[0..1])-1, $month_start));
    }

    die "Unable to parse '$component' as a date";
}



sub _date {
    my ($self, $diff, $date) = @_;

    $date ||= strftime('%F', localtime);

    if ( $diff ) {
        return sprintf('%04d-%02d-%02d', Add_Delta_Days($self->_date_parts($date), $diff));
    }

    return $date;
}

sub _date_parts {
    my ($self, $date) = @_;

    my @date_parts = $date =~ m{ \A ( \d\d\d\d ) - ( \d\d ) - ( \d\d ) \z }xms;

    return @date_parts;
}


1;
