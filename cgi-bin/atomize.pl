#! /usr/bin/perl
# FIXME: -T
# atomize
# Turn a directory into an Atom feed
# (c) Reuben Thomas <rrt@sc3d.org> 2008-2009
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

use warnings;
use strict;

use File::stat;
use Encode;

use Perl6::Slurp;
use File::Basename;
use DateTime;
use CGI::Util qw(escape);
use XML::Atom::Feed;
use XML::Atom::Entry;
use XML::Atom::Link;
use XML::Atom::Person;

use RRT::Misc;
use DarkGlass::Render;


 $XML::Atom::DefaultVersion = "1.0";

# Adapted from XML::Atom::App
sub datetime_as_rfc3339 {
  my ($dt) = @_;
  $dt = DateTime->new(@{$dt}) if ref $dt eq 'ARRAY';
  my $offset = $dt->offset != 0 ? '%z' : 'Z';
  return $dt->strftime('%FT%T$offset');
}

# Read arguments
my ($DocumentRoot, $ServerUrl, $BaseUrl, $Path, $AuthorName, $AuthorEmail) = @ARGV;

# Read files
my @entries = readDir("$DocumentRoot/$Path");
my @times = ();
foreach my $entry (@entries) {
  push @times, stat("$DocumentRoot/$Path/" . decode_utf8($entry))->mtime;
}
my @sorted = sort {$times[$b] <=> $times[$a]} 0 .. $#times;

# Create feed
my $feed = XML::Atom::Feed->new;
$feed->title("$AuthorName: $Path");
my $author = XML::Atom::Person->new;
$author->name($AuthorName);
$author->email($AuthorEmail);
$author->homepage("$ServerUrl$BaseUrl");
$feed->author($author);
$feed->id("$ServerUrl$BaseUrl$Path"); # FIXME: Escape components of $Path
$feed->updated(datetime_as_rfc3339(DateTime->now));
$feed->icon("$ServerUrl${BaseUrl}favicon.ico");

# Add entries
for (my $i = 0; $i <= $#sorted; $i++) {
  my $file = decode_utf8($entries[$sorted[$i]]);
  my $entry = XML::Atom::Entry->new;
  my $title = fileparse($file, qr/\.[^.]*/);
  $entry->title($title);
  $entry->id("$ServerUrl$BaseUrl$Path/" . escape($file)); # FIXME: Improve this. See http://diveintomark.org/archives/2004/05/28/howto-atom-id; at least escape components of $Path
  my $link = XML::Atom::Link->new;
  my ($text, $desttype) = DarkGlass::Render::render("$DocumentRoot/$Path/$file", "$Path/$file", getMimeType("$DocumentRoot/$Path/$file"), "text/html", $ServerUrl, $BaseUrl, $DocumentRoot);
  $entry->content($text);
  $link->type($desttype);
  $link->href("$ServerUrl$BaseUrl$Path/$file");
  $entry->add_link($link);
  $entry->updated(datetime_as_rfc3339(DateTime->from_epoch(epoch => $times[$sorted[$i]])));
  $feed->add_entry($entry);
}

print $feed->as_xml;
