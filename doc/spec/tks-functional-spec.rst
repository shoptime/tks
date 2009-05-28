TKS: Functional Specification
=============================

:author: Nigel McNie
:date: 2009-05-28
:version: 0.9
:copyright: |copy| 2009 Nigel McNie

.. |copy| unicode:: 0xA9

This work is licensed under a `Creative Commons Attribution-Share Alike 3.0
Unported License <http://creativecommons.org/licenses/by-sa/3.0/>`__.

.. contents::
.. sectnum::

Overview
--------

TKS is an attempt to make timesheeting less painful by allowing people to edit
their timesheets in a text file with a simple, human-readable format. As it is
easy to record time in a text file, this will encourage accurate timesheeting,
and make it easier to submit timesheets promptly to a timekeeping system.

Furthermore, it provides a command line interface to exchange timesheet
information with timekeeping systems, keeping bearded geeks happy and lowering
barriers to script timesheet entry and modification [#]_.

.. [#] TKS is not responsible for your timekeeping habits. A tool is only as
       powerful as the tool using it, etc.

Use cases
---------

Martyn installs tks and tks-backend-wrms, and runs it for the first time. It
prints a summary of usage. This summary suggests he can do a few things:

 - start timesheeting in a new file
 - view his timesheets for one or more days
 - edit his existing timesheets for a given day

Martyn makes a new file (time.tks). As he is using vim, syntax highlighting is
available. He writes a day's worth of timesheets and :wq's.

Martyn runs tks on his file. It prints out the information in the file, syntax
highlighted, and informs him to run tks again on the file with ``-c`` to commit
the work. He does this. TKS asks for his WRMS username and password, and asks
if he wants to store that information in his .tksrc file. He says 'yes'. His
information is then committed to WRMS.

He likes this, and wants to download his timesheets for the last two weeks. He
runs TKS with the options to do so. TKS spits out the timesheets on stdout,
which he redirects to a file. As he asked tks to remember his WRMS details, he
wasn't asked for those again.

Martyn sees that there is a mistake in his timesheets for last week. He edits
the file he got previously, changing one block of work to take two hours
instead of one, and deleting another block. He then runs TKS on that file. TKS
deletes all the timesheets on the only affected day, then inserts them again as
they're recorded in the file.

Later, Martyn sees that he made a mistake three months ago that he needs to
fix. He runs TKS with the options to edit the timesheets for a given day. His
editor is fired up with tks data in it already. He changes it and closes the
editor, at which point the file contents are committed to WRMS.

Pleased with his prompt and accurate timesheeting, his bosses give him a large
raise.

Specification
-------------

Program Installation and Setup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

TKS should be able to be run directly from a checkout of the git repository
from where it was cloned, by running ./tks.pl.

From a git checkout, it should be possible to build and install all the tks
debian package simply by running ``make``.

A full suite of documentation should be buildable from a git checkout also, by
running ``make docs``.

The following packages should be built:

================  =======================================  =========================================================================
Package           Dependencies                             Purpose
================  =======================================  =========================================================================
tks               tks-backend                              Provides the tks binary and installs any tks-specific libraries required.
tks-backend       tks-backend-wrms | tks-backend-zebra...  A virtual package that depends on one of the available backends
tks-backend-wrms                                           Provides a WRMS backend for tks
tks-doc                                                    Provides all documentation in /usr/share/doc/tks
================  =======================================  =========================================================================

When the tks package is installed, it should provide a 'tks' binary in
/usr/bin.

Configuration File
^^^^^^^^^^^^^^^^^^

The configuration file provides users with a way to configure their
installation of tks, to make using it easier and faster.

The configuration file will be in "ini" [#]_ style format, as this is an easy
configuration format to read and write.

TKS will search for the config file in the following locations in order, using
the first one it encounters:

- ``$HOME/.rc/tks``
- ``$HOME/.tksrc``

INI files are broken up into sections. Each section can contain any number of
parameters. In lieu of providing a detailed specification, here is an example
INI file that could be used with tks::

    [default]
    site = https://wrms.catalyst.net.nz
    username = myusername
    password = secretpassword

    [othersystem]
    site = http://example.org/
    backend = WRMS

    [wrmap]
    email       = 17
    mahara      = 1235

This example file has three sections - *default*, *othersystem* and *wrmap*.
The section entitled *wrmap* will be used by tks to substitute human-readable
names for work request numbers in TKS files it parses. All other sections
correspond to systems that TKS is able to access.

.. [#] The ini file format is a de facto standard. tks will support all the
       features of ini files that the perl module Config::Inifiles supports

The 'wrmap' Section
~~~~~~~~~~~~~~~~~~~

This section provides a mapping from alphanumeric names for work requests to
their actual identifier. See the TKS file format for more details about this
feature.

System Sections
~~~~~~~~~~~~~~~

All sections not entitled 'wrmap' are system sections. They represent a system
that TKS can access.

The section entitled 'default' represents the system that TKS will perform
operations against, if the ``-s`` parameter is not passed to it.

None of the parameters in a system section are required. The only one that has
meaning to TKS itself is 'backend'. This parameter is the name of a perl module
implementing the TKS Backend API, and defaults to 'WRMS'.

Backends will likely need more configuration. It should be possible for
backends to store this configuration in the system section as parameters, so
that users can edit it themselves.

Running tks
^^^^^^^^^^^

The TKS binary takes several command line options, which are documented below.

General Concepts of TKS Input/Output
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Datespecs
#########

Some command line arguments take a 'datespec' as their value. Datespecs
represent a list of one or more dates. A datespec itself is a list of one or
more *dateparts*, separated by commas. Some example datespecs::

    # this exact date
    2009/05/25
    # whatever date 'yesterday' was
    yesterday
    # All days from the 25th of May to the 3rd of June inclusive, and the 1st of August
    2009-05-25..2009-06-03,2009-08-01
    # From the first day of last month until the last day of last week, and today
    lastmonth..lastweek,today

A datepart can represent just one date, or a list of dates. A datepart is
either one *datetoken*, or two datetokens separated by ``..``.

Datetokens are specified either in a standard date format, or are mnemonics
representing dates. The mnemonic forms can be modified with ``^`` notation to
retrieve previous dates or ranges of dates as appropriate.

==========   ============================================================================================== ========== ==========================
Datetoken    Description                                                                                    Example    Mnemonic meaning/examples
==========   ============================================================================================== ========== ==========================
YYYY-MM-DD   The day specified                                                                              2009-05-25
YYYY/MM/DD   The day specified                                                                              2009/05/25
DD/MM/YYYY   The day specified. The year is considered to be in the 21st century.                           25/05/2009
DD/MM/YY     The day specified. The year is considered to be in the 21st century.                           25/05/09
day          The current day                                                                                           Subtract one day. day^ = yesterday
today        The current day                                                                                           Same as for 'day'
yesterday    The day before today                                                                                      Subtract one day. yesterday^ = the day before yesterday
week         The seven days beginnning from Monday and ending on Sunday in which the current date resides              Subtract 7 days from each day in the list. week^ = lastweek
thisweek     Synonym for week                                                                                          Same as for 'week'
lastweek     Synonym for week^                                                                                         Same as for 'week'
month                                                                                                                  Replace the list of dates with the list of dates in the previous month. If thismonth is July, thismonth^ is June.
thismonth    The calendar month enclosing the current date                                                             Same as for 'month'
lastmonth    Synonym for thismonth^                                                                                    Same as for 'month'
==========   ============================================================================================== ========== ==========================

``^`` notation means suffixing a datetoken with either one or more ``^``
characters, or one ``^`` character followed by a positive integer, which is
shorthand for the number of times the ``^`` modifier would have appeared if
written out in full::

    ^^^ = ^3
    ^^^^ = ^4

Colourising Output
##################

When TKS is outputting a TKS file, *and* stdout is connected to a tty, *and*
the option ``--no-color`` has **not** been passed, TKS should output the file
in colour.

If even one of those conditions is not met, TKS should output the file without
any colouring.

TKS Commands
~~~~~~~~~~~~

The options that the ``tks`` binary takes are listed here. The general options
may be used on any invocation of TKS, though only one of each option is allowed
to be specified. If the passed command line options do not exactly match the
format of any of the commands in this section, tks should exit with an error
message and error code 1.

General Options
###############

The following options can apply to any invocation of ``tks``.

-s <section>
************

Whenever the ``-s`` option is present, this will cause tks to use the backend
and configuration options specified by the appropriate section in the
configuration file. If the specified section is not present, tks will print an
error message and exit immediately with exit status 1::

    nigel@bourdon:~$ tks -s badsection
    Error: the section `badsection' is not defined in your configuration file

If the ``-s`` option is not passed, tks is to behave as if ``-s default`` was
passed to it.

--no-color
**********

Whenever the --no-color option is present, tks must not produce any output with
the ANSI escape sequences to colourise the output.

tks [filename]
##############

Running ``tks`` passing just a file name will cause TKS to parse the file as if
it were a TKS file, and if successful, print the information found to stdout.
Output will be colourised if stdout is a tty and ``--no-color`` has not been
passed as an option.

If filename is ``-``, tks reads from stdin rather than looking for a file.

If the filename is not specified, then tks looks for the 'defaultfile'
configuration setting for the section being used (see ``-s``).

If that is not specified, tks prints an error message and exits with error code
1.

tks --help
##########

Running ``tks --help`` will print the following message and exit immediately
with exit status 0::

    nigel@bourdon:~$ tks
    Usage: tks [options] [-s <section>] <file> 
           tks --help
           tks --version

    Options:

        -s                          Use the configuration for the named section
                                    in your configuration file
        --no-color                  Don't output with syntax-highlighting
                                    (default: use colour if stdout is a tty)

    Options (with a file name):

        -c                          Write data to the backend (by default just
                                    prints what _would_ happen)

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
    nigel@bourdon:~$ 

tks --version
#############

This option will cause TKS to print its version number and exit immediately
with exit status 0::

    nigel@bourdon:~$ tks --version
    1.0.0
    nigel@bourdon:~$ 

tks -c [filename]
#################

TODO

tks -l <datespec>
#################

TODO

tks -e <datespec>
#################

TODO

Backends
^^^^^^^^

TODO: relationship between backend configuration parameters and the configuration file.

WRMS
~~~~

TODO: configuration parameters, behaviour when initialised.


TKS File Format
^^^^^^^^^^^^^^^

Vim Syntax Highlighting
^^^^^^^^^^^^^^^^^^^^^^^
