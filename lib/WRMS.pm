#!/usr/bin/perl

package WRMS;

use strict;
use warnings;
use Carp;
use XML::LibXML;
use WWW::Mechanize;
use WRMS::WR;
# TODO: remove Data::Dumper;
use Data::Dumper;
use File::Slurp;

# TODO: documentation
# need to specify site
# optionally specify username/password (otherwise will be prompted)
sub new {
    my ($class, $options) = @_;

    my $self = {};
    bless $self, $class;

    foreach my $key (qw(username password site login timeout)) {
        $self->{$key} = $options->{$key} if exists $options->{$key};
    }

    $self->{_loggedin} = 0;
    $self->{mech}   = WWW::Mechanize->new();
    $self->{parser} = XML::LibXML->new();
    $self->{parser}->recover(1);
    $self->{timeout} ||= 300;

    if ($self->{login}) {
        $self->login();
    }

    return $self;
}

=head2 login


=cut

sub login {
    my ($self, $username, $password) = @_;

    return if $self->{_loggedin};

    $username ||= $self->{username};
    $password ||= $self->{password};

    unless ( defined $username and defined $password ) {
        $self->{_error} = qq{No username/password specified};
        return $self->{_error};
    }

    my $mech = $self->{mech};

    $mech->get($self->{site});

    unless (
        defined $mech->current_form()
        and defined $mech->current_form()->find_input('username')
        and defined $mech->current_form()->find_input('password')
    ) {
        $self->{_error} = qq{Couldn't find WRMS login form at $self->{site}. HTTP status was } . $self->{mech}->status;
        return $self->{_error};
    }

    $mech->submit_form(
        fields => {
            username => $self->{username},
            password => $self->{password},
        },
    );

    if ( $mech->response()->content() =~ m{ invalid .* username .* password }xmsi ) {
        $self->{_error} = qq{Invalid username or password};
        return $self->{_error};
    }

    unless ( $mech->content() =~ m{ <div \s+ id="top_menu" \s* > .*? > ([^<]*) }xms ) {
        $self->{_error} = q{Couldn't determine "realname" for this WRMS instance};
        return $self->{_error};
    }

    $self->{realname} = $1;

    # get a list of saved searches
    $self->{_savedsearches} = {};
    my $dom = $self->parse_page();
    foreach my $link ( $dom->findnodes('//a') ) {
        if ( $link->getAttribute('href') =~ m{ style=plain .* saved_query= ( .* ) }xms ) {
            my $param = $1;
            map { $link->removeChild($_) } $link->findnodes('./b');
            my $name = $link->textContent;
            $self->{_savedsearches}{$link->textContent} = {
                param   => $param,
                refresh => 0,
                wrlist  => undef,
            }
        }
    }

    $self->{_loggedin} = 1;

    return;
}

sub saved_searches {
    my $self = shift;

    return keys %{$self->{_savedsearches}};
}

sub saved_search_list {
    my ($self, $search) = @_;

    unless ( exists $self->{_savedsearches}{$search} ) {
        croak 'Invalid search';
    }

    $search = $self->{_savedsearches}{$search};

    if ( defined $search->{wrlist} and (time - $search->{refresh}) < $self->{timeout} ) {
        return @{$search->{wrlist}};
    }

    $search->{wrlist} = [];

    #print '/wrsearch.php?style=plain&saved_query=' + $search->{param}, ;
    $self->{mech}->get('/wrsearch.php?style=plain&saved_query=' . $search->{param});

    my $dom = $self->parse_page();

    my ($table) = $dom->findnodes('//table/tr/th[@class="cols"]/../..');

    if ($table) {
        my $headings = [];
        my $clean_sub = sub {
            my $text = $_->textContent;
            $text =~ s/^\s*(.*?)\s*$/$1/ms;
            $text =~ s/\xa0/ /g;
            return $text;
        };

        foreach my $row ( $table->findnodes('./tr/th/..') ) {
            @{$headings} = map { &{$clean_sub}($_) } $row->findnodes('./th');
        }
        foreach my $row ( $table->findnodes('./tr') ) {
            my %data;
            @data{@{$headings}} = map { &{$clean_sub}($_) } $row->findnodes('./td');
            #return unless ( exists $data{'WR #'} and $data{'WR #'} =~ /\S/ );
            next unless ( exists $data{'WR #'} and defined $data{'WR #'} );
            push @{$search->{wrlist}}, WRMS::WR->new($self, $data{'WR #'}, { brief => $data{'Description'} });
        }
    }

    return @{$search->{wrlist}};
}


sub add_time {
    my ($self, $wr, $date, $comment, $hours) = @_;

    $self->{mech}->get('/wr.php?request_id=' . $wr . '&edit=1');

    write_file('WRMS.html', $self->{mech}->response->content);

    $self->{mech}->submit_form(
        with_fields => {
            work_on          => $date,
            work_quantity    => $hours,
            work_description => $comment,
            submit           => 'Update',
        },
        button => 'submit',
    );
}

sub get_time {
    my ($self, $wr, $justme) = @_;

    croak qq{WR '$wr' isn't a number} unless ( defined $wr and $wr =~ m{ \A \d+ \z }xms );

    $self->{mech}->get('/wr.php?request_id=' . $wr);

    croak qq{Request '$wr' is unavailable} if ( $self->{mech}->content() =~ m{ Request .* unavailable }x );

    my $dom = $self->parse_page();

    my $work_data = [];

    foreach my $tr ( $dom->findnodes('//table/tr[count(td)=9]') ) {
        my $data = {};
        @{$data}{qw(doneby doneon quantity rate description invoicedby charged invoicenumber chargeamount)} = map { $_->findvalue('.') } $tr->findnodes('./td');

        if ( defined $data->{charged} and $data->{charged} =~ m{ \A (\d\d) - (\d\d) - (\d\d\d\d) \z }xms ) {
            $data->{charged} = "$3-$2-$1";
        }

        if ( defined $data->{doneon} and $data->{doneon} =~ m{ \A (\d\d) - (\d\d) - (\d\d\d\d) \z }xms ) {
            $data->{doneon} = "$3-$2-$1";
            push @{$work_data}, $data if ( not defined $justme or $data->{doneby} eq $self->{realname} );
        }
    }

    return $work_data;
};

sub parse_page {
    my ($self) = @_;

    my $dom;
    {
        local *STDERR;
        open STDERR, '>', '/dev/null';

        $dom = $self->{parser}->parse_html_string($self->{mech}->content());
    }

    return $dom if defined $dom;

    croak q{Couldn't parse '} . $self->{mech}->uri() . q{'};
}

sub load_timesheet_file {
    my ($file) = @_;

    my ($DATE, $WR, $TIME, $DESC);
    my @result;

    open(FH, "<$file");
    while (my $line = <FH>) {
        # Strip comments
        next if $line =~ m/^ \s* \#/xms;

        if (
            $line =~ m{^ ( \d+ / \d+ / \d\d (\d\d)? ) }xms or  # dd/mm/yy or dd/mm/yyyy
            $line =~ m{^ ( \d{4} / \d+ / \d+ ) }xms or         # yyyy/mm/dd
            $line =~ m{^ ( \d{4} - \d+ - \d+ ) }xms            # yyyy/mm/dd
        ) {
            $DATE = $1;
            next;
        }

        if ( $line =~ m{\A
                ( \d+ | [a-zA-Z0-9_-]+ ) \s+   # Work request number OR alias
                ( \d+ | \d* \. \d+ ) \s+       # Time in integer or decibal
                ( .* ) \z}xms ) {
            $WR   = $1;
            $TIME = $2;
            $DESC = $3;
            chomp $DESC;

            my $row = {
                'wr'      => $WR,
                'date'    => $DATE,
                'comment' => $DESC,
                'time'    => $TIME,
            };

            push @result, $row;
        }

    }
    close FH;

    return @result;
}

sub last_error {
    my ($self) = @_;

    return $self->{_error};
}

1;
