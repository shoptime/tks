#!/usr/bin/env perl
#
# TKS: Timekeeping sucks. TKS makes it suck less.
# Copyright (C) 2008 Catalyst IT Ltd (http://www.catalyst.net.nz)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin . '/lib';
use Getopt::Declare;
use Config::IniFiles;
use File::Slurp;
use List::Util qw(sum);
use Data::Dumper;
use WRMS;

my %config;
tie %config, 'Config::IniFiles', ( -file => $ENV{HOME} . '/.tksrc' );

my $args = Getopt::Declare->new(q(
    [strict]
    -c                     	Write data to WRMS (by default just prints what _would_ happen)
    -v                  	Verbose mode; describe the parsing of the timekeeping file
    <file>              	File to process [required]
));

die unless defined $args;
my $VERBOSE = $args->{'-v'};

my $tkdata = load_timesheet_file($args->{'<file>'});
#print Dumper($tkdata);

# connect to wrms
my $wrms    = WRMS->new({
    username => $config{default}{username},
    password => $config{default}{password},
    site     => $config{default}{site},
    login    => 1,
});

# map of textual representations for WRs
my $wrmap = $config{'wrmap'};

# if the wr is in the map, substitute
foreach my $date ( keys %{$tkdata} ) {
    foreach my $entry ( @{$tkdata->{$date}} ) {
        $entry->{wr} = $wrmap->{$entry->{wr}} if exists $wrmap->{$entry->{wr}};
        unless ( $entry->{wr} =~ m{ \A \d+ \z }xms ) {
            warn "Invalid WR '$entry->{wr}'\n";
            # TODO: perhaps interactively add these?
            $entry = undef;
        }
    }
}

# look through data for WR info, print it and potentially commit
my @lines = read_file($args->{'<file>'});
my $file_needs_write = 0;
my $total_time = 0.0;

foreach my $date ( sort keys %{$tkdata} ) {
    my $date_has_data = 0;
    @{$tkdata->{$date}} = grep { exists $_->{wr} and $_->{wr} =~ m{ \A \d+ \z }xms } @{$tkdata->{$date}};
    foreach my $entry ( sort { $a->{wr} <=> $b->{wr} } @{$tkdata->{$date}} ) {
        $date_has_data = 1;

        printf("%s\t%5d\t%.2f\t%s\n", $date, $entry->{wr}, $entry->{time}, $entry->{comment});

        next unless $args->{'-c'};

        # add the time to wrms
        $wrms->add_time(
            $entry->{wr},
            $date,
            $entry->{comment},
            $entry->{time},
        );

        # comment it out in the file
        @lines[$entry->{linenumber} - 1] = '# ' . @lines[$entry->{linenumber} - 1];
        $file_needs_write = 1;
    }


    my $day_time_taken = sum map { $_->{time} or 0 } @{$tkdata->{$date}};
    printf(" " x length($date) . "\t\t%.2f\n\n", $day_time_taken) if $date_has_data;
    $total_time += $day_time_taken if $day_time_taken;
}

write_file($args->{'<file>'}, @lines) if $file_needs_write;

printf("Total time: %.2f\n", $total_time);
print "Run this program again with -c to commit the work\n" unless $args->{'-c'} or $total_time == 0;





# Named for compatibility with scriptalicious
sub mutter {
    print shift if $VERBOSE;
}

# Loads data from a TKS timesheet file into a structure looking like this:
#
# [
#    'date' => [
#               {
#                   'line'    => 'original line in the tks file',
#                   'wr'      => WR number for this line (if any)
#                   'time'    => Amount of time spent
#                   'comment' => Comment for this line of work
#               },
#               {
#                   'line' => ...
#               }
#              ],
#    'date' => [
#               ...
#              ]
# ]
sub load_timesheet_file {
    my ($file) = @_;

    my $result = {};
    my $current_date = '';
    my @lines = read_file($file);

    my $i = 0;
    foreach my $line ( @lines ) {
        my $linedata = parse_line($line);
        $linedata->{linenumber} = ++$i;

        if ( $linedata->{wr} ) {
            mutter " ** WR: $linedata->{wr}" . (" " x (16 - length($linedata->{wr}))) . "TIME: $linedata->{time}   COMMENT: $linedata->{comment}\n";
            unless ( $current_date ) {
                die "Whoops - timesheet data encountered before date?";
            }

            push @{$result->{$current_date}}, $linedata;
        }
        elsif ( $linedata->{date} ) {
            mutter " * Date: $linedata->{date}\n";
            if ( $current_date ne $linedata->{date} ) {
                $current_date = $linedata->{date};
                $result->{$current_date} = [];
            }
        }
        else {
            mutter "Boring line: $line";
        }
    }

    return $result;
}

# Examine the line for timekeeping information. Returns a hashref describing
# the data retrieved.
#
# This hashref always has a 'line' key, containing the contents of the line. If
# the line had valid timesheeting information on it too, that is returned
# (using the 'wr', 'date', 'time' and 'comment' fields)
my $lastline;
sub parse_line {
    my ($line) = @_;

    my $result = {};
    $result->{line} = $line;

    return $result if $line =~ m/^ \s* \#/xms;

    if (
        $line =~ m{^ ( \d+ / \d+ / \d\d (\d\d)? ) }xms   # dd/mm/yy or dd/mm/yyyy
        or $line =~ m{^ ( \d{4} / \d+ / \d+ ) }xms       # yyyy/mm/dd
        or $line =~ m{^ ( \d{4} - \d+ - \d+ ) }xms       # yyyy-mm-dd
    ) {
        $result->{date} = $1;
        return $result;
    }

    if ( $line =~ m{\A
            ( \d+ | [a-zA-Z0-9_-]+ ) \s+   # Work request number OR alias
            ( \d\d? | \d* \. \d+ ) \s+     # Time in integer or decimal
            ( .* ) \z}xms ) {
        $result->{wr}      = $1;
        $result->{time}    = $2;
        $result->{comment} = $3;
        chomp $result->{comment};
    }

    if ( $line =~ m{\A
            ( \d+ | [a-zA-Z0-9_-]+ ) \s+              # Work request number OR alias
            ( \d\d?:?\d\d ( \- \d\d?:?\d\d )? ) \s+   # Time specified in 24 hour time
            ( .* ) \z}xms ) {
        mutter " ** Found a time-based line: $1   $2\n";
        $result->{wr} = $1;
        $result->{comment} = $4;
        chomp $result->{comment};

        my $time = $2;

        # If we have a start-to-end formatted time
        if ( $time =~ m/-/ ) {
            my ($start, $end) = split(/-/, $time);
            $start = convert_to_minutes($start);
            $end   = convert_to_minutes($end);
            $result->{time} = ($end - $start) / 60;

            $lastline->{time} = ($start - $lastline->{time}) / 60 if $lastline->{needs_closing_time};
            $lastline->{needs_closing_time} = 0;
        }
        else {
            $lastline->{time} = (convert_to_minutes($time) - $lastline->{time}) / 60 if $lastline->{needs_closing_time};

            # We have a starting date only - need to wait for the next line
            $result->{needs_closing_time} = 1;
            $result->{time} = convert_to_minutes($time);
            $lastline = $result;
        }

    }

    return $result;
}


sub convert_to_minutes {
    my ($time) = @_;
    if ( $time =~ m/:/ ) {
        my ($hours, $minutes) = split(/:/, $time);
        return $hours * 60 + $minutes;
    }
    elsif ( length($time) == 4) {
        # 24 hour time
        return substr($time, 0, 2) * 60 + substr($time, 2);
    }
    die("Time in invalid format: $time");
}
