package TKS::Backend::WRMSWeb;

use strict;
use warnings;
use base 'TKS::Backend';
use Date::Calc;
use WWW::Mechanize;
use XML::LibXML;
use JSON;
use POSIX;
use TKS::Timesheet;

sub init {
    my ($self) = @_;

    my $mech = $self->{mech} = WWW::Mechanize->new();
    $self->{parser} = XML::LibXML->new();
    $self->{parser}->recover(1);

    my $username = $self->instance_config('username');
    my $password = $self->instance_config('password');

    unless ( $username and $password ) {
        die "Missing username and/or password";
    }

    # Get homepage
    $mech->get($self->baseurl);

    # Check for login form
    unless (
        defined $mech->current_form()
        and defined $mech->current_form()->find_input('username')
        and defined $mech->current_form()->find_input('password')
    ) {
        die "Couldn't find WRMS login form at " . $self->baseurl . ". HTTP status was: " . $mech->status;
    }

    # Login
    $mech->submit_form(
        fields => {
            username => $username,
            password => $password,
        },
    );

    # Attempt to determine if it worked or not
    my $dom = $self->parse_page;

    my @messages = map { $_->textContent } $dom->findnodes('//ul[@class="messages"]/li');
    if ( @messages ) {
        die "Login failed\n" . join("\n", map { " - $_" } @messages) . "\nStopped at ";
    }

    my ($uncharged_work_link) = grep { $_->textContent eq 'My Uncharged Work' } $dom->findnodes('//a');
    unless ( $uncharged_work_link and $uncharged_work_link->getAttribute('href') =~ /user_no=(\d+)/ ) {
        die "Couldn't determine WRMS user_no";
    }

    $self->{wrms_user_no} = $1;
}

sub baseurl {
    my ($self) = @_;

    my $site     = $self->instance_config('site');
    $site ||= 'https://wrms.catalyst.net.nz/';

    $site .= '/' unless $site =~ m{ / \z }xms;

    return $site;
}

sub get_timesheet {
    my ($self, @dates) = @_;

    my ($c_year, $c_month, $c_day) = map { strftime($_, localtime) } qw(%Y %m %d);

    my $timesheet = TKS::Timesheet->new();

    foreach my $date ( @dates ) {
        die "Invalid date '$date'" unless $date =~ m{ \A ( \d\d\d\d ) - ( \d\d ) - ( \d\d ) \z }xms;

        $self->{mech}->get("/form.php?f=timelist&user_no=$self->{wrms_user_no}&uncharged=1&from_date=$date&to_date=$date");

        my $dom = $self->parse_page;
        my ($table) = grep { $_->findnodes('./tr[1]/*')->size == 13 } $dom->findnodes('//table');

        die "Couldn't find data table" unless $table;

        foreach my $row ( $table->findnodes('./tr') ) {
            my @data = map { $_->textContent } $row->findnodes('./td');
            next unless $data[2] and $data[2] =~ m{ \A (\d\d)/(\d\d)/(\d\d\d\d) \z }xms;

            my $entry = {
                date         => "$3-$2-$1",
                request      => $data[1],
                comment      => $data[6],
                time         => $data[3],
                needs_review => $data[8],
            };

            next unless $entry->{date} eq $date;

            unless ( $entry->{time} =~ m{ \A ( [\d.]+ ) \s hours \z }xms ) {
                die "Can't parse hours from time '$entry->{time}'";
            }
            $entry->{time} = $1;

            $entry->{needs_review} = $entry->{needs_review} =~ m{ review }ixms ? 1 : 0;

            $timesheet->addentry(TKS::Entry->new($entry));
        }
    }
    return $timesheet;
}

sub delete_timesheet {
    my ($self, $timesheet) = @_;

    foreach my $entry ( $timesheet->entries ) {
        my $data = to_json({
            work_on          => $entry->date,
            request_id       => $entry->request,
            work_description => $entry->comment,
            hours            => 0,
        });
        $self->{mech}->post($self->baseurl . 'api.php/times/record', Content => $data);
        # method returns "old" hours
        unless ( $self->{mech}->content =~ m{ \A [\d.]+ \z }xms ) {
            die "Error: " . $self->{mech}->content;
        }
    }
}

sub add_timesheet {
    my ($self, $timesheet) = @_;

    my $existing = $self->get_timesheet($timesheet->dates);
    $existing->addtimesheet($timesheet);

    foreach my $entry ( $existing->compact->entries ) {
        my $data = to_json({
            work_on          => $entry->date,
            request_id       => $entry->request,
            work_description => $entry->comment,
            hours            => $entry->time,
        });
        $self->{mech}->post($self->baseurl . 'api.php/times/record', Content => $data);
        # method returns "old" hours
        unless ( $self->{mech}->content =~ m{ \A [\d.]+ \z }xms ) {
            die "Error: " . $self->{mech}->content;
        }
    }
}

sub save_timesheet {
    my ($self, $date, $timesheet) = @_;
};

sub parse_page {
    my ($self) = @_;

    my $dom;
    {
        local *STDERR;
        open STDERR, '>', '/dev/null';

        $dom = eval { $self->{parser}->parse_html_string($self->{mech}->content()) };
    }

    return $dom if defined $dom;

    die q{XML::LibXML couldn't parse '} . $self->{mech}->uri . q{': } . $@;
}


1;
