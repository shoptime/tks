package TKS::Backend;

use strict;
use warnings;

use TKS::Config;
use Term::ReadLine;
use UNIVERSAL;

sub new {
    my ($self, $instance) = @_;

    my $class = config($instance, 'backend') || 'TKS::Backend::WRMSWeb';

    eval "use $class";

    $self = bless {}, $class;

    unless ( UNIVERSAL::isa($self, __PACKAGE__) ) {
        die "Bad backend: " . ( ref $self ) . " isn't a subclass of " . __PACKAGE__;
    }

    $self->{instance} = $instance;

    $self->init();

    return $self;
}

sub instance {
    return shift->{instance};
}

sub instance_config {
    my ($self, $key) = @_;

    return config($self->{instance}, $key);

    #return read_password('Password for "' . $self->instance_config('name') . '" instance: ') if $key eq 'password';
}

sub read_line {
    my ($self, $prompt) = @_;

    my $term = Term::ReadLine->new('tks');

    return $term->readline($prompt);
}

sub read_password {
    my ($self, $prompt) = @_;

    my $term = Term::ReadLine->new('tks');

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

sub delete_timesheet {
    die "Need to implement get_timesheet";
}

sub add_timesheet {
    die "Need to implement get_timesheet";
}

sub valid_request {
    return 1;
}


1;

