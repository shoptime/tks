#!/usr/bin/perl
# tks: Time keeping sucks. TKS makes it suck less.
# Author: Martyn Smith
# Copyright (C) 2009 Catalyst IT Ltd (http://www.catalyst.net.nz)
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

our $VERSION = '1.0.1';

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long qw(GetOptions);
use TKS::Backend;
use TKS::Config;
use TKS::Date;
use Term::ANSIColor;

my(%opt);

if(!GetOptions(\%opt, 'help|?', 'version', 'section|s=s', 'list|l=s', 'edit|e=s', 'commit|c', 'no-color', 'user|u=s', 'filter|f=s', 'force')) {
    pod2usage(-exitval => 1,  -verbose => 0);
}

pod2usage(-exitstatus => 0, -verbose => 1) if $opt{help};
if ( $opt{version} ) {
    print "tks version $VERSION\n";
    exit 0;
}

$opt{filename} = shift;

$opt{section} ||= 'default';

if ( length(join('', map { $opt{$_} ? 'x' : '' } qw(commit list edit))) > 1) {
    pod2usage(-exitval => 1, -message => "Options commit, list, and edit are mutually exclusive\n", -verbose => 0);
}

my $filename = $opt{filename} || config($opt{section}, 'defaultfile');
$filename =~ s{ \A ~ / }{"$ENV{HOME}/"}xmse if defined $filename;

my $backend = TKS::Backend->new($opt{section});

if ( $opt{list} ) {
    if ( $opt{filename} ) {
        pod2usage(-verbose => 0, -exitval => 1, -message => "using --list with a filename is not supported");
    }
    my $timesheet = $backend->get_timesheet(TKS::Date->new($opt{list}), $opt{user});
    ts_print($timesheet);
}
elsif ( $opt{edit} ) {
    if ( $opt{filename} ) {
        pod2usage(-verbose => 0, -exitval => 1, -message => "using --list with a filename is not supported");
    }
    my $timesheet = $backend->get_timesheet(TKS::Date->new($opt{edit}));
    my $new_timesheet = $timesheet->edit();

    if ( $new_timesheet ) {
        my $diff = $timesheet->diff($new_timesheet);
        $backend->add_timesheet($diff);
        ts_print($new_timesheet);
    }
    else {
        print "Timesheet wasn't saved, no modifications made\n";
    }
}
else {
    die "No file specified" unless $filename;
    die "File $filename not readable" unless -r $filename;
    my $timesheet = TKS::Timesheet->from_file($filename, $opt{force});
    my $filter_warning;

    if ( $opt{filter} ) {
        $filter_warning = $timesheet->time;
        $timesheet = $timesheet->filter_date($opt{filter});
        $filter_warning -= $timesheet->time;
    }

    $timesheet->backend($backend);
    ts_print($timesheet);
    if ( $opt{commit} ) {
        my $existing = $backend->get_timesheet($timesheet->dates);
        my $diff = $existing->diff($timesheet);
        if ( $diff->entries ) {
            print STDERR "Committing ...\n";
            $backend->add_timesheet($diff, 1);
        }
        else {
            print STDERR "No changes, nothing to commit\n";
        }
    }
    if ( $filter_warning ) {
        my $color_on = ( -t STDOUT and not $opt{'no-color'} );
        printf
            "\n%swarning:%s %0.2f hours in your file %s%s%s fell outside the datespec %s%s%s and were not %s\n\n",
            $color_on ? color('bold red') : '',
            $color_on ? color('reset') : '',
            $filter_warning,
            $color_on ? color('bold blue') : '',
            $filename,
            $color_on ? color('reset') : '',
            $color_on ? color('bold blue') : '',
            $opt{filter},
            $color_on ? color('reset') : '',
            $opt{commit} ? 'committed' : 'displayed',
        ;
    }
}

sub ts_print {
    my ($timesheet) = @_;

    if ( -t STDOUT and not $opt{'no-color'} ) {
        print $timesheet->as_color_string;
    }
    else {
        print $timesheet->as_string;
    }
}


exit 0;

__END__

=head1 NAME

tks - Time keeping sucks. TKS makes it suck less.

=head1 DESCRIPTION

Time keeping sucks. TKS makes it suck less.

=head1 SYNOPSIS

  tks [options] [-s <section>] [<file>]
           tks --help
           tks --version

=head1 OPTIONS

        -s                          Use the configuration for the named section
                                    in your configuration file
        --no-color                  Don't output with syntax-highlighting
                                    (default: use colour if stdout is a tty)

    Options (with a file name):

        -c                          Write data to the backend (by default just
                                    prints what _would_ happen)
        -f <datespec>               Ignores all entries in the provided file
                                    that fall outside the given datespec (a
                                    warning will be printed if there are
                                    entries that fall outside this range)
        --force                     Turn recoverable errors into warnings when
                                    parsing file

    Options (without a file name):

        -l <datespec>               Lists timesheet entries for <datespec>
                                    (output is a valid TKS file)
        -e <datespec>               Open your $EDITOR with the entries for
                                    <datespec>, and after you've edited them,
                                    commit them to the system

    <datespec> can be many things: a date (YYYY-MM-DD), a list of dates and/or
    a mnemonic like 'yesterday'. Consult the manpage for more information.

    Example usage:

        tks mytime.tks            # Parse and output time recorded in this file
        tks -c mytime.tks         # Commit the time found in this file to the
                                  # default backend
        tks -s foo -e 2009-05-25  # Edit the time recorded in system 'foo' on
                                  # 2009/05/25
        tks -l lastweek,today     # Output all time recorded in the default
                                  # system from last week and today

=head1 DATESPECS

Some command line arguments take a 'datespec' as their value. Datespecs
represent a list of one or more dates. Some examples:

    # this exact date
    2009/05/25
    # whatever date 'yesterday' was
    yesterday
    # All days from the 25th of May to the 3rd of June inclusive, and the 1st of August
    2009-05-25..2009-06-03,2009-08-01
    # From the first day of last month until the last day of last week, and today
    lastmonth..lastweek,today

The examples should give you a feel for the allowed syntax, the following is a
more thorough description.

A datespec itself is a list of one or more *dateparts*, separated by commas. A
datepart can represent just one date, or a list of dates. A datepart is either
one *datetoken*, or two datetokens separated by ``..``.

Datetokens are specified either in a standard date format, or are mnemonics
representing dates. The mnemonic forms can be modified with ``^`` notation to
retrieve previous dates or ranges of dates as appropriate. Mnemonics are case
insensitive.

As an example, for the datespec 2009-05-25..2009-06-03,2009-08-01,today^:

  - There are three dateparts: the date range at the start, the first of August
    in the middle and the mnemonic at the end
  - The first datepart is a range, from the first date to the second, inclusive
  - The second datepart is exactly that date
  - The third datepart represents 'yesterday' (the mnemonic 'yesterday' works
    too)

=head1 EDITING TIMESHEETS WITHOUT A TKS FILE

You can do this with tks -e. If you accidentally filed a bunch of time for last
year, or Saturday when you meant Monday, simply run tks -e, change the date and
save/quit. The time will be moved to the new day.

Naturally, you can alter descriptions/add timesheets etc. in this manner also.

=head1 GETTING STARTED

Reading this manpage and simply running tks is a great start. You may also be
interested in the manpage for the "tksrc" file: man tksrc

=head1 BUGS

Please report bugs to bugzilla:
http://bugzilla.catalyst.net.nz/enter_bug.cgi?product=TKS

You can see a list of bugs here:
http://bugzilla.catalyst.net.nz/buglist.cgi?query_format=specific&order=relevance+desc&bug_status=__open__&product=TKS&content=

For those people using TKS not at Catalyst IT (greetz to Liip!) - please report
bugs to whomever introduced TKS to you. They'll get back to us eventually.

=head1 AUTHOR

tks is written by Martyn Smith and Nigel McNie. Martyn wrote almost all the code for this version, while Nigel criticised it constantly (he also helped by writing this documentation, which might make him redeemable).

=head1 SEE ALSO

tksrc(5), http://wiki.wgtn.cat-it.co.nz/wiki/TKS

=cut


