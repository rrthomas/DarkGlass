#! /usr/bin/perl -T
# DarkGlass
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2023
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

use utf8;
use strict;
use warnings;

use CGI qw(:standard);

use lib ".";
use DarkGlass;


# Configuration

# Set locale (for correct handling of non-ASCII filenames)
#$ENV{'LANG'} = "en_GB.UTF-8";
# URL of server
$DarkGlass::ServerUrl = "https://rrthomas.github.io";
# Root of site relative to root of server
$DarkGlass::BaseUrl = "/DarkGlass/";
# Directory of site in file system
$DarkGlass::DocumentRoot = "../doc";
# Site name
$DarkGlass::Title = "DarkGlass";
# Site owner's name and email address
$DarkGlass::Author = "Reuben Thomas";
$DarkGlass::Email = "rrt\@sc3d.org";


# Perform the request
# Command-line arguments are supplied when we run in static mode
DarkGlass::doRequest(@ARGV);
