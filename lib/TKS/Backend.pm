package TKS::Backend;

use strict;
use warnings;

use Term::ReadPassword;

sub new {
    my ($self) = @_;

    my $class = ref $self || $self;

    $self = bless {}, $class;

    return $self;
}

sub instance_config {
    my ($self, $key) = @_;

    return 'default' if $key eq 'name';
    return 'martyn' if $key eq 'username';
    return read_password('Password for "' . $self->instance_config('name') . '" instance: ') if $key eq 'password';
}


1;

