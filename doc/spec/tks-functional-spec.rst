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

.. [1] The ini file format is a de facto standard. tks will support all the features of ini files that the perl module Config::Inifiles supports

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

Explain all inputs and outputs. flowcharts?

Vim Syntax Highlighting
^^^^^^^^^^^^^^^^^^^^^^^

