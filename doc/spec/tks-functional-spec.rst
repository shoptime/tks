TKS: Functional Specification
=============================

Overview
--------

TKS is an attempt to make timesheeting less painful by allowing people to edit
their timesheets in a text file with a simple, human-readable format. As it is
easy to record time in a text file, this will encourage accurate timesheeting,
and make it easier to submit timesheets promptly to a timekeeping system.

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
highlighted, and informs him to run tks again on the file with -c to commit the
work. He does this. TKS asks for his WRMS username and password, and asks if he
wants to store that information in his .tksrc file. He says 'yes'. His
information is then committed to WRMS.

He likes this, and wants to download his timesheets for the last two weeks. He
runs tks with the options to do so. tks spits out the timesheets on stdout,
which he redirects to a file. As he asked tks to remember his WRMS details, he
wasn't asked for those again.

Martyn sees that there is a mistake in his timesheets for last week. He edits
the file he got previously, changing one block of work to take two hours
instead of one, and deleting another block. He then runs tks on that file. tks
deletes all the timesheets on the only affected day, then inserts them again as
they're recorded in the file.

Later, Martyn sees that he made a mistake three months ago that he needs to
fix. He runs tks with the options to edit the timesheets for a given day. His
editor is fired up with tks data in it already. He changes it and closes the
editor, at which point the file contents are committed to WRMS.

Specification
-------------

Program Installation and Setup
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

TKS should be able to be run directly from a checkout of the git repository
from where it was cloned, by running ./tks.pl.

From a git checkout, it should be possible to build and install all the tks
debian package simply by typing 'make'.

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

The configuration file will be in "ini" [1]_ style format, as this is an easy
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

.. [1] The ini file format is a de facto standard. tks will support all the
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
First, some general principles of tks input and output.

Datespecs
~~~~~~~~~

Some command line arguments take a 'datespec' as their value. Datespecs
represent a list of one or more dates. A datespec itself is a list of one or
more *dateparts*, separated by commas. A datepart is either a date, or a
mnemonic that represents a date or list of dates.

==========   ==================================================================================== ==========
Datepart     Description                                                                          Example
==========   ==================================================================================== ==========
YYYY-MM-DD   The day specified                                                                    2009/05/25
YY-MM-DD     The day specified. The year is considered to be in the 21st century.                 09/05/25
today        The current day
yesterday    The day before today
lastweek     The seven days beginning from Monday and ending on the Sunday before the current day
thismonth    The calendar month enclosing the current date
lastmonth    The calendar month before the month enclosing the current date
==========   ==================================================================================== ==========

Colourising output
~~~~~~~~~~~~~~~~~~

tks --help
~~~~~~~~~~

TODO:throw error if user does more than one of -c, -e, and -l
TODO: -s defaults to 'default'

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
~~~~~~~~~~~~~

This option will cause TKS to print its version number and exit immediately
with exit status 0::

    nigel@bourdon:~$ tks --version
    1.0.0
    nigel@bourdon:~$ 

tks -s <section>
~~~~~~~~~~~~~~~~

Whenever the ``-s`` option is present, this will cause tks to use the backend
specified by the appropriate section in the configuration file. If the
specified section is not present, tks will print an error message and exit
immediately with exit status 1::

    nigel@bourdon:~$ tks -s badsection
    Error: the section `badsection' is not defined in your configuration file

tks --no-color
~~~~~~~~~~~~~~

Whenever the --no-color option is present, tks must not produce any output with the ANSI escape sequences to colourise the output.


Vim Syntax Highlighting
^^^^^^^^^^^^^^^^^^^^^^^

