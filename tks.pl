#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin . '/lib';
use Getopt::Declare;
use Config::IniFiles;
use WRMS;

my %config;
tie %config, 'Config::IniFiles', ( -file => $ENV{HOME} . '/.tksrc' );

my $args = Getopt::Declare->new(q(
    [strict]
    -c                     	Write data to WRMS (by default just prints what _would_ happen)
    <file>              	File to process [required]
));

die unless defined $args;

my @data = WRMS::load_timesheet_file($args->{'<file>'});

# connect to wrms
my $wrms    = WRMS->new({
    username => $config{default}{username},
    password => $config{default}{password},
    site     => $config{default}{site},
    login    => 1,
});

# map of textual representations for WRs
my $wrmap = $config{'wrmap'};

my $total_time = 0;

# if the wr is in the map, substitute
foreach my $entry ( @data ) {
    $entry->{wr} = $wrmap->{$entry->{wr}} if exists $wrmap->{$entry->{wr}};
    unless ( $entry->{wr} =~ m{ \A \d+ \z }xms ) {
        warn "Invalid WR '$entry->{wr}'\n";
        # TODO: perhaps interactively add these?
    }
}

@data = grep { $_->{wr} =~ m{ \A \d+ \z }xms } @data;

# sort dataz by date, then WR
@data = sort { $a->{date} cmp $b->{date} or $a->{wr} <=> $b->{wr} } @data;

# loop over data
my $current_date = '';
my $current_date_hoursum = 0.0;
foreach my $entry ( @data ) {
    # don't want data with no wr
    next unless defined $entry->{wr};

    # unless we have something that looks like a wr, skip
    unless ( $entry->{wr} =~ m{ \A \d+ \z }xms ) {
        warn "Invalid WR: $entry->{wr}";
        next;
    }

    # unless we have some time
    next unless defined $entry->{time} and $entry->{time} =~ m{ \d }xms;

    # output blank line for new date
    if ( $current_date and $current_date ne $entry->{date} ) {
        # time to print a summary
        printf("\t\t%.2f\n\n", $current_date_hoursum);
        $current_date_hoursum = 0.0;
    }
    else {
        $current_date_hoursum += $entry->{time};
    }
    $current_date = $entry->{date};

    $total_time += $entry->{time};
    printf("%s\t%5d\t%.2f\t%s", $entry->{date}, $entry->{wr}, $entry->{time}, $entry->{comment});
    print "\n";

    next unless $args->{'-c'};

    # add the time to wrms
    $wrms->add_time(
        $entry->{wr},
        $entry->{date},
        $entry->{comment},
        $entry->{time},
    );
}

# The final summary
printf("\t\t%.2f\n\n", $current_date_hoursum);
print "Total time: $total_time\n";

print "Run this program again with -c to commit the work\n" unless $args->{'-c'};
