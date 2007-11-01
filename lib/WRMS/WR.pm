#!/usr/bin/perl

package WRMS::WR;

use strict;
use warnings;
use Carp;
use XML::LibXML;
# TODO: remove Data::Dumper;
use Data::Dumper;

my $KEYS = [qw(wr brief status detail organisation system urgency importance)];

# TODO: documentation
sub new {
    my ($class, $wrms, $wr, $options) = @_;

    my $self = {};
    bless $self, $class;

    unless (defined $wrms and ref $wrms eq 'WRMS') {
        croak 'First param must be an instance of WRMS';
    }

    unless (defined $wr and $wr =~ /^\d+$/) {
        croak 'Second param must be a work request number';
    }

    foreach my $key ( @{$KEYS} ) {
        $self->{data}{$key} = $options->{$key} if exists $options->{$key};
    }

    $self->{wrms} = $wrms;
    $self->{data}{wr} = $wr;

    return $self;
}

sub get {
    my ($self, $key) = @_;

    croak "Unknown key '$key'" unless grep { $_ eq $key } @{$KEYS};

    $self->fetch_data() unless defined $self->{data}{$key};

    return $self->{data}{$key};
}

sub fetch_data {
    my $self = shift;

    $self->{wrms}{mech}->get('/wr.php?request_id=' . $self->{data}{wr});

    my $dom = $self->{wrms}->parse_page();

    foreach my $tr ( $dom->findnodes('//tr/th[@class="prompt"]/..') ) {
        my $key = $tr->findnodes('./th[@class="prompt"]')->[0]->textContent;
        my $value = eval { $tr->findnodes('./td[@class="entry"]')->[0]->textContent; };

        if ( $key eq 'W/R #' and $value =~ m{ Status: \s* (.*) }xms ) {
            $self->{data}{status} = $1;
        }
        $self->{data}{brief}        = $value if ( $key eq 'Brief' );
        $self->{data}{detail}       = $value if ( $key eq 'Details' );
        $self->{data}{organisation} = $value if ( $key eq 'Organisation' );
        $self->{data}{system}       = $value if ( $key eq 'System' );
        $self->{data}{urgency}      = $value if ( $key eq 'Urgency' );
        $self->{data}{importance}   = $value if ( $key eq 'Importance' );

    }
}

1;
