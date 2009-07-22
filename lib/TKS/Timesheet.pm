# Copyright (C) 2009 Catalyst IT Ltd (http://www.catalyst.net.nz)
#
# This file is distributed under the same terms as tks itself.
package TKS::Timesheet;

use Moose;
use List::Util qw(sum);
use Term::ANSIColor;
use TKS::Date;
use TKS::Entry;
use TKS::Config;
use File::Slurp;
use File::Temp qw(tempfile);
use Fcntl qw(:DEFAULT :flock);
use POSIX;

has 'entries' => ( is => 'rw', isa => 'ArrayRef[TKS::Entry]', required => 1, default => sub { [] } );
has 'backend' => ( is => 'rw', isa => 'TKS::Backend' );

around 'entries' => sub {
    my ($orig, $self) = @_;

    my $entries = $self->$orig();

    return () unless $entries and ref $entries eq 'ARRAY';
    return @{$entries};
};

sub from_file {
    my ($self, $filename, $force) = @_;

    my $data = scalar(read_file($filename));

    return $self->from_string($data, $filename, $force);
}
sub from_string {
    my ($self, $string, $filename, $force) = @_;

    my $class = ref $self || $self;

    my $timesheet = $class->new();

    $timesheet->{parse_date} = undef;
    $timesheet->{parse_last_entry} = undef;
    $timesheet->{parse_filename} = $filename;
    $timesheet->{force} = $force;

    my @entries;

    $timesheet->{parse_line} = 0;
    foreach my $line ( split /\r?\n/, $string ) {
        $timesheet->{parse_line}++;

        my $entry = $timesheet->_from_string_parse_line($line);

        next unless $entry;

        $timesheet->{parse_last_entry}->{next_entry} = $entry if $timesheet->{parse_last_entry};
        push @entries, $entry;
        $timesheet->{parse_last_entry} = $entry;
    }

    # Resolve end times where appropriate
    foreach my $entry ( @entries ) {
        if ( $entry->{incomplete} ) {
            unless ( defined $entry->{next_entry}{date} ) {
                $timesheet->_from_string_fail('Got end of file before a finish time in entry', $entry->{line});
            }
            unless ( $entry->{date} eq $entry->{next_entry}{date} ) {
                $timesheet->_from_string_fail('Got a date before a finish time in entry', $entry->{line});
            }
            unless ( $entry->{next_entry}{start} ) {
                $timesheet->_from_string_fail('Failed to find a finish time for entry', $entry->{line});
            }
            $entry->{time} = $timesheet->_from_string_timediff($entry->{start}, $entry->{next_entry}{start});
        }
        delete $entry->{next_entry};
        delete $entry->{incomplete};
        delete $entry->{start};
        delete $entry->{end};
    }

    foreach my $entry ( @entries ) {
        $entry->{request} = config('requestmap', $entry->{request}) || $entry->{request};
        $timesheet->addentry(TKS::Entry->new(
            date         => $entry->{date},
            request      => $entry->{request},
            time         => $entry->{time},
            comment      => $entry->{comment},
            needs_review => $entry->{needs_review},
        ));
    }

    my @big_days = grep { $_->[1] > 24 } map { [ $_ , $timesheet->filter_date($_)->time ] } $timesheet->dates->dates;

    if ( @big_days ) {
        foreach my $big_day ( @big_days ) {
            $timesheet->_from_string_fail("$big_day->[1] hours on date $big_day->[0] is more than 24", $timesheet->{parse_line_for_date}{$big_day->[0]}, 1);
        }
    }

    delete $timesheet->{parse_date};
    delete $timesheet->{parse_last_entry};
    delete $timesheet->{parse_line};
    delete $timesheet->{parse_filename};
    delete $timesheet->{parse_line_for_date};

    return $timesheet;
}

sub _from_string_parse_line {
    my ($self, $line) = @_;

    my $result = {
        date => $self->{parse_date},
        line => $self->{parse_line},
    };

    # yyyy-mm-dd or yyyy/mm/dd
    if ( $line =~ m{ \A ( \d{4} ) ( [/-] ) ( \d{2} ) \2 ( \d{2} ) \b \s* (?: \# .* )? \z }xms ) {
        $self->{parse_date} = strftime('%F', 0, 0, 0, $4, $3 - 1, $1 - 1900);
        if ( defined $result->{date} and $result->{date} ge $self->{parse_date} ) {
            $self->_from_string_fail("Specified date $self->{parse_date} is earlier than the date before it", $result->{line}, 1);
        }
        $self->{parse_line_for_date}{$self->{parse_date}} = $result->{line};
        return;
    }
    if (
        $line =~    m{ \A ( \d+ ) / ( \d+ ) / ( \d\d (?:\d\d)? ) \b \s* (?: \# .* )? \z }xms # dd/mm/yy or dd/mm/yyyy
    ) {
        $self->{parse_date} = strftime('%F', 0, 0, 0, $1, $2 - 1, $3 >= 100 ? $3 - 1900 : $3 + 100);
        if ( defined $result->{date} and $result->{date} ge $self->{parse_date} ) {
            $self->_from_string_fail("Specified date $self->{parse_date} is earlier than the date before it", $result->{line}, 1);
        }
        $self->{parse_line_for_date}{$self->{parse_date}} = $result->{line};
        return;
    }

    if ( $line =~ m{
            \A
            ( \d+ | [a-zA-Z0-9_-]+ ) \s+  # Work request number OR alias
            ( \d+ | \d* \. \d+ )     \s+  # Time in integer or decimal
            ( \[review\] )?          \s*  # Review flag
            ( \S .* )                     # Work description
            \z
        }xms ) {
        $result->{request}      = $1;
        $result->{time}         = $2;
        $result->{needs_review} = $3 ? 1 : 0;
        $result->{comment}      = $4;
        chomp $result->{comment};
    }

    if ( $line =~ m{
            \A
            ( \d+ | [a-zA-Z0-9_-]+ )              \s+ # Work request number OR alias
            ( \d\d?:?\d\d (?: \- \d\d?:?\d\d )? ) \s+ # Time specified in 24 hour time
            ( \[review\] )?                       \s* # Review flag
            ( \S .* )                                 # Work description
            \z
        }xms ) {
        $result->{request}      = $1;
        $result->{needs_review} = $3 ? 1 : 0;
        $result->{comment}      = $4;
        chomp $result->{comment};

        my $time = $2;

        # If we have a start-to-end formatted time
        if ( $time =~ m/-/ ) {
            my ($start, $end) = split(/-/, $time);
            $result->{time} = $self->_from_string_timediff($start, $end);
            $result->{start} = $start;
            $result->{end} = $end;
        }
        else {
            $result->{start} = $time;
            $result->{incomplete} = 1;
        }

    }

    if ( $result->{request} ) {
        unless ( $result->{date} ) {
            $self->_from_string_fail('Encountered timesheet entry before a date was specified');
        }
        unless ( defined $result->{time} or $result->{incomplete} ) {
            $self->_from_string_fail('Failed to calculate time');
        }
        return $result;
    }

    # Skip "blank" lines
    return if $line =~ m{ \A \s* (?: \# .* )? \z }xms;

    # Detect "common" errors
    my $error;

    unless ( $line =~ m{ \A ( \d+ | [a-zA-Z0-9_-]+ ) }xms ) {
        $error ||= 'All lines need to start with a request or an alias';
    }

    if ( $line =~ m{
            \A
            ( \d+ | [a-zA-Z0-9_-]+ ) \s+ # Work request number OR alias
            ( \d\d?:?\d\d \- ) \s+       # Time specified in 24 hour time
            ( \[review\] )?          \s* # Review flag
            ( \S .* )                    # Work description
            \z
        }xms ) {
        $error ||= 'Missing end time for time range';
    }

    $error ||= 'Failed to parse line';

    $self->_from_string_fail("$error\n$line");
}

sub _from_string_timediff {
    my ($self, $start, $end, $line) = @_;

    $line ||= $self->{parse_line};

    my ($start_hour, $start_minute) = $start =~ m{ \A (\d\d?) :? (\d\d) \z }xms;

    $self->_from_string_fail("Invalid time format '$start'") unless $start_hour and $start_minute;

    my ($end_hour, $end_minute) = $end =~ m{ \A (\d\d?) :? (\d\d) \z }xms;

    $self->_from_string_fail("Invalid time format '$end'") unless $end_hour and $end_minute;

    my $minutes_start = $start_hour * 60 + $start_minute;
    my $minutes_end = $end_hour * 60 + $end_minute;

    $self->_from_string_fail("Start time can't be after end time in '$start-$end'") if $minutes_start > $minutes_end;

    return ( $minutes_end - $minutes_start ) / 60;
}

sub _from_string_fail {
    my ($self, $message, $line, $overridable) = @_;

    $line ||= $self->{parse_line};

    $message = "line $line: $message";

    if ( not $self->{force} and $overridable ) {
        $message .= ' (use --force to ignore this error)';
    }

    $message = "$self->{parse_filename}: $message" if $self->{parse_filename};

    if ( $overridable and $self->{force} ) {
        warn "WARNING: $message\n";
    }
    else {
        die "$message\n";
    }
}

sub dates {
    my ($self) = @_;

    my $dates = TKS::Date->new();

    foreach my $entry ( $self->entries ) {
        $dates->add_datespec($entry->date);
    }

    return $dates;
}

sub clone {
    my ($self) = @_;

    my $timesheet = $self->new();

    foreach my $entry ( $self->entries ) {
        $timesheet->addentry($entry->clone);
    }

    return $timesheet;
}

sub invert {
    my ($self) = @_;

    my $timesheet = $self->new();

    foreach my $entry ( $self->entries ) {
        $entry = $entry->clone;
        $entry->time(-$entry->time);
        $timesheet->addentry($entry);
    }
    return $timesheet;
}

sub diff {
    my ($self, $timesheet) = @_;

    $self = $self->compact;
    $timesheet = $timesheet->compact;
    my $diff = $self->new();

    foreach my $entry ( $self->entries ) {
        my ($match) = $timesheet->entry_search($entry);
        if ( $match ) {
            unless ( $match->time == $entry->time ) {
                $entry = $entry->clone;
                $entry->time($match->time - $entry->time);
                unless ( abs($entry->time) < 1e-8 ) {
                    $diff->addentry($entry);
                }
            }
        }
        else {
            $diff->addentry($entry->invert_clone);
        }
    }
    foreach my $entry ( $timesheet->entries ) {
        my ($match) = $self->entry_search($entry);
        unless ( $match ) {
            $diff->addentry($entry->clone);
        }
    }

    return $diff;
}

sub entry_search {
    my ($self, $search_entry) = @_;

    my @matches;
    foreach my $entry ( $self->entries ) {
        if (
            $entry->date eq $search_entry->date
            and $entry->request eq $search_entry->request
            and $entry->comment eq $search_entry->comment
            and $entry->needs_review eq $search_entry->needs_review
        ) {
            push @matches, $entry->clone;
        }
    }

    return @matches;
}

sub addentry {
    my ($self, $entry) = @_;

    push @{$self->{entries}}, $entry;
}

sub addtimesheet {
    my ($self, $timesheet) = @_;

    foreach my $entry ( $timesheet->entries ) {
        $self->addentry($entry->clone);
    }
}

sub subtimesheet {
    my ($self, $timesheet) = @_;

    $self->addtimesheet($timesheet->invert);
}

sub size {
    my ($self) = @_;

    return scalar($self->entries);
}

sub time {
    my ($self) = @_;

    return sum( map { $_->time } $self->entries );
}

sub filter_date {
    my ($self, $date) = @_;

    $date = TKS::Date->new($date);

    my $timesheet = $self->new();

    foreach my $entry ( $self->entries ) {
        next unless $date->contains($entry->date);
        $timesheet->addentry($entry);
    }

    return $timesheet;
}

sub filter_request {
    my ($self, $request) = @_;

    my $timesheet = $self->new();

    foreach my $entry ( $self->entries ) {
        next unless $entry->request eq $request;
        $timesheet->addentry($entry);
    }

    return $timesheet;
}

sub as_color_string {
    my ($self) = @_;

    return $self->as_string(1);
}

sub as_string {
    my ($self, $color) = @_;

    my $output = '';
    my $date;
    my $date_total;

    unless ( $self->entries ) {
        $output .= $color ? color('bold blue') : '';
        $output .= "# no entries in this timesheet\n";
        $output .= $color ? color('reset') : '';
        return $output;
    }

    my $format_hours = sub {
        my ($date_total) = @_;
        return '' unless $date_total;
        return sprintf(
            "%s#            %5.2f    total hours%s\n",
            $color ? color('bold blue') : '',
            $date_total,
            $color ? color('reset') : '',
        );
    };

    foreach my $entry ( sort { $a->date cmp $b->date or $a->request cmp $b->request or $a->comment cmp $b->comment } $self->entries ) {
        unless ( $date and $date eq $entry->date ) {
            if ( defined $date_total ) {
                $output .= $format_hours->($date_total);
            }
            $output .= "\n" . ( $color ? color('bold magenta') : '' ) . $entry->date;
            if ( $entry->date =~ m{ \A (\d\d\d\d)-(\d\d)-(\d\d) \z }xms ) {
                $output .= $color ? color('bold blue') : '';
                $output .= ' # ' . strftime('%A', 0, 0, 0, $3, $2 - 1, $1 - 1900);
            }
            $output .= $color ? color('reset') : '';
            $output .= "\n\n";
            $date = $entry->date;
            $date_total = 0;
        }

        next if $entry->request eq '-';

        $date_total += $entry->time;
        my $request_color = 'yellow';
        if ( $self->backend and not $self->backend->valid_request($entry->request) ) {
            $request_color = 'bold red';
        }
        $output .= sprintf(
            "%s%-12s %s%5.2f    %s%s%s%s\n",
            $color ? color($request_color) : '',
            config('reverserequestmap', $entry->request) || $entry->request,
            $color ? color('reset') . color('green') : '',
            $entry->time,
            $color ? color('red') : '',
            $entry->needs_review ? '[review] ' : '',
            $color ? color('reset') : '',
            $entry->comment,
        );
    };
    if ( defined $date_total ) {
        $output .= $format_hours->($date_total);
    }

    if ( $self->time ) {
        $output .= $color ? color('bold blue') : '';
        $output .= "\n# Total hours: " . sprintf('%.2f', $self->time) . "\n";
    }

    $output .= $color ? color('reset') : '';
    $output .= "\n";

    return $output;
}

sub edit {
    my ($self) = @_;

    my $string = "# Edit this file to suit, then save and quit\n";
    $string .= $self->as_string;

    my $timesheet;

    while ( not $timesheet ) {
        $string  = $self->invoke_editor($string);
        return unless $string;
        $timesheet = eval { $self->from_string("\n\n" . $string); };
        if ( $@ ) {
            $string =~ s{ ^ \# \s ERROR: .* $ }{}xm;
            $string =~ s{ \A \s* }{}xms;
            chomp $@;
            $string = "# ERROR: $@\n\n$string";
        }
    }

    return $timesheet;
}

# this method based on Term::CallEditor(v0.11)'s solicit method
# original: Copyright 2004 by Jeremy Mates
# copied under the terms of the GPL
sub invoke_editor {
    my ($self, $string) = @_;

    my $editor = $ENV{EDITOR} || $ENV{VISUAL} || 'vi';

    File::Temp->safe_level(File::Temp::HIGH);
    my ( $fh, $filename ) = tempfile( UNLINK => 1, SUFFIX => '.tks' );

    # since File::Temp returns both, check both
    unless ( $fh and $filename ) {
        die "couldn't create temporary file";
    }

    select( ( select($fh), $|++ )[0] );
    print $fh $string;

    # need to unlock for external editor
    flock $fh, LOCK_UN;

    # run the editor
    my $mtime = (stat $filename)[9];
    my $status = system($editor, $filename);

    # check its return value
    if ( $status != 0 ) {
        die $status != -1
            ? "external editor ($editor) failed: $?"
            : "could not launch ($editor) program: $!";
    }

    if ( (stat $filename)[9] == $mtime ) {
        # File wasn't "saved"
        return;
    }

    unless ( seek $fh, 0, 0 ) {
        die "could not seek on temp file: errno=$!";
    }

    return scalar(read_file($filename));
}

sub negative_to_zero {
    my ($self) = @_;

    my $timesheet = $self->new();

    foreach my $entry ( $self->entries ) {
        $entry = $entry->clone;
        $entry->time(0) if $entry->time < 0;
        $timesheet->addentry($entry);
    }

    return $timesheet;
}

sub compact {
    my ($self) = @_;

    my $timesheet = $self->new();

    my $entries = {};

    foreach my $entry ( $self->entries ) {
        if ( exists $entries->{$entry->date}{$entry->request}{$entry->comment}{$entry->needs_review} ) {
            $entries->{$entry->date}{$entry->request}{$entry->comment}{$entry->needs_review}->time($entries->{$entry->date}{$entry->request}{$entry->comment}{$entry->needs_review}->time + $entry->time);
        }
        else {
            $entries->{$entry->date}{$entry->request}{$entry->comment}{$entry->needs_review} = $entry->clone;
        }
    }

    foreach my $date ( keys %{$entries} ) {
        foreach my $request ( keys %{$entries->{$date}} ) {
            foreach my $comment ( keys %{$entries->{$date}{$request}} ) {
                foreach my $needs_review ( keys %{$entries->{$date}{$request}{$comment}} ) {
                    $timesheet->addentry($entries->{$date}{$request}{$comment}{$needs_review});
                }
            }
        }
    }

    return $timesheet;
}

1;
