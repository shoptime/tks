#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin . '/lib';
use Getopt::Declare;
use YAML;
use WRMS;

my $config = YAML::LoadFile($FindBin::Bin . '/config.yml');

my $args = Getopt::Declare->new(q(
    [strict]
    -c                     	Write data to WRMS (by default just prints what _would_ happen)
    <yamlfile>             	File to proces [required]
));

die unless defined $args;

my @data = YAML::LoadFile($args->{'<yamlfile>'});

# connect to wrms
my $wrms    = WRMS->new({
    username => $config->{username},
    password => $config->{password},
    site => $config->{site},
    login => 1,
});

# map of textual representations for WRs
my $wrmap = $config->{wrmap};

my $total_time = 0;

# loop over yaml data
foreach my $entry ( @data ) {
    # don't want data with no wr
    next unless defined $entry->{wr};

    # if the wr is in the map, substitute
    $entry->{wr} = $wrmap->{$entry->{wr}} if exists $wrmap->{$entry->{wr}};

    # unless we have something that looks like a wr, skip
    unless ( $entry->{wr} =~ m{ \A \d+ \z }xms ) {
        warn "Invalid WR: $entry->{wr}";
        next;
    }

    # unless we have some time
    next unless defined $entry->{time} and $entry->{time} =~ m{ \d }xms;

    $total_time += $entry->{time};
    print $entry->{date}, " - ", $entry->{wr}, " - ", $entry->{time}, "\n";

    next unless $args->{'-c'};

    # add the time to wrms
    $wrms->add_time(
        $entry->{wr},
        $entry->{date},
        $entry->{comment},
        $entry->{time},
    );
}

print "Total time: $total_time\n";
