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

use strict;
use warnings;

use Pod::Usage;
use Getopt::Long qw(GetOptions);
use TKS::Backend;
use TKS::Config;
use TKS::Date;
use Term::ANSIColor;

my(%opt);

if(!GetOptions(\%opt, 'help|?', 'section|s=s', 'list|l=s', 'edit|e=s', 'commit|c', 'no-color', 'user|u=s', 'filter|f=s')) {
    pod2usage(-exitval => 1,  -verbose => 0);
}

pod2usage(-exitstatus => 0, -verbose => 1) if $opt{help};

$opt{filename} = shift;

$opt{section} ||= 'default';
$opt{filename} ||= config($opt{section}, 'defaultfile');


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
    my $timesheet = TKS::Timesheet->from_file($filename);
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

=cut



