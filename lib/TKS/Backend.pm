# Copyright (C) 2009 Catalyst IT Ltd (http://www.catalyst.net.nz)
#
# This file is distributed under the same terms as tks itself.
package TKS::Backend;

use strict;
use warnings;

use TKS::Config qw(config config_set config_delete);
use Term::ReadLine;
use UNIVERSAL;

sub new {
    my ($self, $instance) = @_;

    my $class = config($instance, 'backend') || 'TKS::Backend::WRMSWeb';

    eval "use $class";

    if ( $@ ) {
        die "Failed to load backend '$class': $@";
    }

    $self = bless {}, $class;

    unless ( UNIVERSAL::isa($self, __PACKAGE__) ) {
        die "Bad backend: " . ( ref $self ) . " isn't a subclass of " . __PACKAGE__;
    }

    $self->{instance} = $instance || 'default';

    $self->init();

    return $self;
}

sub instance {
    return shift->{instance};
}

sub instance_config {
    my ($self, $key) = @_;

    return config($self->{instance}, $key);
}

sub instance_config_set {
    my ($self, $key, $value) = @_;

    config_set($self->{instance}, $key, $value);
}

sub read_line {
    my ($self, $prompt) = @_;

    my $term = Term::ReadLine->new('tks');

    return $term->readline($prompt);
}

sub read_password {
    my ($self, $prompt) = @_;

    my $term = Term::ReadLine->new('tks');

    die 'Need Term::ReadLine::Gnu installed' unless $term->ReadLine eq 'Term::ReadLine::Gnu';

    $term->{redisplay_function} = $term->{shadow_redisplay};
    my $password = $term->readline($prompt);
    $term->{redisplay_function} = undef;

    return $password;
}

sub init {
}

sub get_timesheet {
    die "Need to implement get_timesheet";
}

sub add_timesheet {
    die "Need to implement get_timesheet";
}

sub valid_request {
    return 1;
}


1;

