#!/usr/bin/perl
# hamster2tks - makes a TKS file using details from Hamster
# Author: Matthew Hunt
# Copyright (C) 2010 Catalyst IT Ltd (http://www.catalyst.net.nz)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

our $VERSION = '1.0.0';

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long qw(GetOptions);
use FileHandle;
use DBI;
use TKS::Config;
use TKS::Date;
use POSIX;

my (%opt);

if (!GetOptions(\%opt, 'help|?', 'version', 'list|l=s', 'database|d=s',
    'section|s=s', 'output|o=s', 'quiet|q')) {
    pod2usage('exitval' => 1, 'verbose' => 0);
} 

pod2usage('exitstatus' => 0, 'verbose' => 1) if $opt{help};
if ( $opt{version} ) {
    print "hamster2tks version $VERSION\n";
    exit 0;
}

$opt{database} ||= config('hamster', 'db');
$opt{section}  ||= config('hamster', 'defaultsection');

# default to displaying all sections for the current date
$opt{list}     ||= 'today';
$opt{section}  ||= 'all';

my $output      = '';
my $total_hours = 0;

if ($opt{list}) {
    # get the list of dates using TKS datespec
    my $tksdate = TKS::Date->new($opt{list});

    my $dbh = DBI->connect("dbi:SQLite:dbname=$opt{database}","","");

    my $cat_sql     = '';
    my $category_id = ''; 
    # get the category ID if we are not selecting all categories
    if ($opt{section} ne 'all') {
        ($cat_sql, $category_id) = get_category_id_by_name($dbh, $opt{section});
    }

    # report the work for the selected section for each day in the
    # datespec list
    for my $date ($tksdate->dates) {
        my $day_hours = 0;

        my @activities = get_activities_by_date($dbh, $date, $cat_sql, $category_id);

        next if (!@activities);

        my $dow = '';
        if ( $date =~ m{ \A (\d\d\d\d)-(\d\d)-(\d\d) \z }xms ) {
            $dow = strftime('%A', 0, 0, 0, $3, $2 - 1, $1 - 1900);
        }
        $output .= "$date # $dow\n";
        for my $activity (@activities) {
            my $tags = get_tags_by_fact_id($dbh, $activity->{id});

            # try to get a WR number and a description from the activity
            # name; if the WR part isn't numeric, treat the whole string
            # as the WR number part for the TKS file
            my ($wr, $short_description) = split(/\s/,
            $activity->{name}, 2);
            if ($wr !~ /[0-9]/) {
                $wr .= " $short_description";
            }

            # if no tags are set, tries to use short description
            # instead; the last resort is just to use 'weekly timesheet'
            if (!$tags) {
                $tags = $short_description || 'weekly timesheet';
            }

            my $hours = int(($activity->{time} / 60) * 100) / 100;
            $day_hours += $hours;
            $output .= sprintf("%-13s %5.2f    %s\n", $wr, $hours, $tags);
        }
        $output .= sprintf("#             %5.2f    total hours\n\n", $day_hours);
        $total_hours += $day_hours;
    }

    # append total hours for the period
    $output .= sprintf("# Total hours: %0.2f\n\n", $total_hours);
}

if ($total_hours <= 0) {
    if (!$opt{quiet}) {
        warn "No hours recorded for period.\n";
    }

    exit 1;
}

if ($opt{output}) {
    my $fh = FileHandle->new();
    if (!$fh->open("> $opt{output}")) {
        die "Failed to open file for output: $opt{output}\n$!\n";
    }
    $fh->print($output);
    $fh->close;

    exit 0;
}
else {
    print $output;

    exit 0;
}

sub get_category_id_by_name {
    my ($dbh, $name) = @_;

    my $cat_id;
    my $cat_sql;

    my $query = "SELECT id FROM categories WHERE name = ?";
    my $sth = $dbh->prepare($query);

    $sth->execute($name);
    $sth->bind_col(1, \$cat_id);
    $sth->fetch;

    if (defined $cat_id) {
        $cat_sql = " AND activities.category_id = ?";
    }

    return ($cat_sql, $cat_id);
}

sub get_tags_by_fact_id {
    my ($dbh, $id) = @_;
    my $tag_name;
    my @tags = ();

    my $query =<<EOTagSQL;
SELECT tags.name
  FROM fact_tags LEFT JOIN tags ON (fact_tags.tag_id = tags.id)
 WHERE fact_id = ?
EOTagSQL

    my $sth   = $dbh->prepare($query);

    $sth->bind_col(1, \$tag_name);
    $sth->execute($id);
    while ($sth->fetch) {
        push @tags, $tag_name;
    }
    my $tags = join(", ", @tags);

    return $tags;
}

sub get_activities_by_date {
    my ($dbh, $date, $cat_sql, $cat_id) = @_;

    my $start = $date . " 00:00:00";
    my $end   = $date . " 23:59:59";
    my ($id, $name, $minutes);

    my $query =<<EOActivitySQL;
SELECT facts.id, activities.name,
       ((strftime('%s', end_time) - strftime('%s', start_time))/60) AS minutes
  FROM facts LEFT JOIN activities ON (facts.activity_id = activities.id)
 WHERE start_time > ? AND start_time < ? AND end_time IS NOT NULL
EOActivitySQL

    if (defined $cat_id) {
        $query .= $cat_sql;
    }

    my $sth = $dbh->prepare($query);
    $sth->bind_columns(\$id, \$name, \$minutes);
    if ($cat_id) {
        $sth->execute($start, $end, $cat_id);
    }
    else {
        $sth->execute($start, $end);
    }

    my @activities = ();
    while ($sth->fetch) {
        push @activities,
         {'id' => $id, 'name' => $name, 'time' => $minutes};
    }

    return @activities;
}

exit 0;

__END__

=head1 NAME

hamster2tks - creates TKS files using details from Hamster

=head1 SYNOPSIS

B<hamster2tks> [B<-h>]

- display brief usage information

B<hamster2tks> [B<--version>]

- display version number

B<hamster2tks> [B<-q>] [B<-d> I<database>] [B<-l> I<datespec>] [B<-s> I<section>] [B<-o> I<output file>]

- attempts to create a TKS file using the parameters provided

=head1 DESCRIPTION

B<hamster2tks> is a utility that reads details from the Hamster applet's
sqlite database and converts them into a format suitable for use with
TKS. See L<http://projecthamster.wordpress.com/> for more information on
the Hamster applet, L<http://wiki.wgtn.cat-it.co.nz/wiki/TKS> for more
information on TKS, and
L<http://wiki.wgtn.cat-it.co.nz/wiki/Timesheeting> for a description of
timesheeting within the company.

=head1 OPTIONS

=over 4

=item B<-h>

Show brief usage information for the program and exit.

=back

=over 4

=item B<--version>

Show version information for the program and exit.

=back

=over 4

=item B<-q>

Quiet operation. Prevents a warning from being emitted when no timesheet
details are found for the given datespec. This is recommended when using
B<hamster2tks> from cron.

=back

=over 4

=item B<-d> I<database>

Specifies the location of the Hamster applet's sqlite database file.

Can be specified in the B<.tksrc> file.

=back

=over 4

=item B<-l> I<datespec>

Produce a report for the requested dates. I<datespec> is a date
specification as documented in the L<tks(1)> manpage.

Default is 'today'.

=back

=over 4

=item B<-s> I<section>

If you use multiple WRMS backends (this only applies to people who do
work for the Electoral Enrolment Centre as well as work for other
clients), the B<section> argument allows you to select a Hamster
category to report on. In this case it is recommended that you use two
categories (EEC and Catalyst) to distinguish the backend to which
timesheet entries belong.

Can be specified in the B<.tksrc> file.

Default is 'all'.

=back

=over 4

=item B<-o> I<output file>

Specifies the location of an output file for the generated TKS
timesheet.

Default is to print to standard output.

=back

=head1 Setting defaults

B<hamster2tks> reads defaults from the B<[hamster]> section of the
standard L<tksrc(5)> file. There are keys for specifying the location of
the hamster database file (B<db>) and the default section for reports
(B<defaultsection>). For example:

    [hamster]
    db = /home/user/.local/share/hamster-applet/hamster.db
    defaultsection = all

=head1 BUGS

Behaviour is undefined if your hamster timesheet entry crosses a day
boundary.

No output is created for timesheet entries that are currently in
progress.

=head1 AUTHOR

Matthew Hunt

=head1 SEE ALSO

L<http://projecthamster.wordpress.com/>

L<http://wiki.wgtn.cat-it.co.nz/wiki/TKS>

=cut
