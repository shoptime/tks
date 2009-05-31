package TKS::Entry;

use Moose;

has 'date'         => ( is => 'rw', isa => 'Str', required => 1 );
has 'request'      => ( is => 'rw', isa => 'Str', required => 1 );
has 'time'         => ( is => 'rw', isa => 'Num', required => 1 );
has 'needs_review' => ( is => 'rw', isa => 'Int', required => 1, default => 0 );
has 'comment'      => ( is => 'rw', isa => 'Str', required => 1 );

sub clone {
    my ($self) = @_;

    return bless { %{$self} }, ref $self;
};

sub invert_clone {
    my ($self) = @_;

    $self = bless { %{$self} }, ref $self;
    $self->{time} = -$self->{time};

    return $self;
};

sub as_string {
    my ($self) = @_;

    return $self->request . ': ' . $self->comment . ' (' . $self->time . ')';
}

1;
