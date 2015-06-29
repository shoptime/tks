package TKS::Backend::Opcode;

use 5.018;
use strict;
use warnings;
use base 'TKS::Backend';

use TKS::Timesheet;
use URI;
use LWP::UserAgent;
use JSON::XS;
use DateTime;

# Sample .tksrc stuff:
#
#   [sample]
#   defaultfile=~/doc/timesheet.tks
#   defaultfilter=week
#   backend = TKS::Backend::Sample
#   configparam1 = configvalue1
#

sub datetime_for_date {
    my ($date) = @_;

    my ($year, $month, $day) = $date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/;
    my $dt = DateTime->new(
        year      => $year,
        month     => $month,
        day       => $day,
        hour      => 0,
        minute    => 0,
        second    => 0,
        time_zone => 'Pacific/Auckland',
    );
    return $dt;
}

sub epoch_for_date {
    my ($date, $hour) = @_;
    $hour //= 0;

    return datetime_for_date($date)->add(hours => $hour)->epoch;
}

sub init {
    my ($self) = @_;

    $self->{ua} = LWP::UserAgent->new(
        default_headers => HTTP::Headers->new(
            'X-Email' => $self->instance_config('username'),
            'X-Secret' => $self->instance_config('password'),
        ),
    );

    $self->{clients} = $self->get_json('clients');
}

sub get_json {
    my ($self, $path) = @_;

    my $res = $self->{ua}->get($self->url_for($path));
    die 'Failed request: ' . $res->status_line unless $res->is_success;

    return decode_json($res->decoded_content);
}

sub post_json {
    my ($self, $path, $payload) = @_;

    my $uri = $self->url_for($path);
    my $req = HTTP::Request->new('POST', $uri);
    $req->header('Content-Type' => 'application/json');
    $req->content(encode_json($payload));

    my $res = $self->{ua}->request($req);

    die 'Failed request: ' . $res->status_line unless $res->is_success;

    return decode_json($res->decoded_content);
}

sub url_for {
    my ($self, $path) = @_;

    my $site = $self->instance_config('site');
    $site ||= 'https://billing.opcode.co.nz';
    $site =~ s{/$}{};

    my $url = URI->new($site);

    $url->path_segments($url->path_segments, 'api', split('/', $path));

    return $url;
}

sub get_timesheet {
    my ($self, $dates, $user) = @_;

    my $timesheet = TKS::Timesheet->new;

    my $entries = $self->get_json('entry/list/' . epoch_for_date($dates->mindate) . '/' . datetime_for_date($dates->maxdate)->add(days => 1)->epoch);

    for my $entry (@{$entries}) {
        my $date = DateTime->from_epoch(epoch => $entry->{start});
        my $hours = ($entry->{stop} - $entry->{start}) / 3600;
        $timesheet->addentry(TKS::Entry->new(
            date         => $date->strftime('%F'),
            request      => $entry->{client} . '/' . $entry->{facet},
            comment      => $entry->{description},
            time         => $hours,
            needs_review => 0,
        ));
    }

    return $timesheet->compact;
}

sub add_timesheet {
    my ($self, $timesheet, $show_progress) = @_;

    foreach my $entry ($timesheet->entries) {
        die 'Invalid request "' . $entry->request . '"' unless $self->valid_request($entry->request);
    }

    my $existing = $self->get_timesheet($timesheet->dates);
    my $target_timesheet = $timesheet->diff($existing->invert)->invert;

    my @entries;
    foreach my $entry (sort { $a->time <=> $b->time } $timesheet->compact->entries) {
        my ($client, $facet) = split(m{/}, $entry->request, 2);

        my ($year, $month, $day) = $entry->date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/;
        my $date = DateTime->new(
            year      => $year,
            month     => $month,
            day       => $day,
            hour      => 8,
            minute    => 0,
            second    => 0,
            time_zone => 'Pacific/Auckland',
        );

        push @entries, {
            client      => $client,
            facet       => $facet,
            description => $entry->comment,
            start       => epoch_for_date($entry->date, 8),
            stop        => epoch_for_date($entry->date, 8) + 3600 * $entry->time,
        };
    }

    my $replace_from = epoch_for_date($timesheet->dates->mindate);
    my $replace_to = datetime_for_date($timesheet->dates->maxdate)->add(days => 1)->epoch;

    $self->post_json('entry/add', {
        replace_range => {
            from => $replace_from,
            to   => $replace_to
        },
        entries => \@entries,
    });
}

sub valid_request {
    my ($self, $request) = @_;

    my ($client_slug, $facet_slug) = split(m{/}, $request, 2);

    my ($client) = grep { $_->{slug} eq $client_slug } @{$self->{clients}};

    return 0 unless $client;

    my ($facet) = grep { $_->{slug} eq ($facet_slug // '') } @{$client->{facets}};

    return 0 unless $facet;

    return 1;
}

1;

