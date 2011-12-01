#!/usr/bin/perl

# Author: Matthew Hunt
# Copyright (C) 2011 Catalyst IT Ltd (http://www.catalyst.net.nz)
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

our $VERSION = '2.0.0';

use Modern::Perl;
use strict;
use warnings;

use Pod::Usage;
use Getopt::Long qw(GetOptions);
use TKS::Config;
use TKS::Date;

my (%opt);

if (!GetOptions(\%opt, 'help|h', 'version', 'list|l=s', 'section|s=s',
            'commit|c', 'directory|d')) {
    pod2usage('exitval' => 1, 'verbose' => 0);
} 

pod2usage('exitstatus' => 0, 'verbose' => 1) if $opt{help};
if ( $opt{version} ) {
    print "rerun-timesheet version $VERSION\n";
    exit 0;
}

$opt{section}   ||= config('rerun-timesheet', 'sections');
$opt{directory} ||= config('rerun-timesheet', 'directory');

# DEFAULT: extract all sections for previous day to current working
# directory and don't commit
$opt{list}      ||= 'yesterday';
$opt{section}   ||= 'all';
$opt{directory} ||= $ENV{PWD};
$opt{commit}    ||= 0;

# get the list of dates using TKS datespec
my $tksdate = TKS::Date->new($opt{list});

my @sections = split(",", $opt{section});

for my $section (@sections) {
    my $section_abbrev = substr(lc($section), 0, 3);

    for my $date ($tksdate->dates) {
        my $file = $opt{directory} . "/$date-${section_abbrev}.tks";

        # create file
        system("/usr/bin/hamster2tks", "-q", "-s", $section, "-l", $date, "-o", $file);

        if (-e $file && $opt{commit}) {
            system("/usr/bin/tks", "-q", "-s", $section, "-c", $file);
        }
        elsif (-e $file) {
            system("/usr/bin/tks", "-q", "-s", $section, $file);
        }
    }
}


exit(0);

__END__

=head1 NAME

rerun-timesheet - recreate and optionally commit timesheet for a date range

=head1 SYNOPSIS

B<rerun-timesheet> [B<-h>|B<--help>]

- display brief usage information

B<rerun-timesheet> [B<--version>]

- display version number

B<rerun-timesheet> [B<-l>|B<--list> I<datespec>] [B<-s>|B<--section> I<section>]
                [B<-d>|B<--directory> I<output directory>] [B<-c>|-B<--commit>]

- attempts to create a TKS file using the parameters provided and
  optionally commit the file to WRMS

=head1 DESCRIPTION

B<rerun-timesheet> is a simple wrapper around calls to the
C<hamster2tks> and C<tks> programs.  It runs the hamster2tks file
conversion for a provided date range and can also run the tks import
into WRMS for the generated files.

=head1 OPTIONS

=over 4

=item B<-h>|B<--help>

Show brief usage information for the program and exit.

=back

=over 4

=item B<--version>

Show version information for the program and exit.

=back

=over 4

=item B<-l> I<datespec>

Run for the requested dates. I<datespec> is a date specification as
documented in the L<tks(1)> manpage.

Default is 'yesterday'.

=back

=over 4

=item B<-s>|B<--section> I<section>

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

=item B<-d>|B<--directory> I<output file>

Specifies the directory to write output file to.

Can be specified in the B<.tksrc> file.

Default is current working directory.

=back

=over 4

=item B<-c>|B<--commit>

Specifies whether changes should be committed to WRMS using TKS.

Default is not to commit.

=back

=head1 Setting defaults

B<rerun-timesheet> reads defaults from the B<[rerun-timesheet]> section
of the standard L<tksrc(5)> file. There are keys for specifying the
output directory (B<directory>) and the default sections for reports
(B<sections>). For example:

    [rerun-timesheet]
    sections = EEC,Catalyst
    directory = /home/matt/timesheet

=head1 BUGS

Probably you can get it to do something wrong if you try hard.

=head1 AUTHOR

Matthew Hunt

=head1 SEE ALSO

L<http://projecthamster.wordpress.com/>

L<http://wiki.wgtn.cat-it.co.nz/wiki/TKS>

=cut
