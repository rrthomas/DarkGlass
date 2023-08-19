# DarkGlass

Reuben Thomas (rrt@sc3d.org)

DarkGlass is a simple content management system that exports a
directory tree to the web. It displays different file types
appropriately, uses file permissions to determine which files and
directories should be exported, has a customizable navigation panel,
and uses Markdown for rapid creation of simple web pages from plain
text files.

DarkGlass is meant to be simple to use, simple to install and
maintain, and its code should be easy to understand. It is released
under the GNU General Public License version 3, or (at your option)
any later version. There is no warranty.

See https://rrt.sc3d.org/Software/DarkGlass for more information.


## Source code organization

The files are organised as follows:

=`README.dg.md`=
    is a quick introduction.
=`cgi-bin`=
    contains the main DarkGlass program `DarkGlass.pm`, some helper modules in `MIME` and `RRT`, and the front-end script and configuration file `web.pl`.
=`*.md`=
    The DarkGlass documentation.
