#!/usr/bin/perl
# DarkGlass
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2024
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

use strict;
use warnings;

use lib ".";
use DarkGlass;


# Configuration

# Root of site relative to root of server
$DarkGlass::BaseUrl = "/DarkGlass/";
# Directory of site in file system
$DarkGlass::DocumentRoot = "../doc";
# Site name
$DarkGlass::Title = "DarkGlass";
# Site owner's name and email address
$DarkGlass::Author = "Reuben Thomas";
$DarkGlass::Email = "rrt\@sc3d.org";
# Command to render Markdown to HTML
$DarkGlass::Renderer = "";


# Perform the request
DarkGlass::doRequest(@ARGV);
