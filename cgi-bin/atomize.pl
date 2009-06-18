#! /usr/bin/perl
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
use XML::Atom::Feed;
use XML::Atom::Entry;
use XML::Atom::Link;
use XML::Atom::Person;

use RRT::Misc;


# Adapted from XML::Atom::App
sub datetime_as_rfc3339 {
  my ($dt) = @_;
  $dt = DateTime->new(@{$dt}) if ref $dt eq 'ARRAY';
  my $offset = $dt->offset != 0 ? '%z' : 'Z';
  return $dt->strftime('%FT%T$offset');
}

# Read arguments
my ($DocumentRoot, $BaseUrl, $path, $AuthorName, $AuthorEmail) = @ARGV;

# Read files
my @entries = readDir("$DocumentRoot/$path");
my @times = ();
foreach my $entry (@entries) {
  push @times, stat("$DocumentRoot/$path/" . decode_utf8($entry))->mtime;
}
my @sorted = sort {$times[$b] <=> $times[$a]} 0 .. $#times;

# Create feed
my $feed = XML::Atom::Feed->new;
$feed->title("$AuthorName: $path");
my $author = XML::Atom::Person->new;
$author->name($AuthorName);
$author->email($AuthorEmail);
$author->homepage($BaseUrl);
$feed->author($author);
$feed->id("$AuthorName: $path");
$feed->updated(datetime_as_rfc3339(DateTime->now));

# Add entries
for (my $i = 0; $i <= $#sorted; $i++) {
  my $file = decode_utf8($entries[$sorted[$i]]);
  my $entry = XML::Atom::Entry->new;
  my $title = fileparse($file, qr/\.[^.]*/);
  $entry->title($title);
  #$entry->id("$AuthorName: $path/$file $date"); FIXME: generate this
  my $link = XML::Atom::Link->new;
  $link->type(getMimeType($file)); # FIXME: give correct type
  $link->href("$BaseUrl$path/$file");
  $entry->add_link($link);
  $entry->content(scalar(slurp '<:crlf:utf8', "$DocumentRoot/$path/$file"));
  $entry->updated(datetime_as_rfc3339(DateTime->from_epoch(epoch => $times[$sorted[$i]])));
  $feed->add_entry($entry);
}

print $feed->as_xml;
