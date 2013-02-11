#! /usr/bin/perl -T
# DarkGlass
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2013
# http://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

# FIXME: Remove cgi-bin from PATH
BEGIN { # Run before "use" statements so variables are defined for other modules' initialization
  $ENV{HOME} = '/home/rrt';
  $ENV{PATH} = "$ENV{HOME}/public_html/cgi-bin:/usr/local/bin:/bin:/usr/bin";
}

use utf8;
use strict;
use warnings;

use CGI qw(:standard);

use lib ".";
use DarkGlass;


# Configuration

# URL of server
$DarkGlass::ServerUrl = "http://skwd.it.cx";
# Root of site relative to root of server
$DarkGlass::BaseUrl = "/~rrt/";
# Directory of site in file system
$DarkGlass::DocumentRoot = "/home/rrt";
# Site owner's name and email address
$DarkGlass::Author = "Reuben Thomas";
$DarkGlass::Email = "rrt\@sc3d.org";


# Perform the request
DarkGlass::doRequest();
