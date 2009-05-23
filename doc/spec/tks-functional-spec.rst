TKS: Functional Specification
=============================

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


