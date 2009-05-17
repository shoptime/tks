package TKS::File;

use strict;
use warnings;
use Carp;
use POSIX;
use File::Slurp;

sub new {
    my ( $self, $filename ) = @_;

    my $class = ref $self || $self;
    $self = bless {}, $class;

    die 'Must specify a filename' unless $filename;
    die "Cannot read file: $filename" unless -r $filename;

    $self->{filename} = $filename;

    @{$self->{filedata}} = read_file($filename);

    @{$self->{entries}} = $self->parse_file();

    return $self;
}

sub entries {
    my ($self) = @_;

    return @{$self->{entries}};
}

sub as_string {
    my ($self) = @_;

    my $output = '';
    my $date;

    foreach my $entry ( sort { $a->{date} cmp $b->{date} or $a->{wr} <=> $b->{wr} } $self->entries ) {
        unless ( $date and $date eq $entry->{date} ) {
            $output .= "\n$entry->{date}\n\n";
            $date = $entry->{date};
        }
        $output .= sprintf "%-5d  %5.2f  %s\n", $entry->{wr}, $entry->{time}, $entry->{comment};
    };
    $output .= "\n";
    return $output;
}

sub parse_file {
    my ($self) = @_;

    $self->{parse_date} = undef;
    $self->{parse_last_entry} = undef;

    my @entries;

    $self->{parse_line} = 0;
    foreach my $line ( @{$self->{filedata}} ) {
        $self->{parse_line}++;

        my $entry = $self->parse_line($line);

        next unless $entry;

        $self->{parse_last_entry}->{next_entry} = $entry if $self->{parse_last_entry};
        push @entries, $entry;
        $self->{parse_last_entry} = $entry;
    }

    # Resolve end times where appropriate
    foreach my $entry ( @entries ) {
        if ( $entry->{incomplete} ) {
            unless ( $entry->{date} eq $entry->{next_entry}{date} ) {
                $self->parse_fail('Got a date before a finish time in entry', $entry->{line});
            }
            unless ( $entry->{next_entry}{start} ) {
                $self->parse_fail('Failed to find a finish time for entry', $entry->{line});
            }
            $entry->{time} = $self->timediff($entry->{start}, $entry->{next_entry}{start});
        }
        delete $entry->{next_entry};
        delete $entry->{incomplete};
        delete $entry->{start};
        delete $entry->{end};
    }

    return @entries;
}

sub parse_line {
    my ($self, $line) = @_;

    my $result = {
        date => $self->{parse_date},
        line => $self->{parse_line},
    };

    # yyyy-mm-dd or yyyy/mm/dd
    if ( $line =~ m{ \A ( \d{4} ) ( [/-] ) ( \d{2} ) \2 ( \d{2} ) \b \s* (?: \# .* )? \z }xms ) {
        $self->{parse_date} = strftime('%F', 0, 0, 0, $4, $3 - 1, $1 - 1900);
        return;
    }
    if (
        $line =~    m{ \A ( \d+ ) / ( \d+ ) / ( \d\d (?:\d\d)? ) \b \s* (?: \# .* )? \z }xms # dd/mm/yy or dd/mm/yyyy
    ) {
        $self->{parse_date} = strftime('%F', 0, 0, 0, $1, $2 - 1, $3 >= 100 ? $3 - 1900 : $3 + 100);
        return;
    }

    if ( $line =~ m{
            \A
            ( \d+ | [a-zA-Z0-9_-]+ ) \s+  # Work request number OR alias
            ( \d+ | \d* \. \d+ )     \s+  # Time in integer or decimal
            ( \S .* )                        # Work description
            \z
        }xms ) {
        $result->{wr}      = $1;
        $result->{time}    = $2;
        $result->{comment} = $3;
        chomp $result->{comment};
    }

    if ( $line =~ m{
            \A
            ( \d+ | [a-zA-Z0-9_-]+ )              \s+ # Work request number OR alias
            ( \d\d?:?\d\d (?: \- \d\d?:?\d\d )? ) \s+ # Time specified in 24 hour time
            ( \S .* )                                    # Work description
            \z
        }xms ) {
        $result->{wr}      = $1;
        $result->{comment} = $3;
        chomp $result->{comment};

        my $time = $2;

        # If we have a start-to-end formatted time
        if ( $time =~ m/-/ ) {
            my ($start, $end) = split(/-/, $time);
            $result->{time} = $self->timediff($start, $end);
            $result->{start} = $start;
            $result->{end} = $end;
        }
        else {
            $result->{start} = $time;
            $result->{incomplete} = 1;
        }

    }

    if ( $result->{wr} ) {
        unless ( $result->{date} ) {
            $self->parse_fail('Encountered timesheet entry before a date was specified');
        }
        unless ( $result->{time} or $result->{incomplete} ) {
            $self->parse_fail('Failed to calculate time');
        }
        return $result;
    }

    # Skip "blank" lines
    return if $line =~ m{ \A \s* (?: \# .* )? \z }xms;

    $self->parse_fail('Failed to parse line');
}

sub timediff {
    my ($self, $start, $end, $line) = @_;

    $line ||= $self->{parse_line};

    my ($start_hour, $start_minute) = $start =~ m{ \A (\d\d?) :? (\d\d) \z }xms;

    $self->parse_fail("Invalid time format '$start'") unless $start_hour and $start_minute;

    my ($end_hour, $end_minute) = $end =~ m{ \A (\d\d?) :? (\d\d) \z }xms;

    $self->parse_fail("Invalid time format '$end'") unless $end_hour and $end_minute;

    my $minutes_start = $start_hour * 60 + $start_minute;
    my $minutes_end = $end_hour * 60 + $end_minute;

    $self->parse_fail("Start time can't be after end time in '$start-$end'") if $minutes_start > $minutes_end;

    return ( $minutes_end - $minutes_start ) / 60;
}

sub parse_fail {
    my ($self, $message, $line) = @_;

    $line ||= $self->{parse_line};

    die "$self->{filename}:$line $message\n";
}

1;
