#! /usr/bin/perl

use warnings;
use strict;

use File::Basename;
use File::stat;
use Encode;

use DateTime;
use XML::Atom::App;
use Perl6::Slurp;
use CGI::Carp 'fatalsToBrowser';
use CGI::Util qw(unescape);

use RRT::Misc;

my @atoms = ();

my $DocumentRoot = "/home/rrt";
my $BaseUrl = "http://localhost/~rrt";
my $path = "Log";
my @entries = readDir("$DocumentRoot/$path");
my @times = ();
#print STDERR "$#entries\n";
foreach my $entry (@entries) {
  push @times, stat("$DocumentRoot/$path/" . decode_utf8($entry))->mtime;
}
my @sorted = sort {$times[$b] <=> $times[$a]} 0 .. $#times;
my $text = "";
foreach (my $i = 0; $i <= $#sorted; $i++) {
  my $file = decode_utf8($entries[$sorted[$i]]);
  push @atoms, {
    title => $file,
    link => [{title => $file, href => "$BaseUrl/$path/$file"}],
    content => scalar(slurp "$DocumentRoot/$path/$file"),
    updated => XML::Atom::App->datetime_as_rfc3339(DateTime->from_epoch(epoch => $times[$sorted[$i]])),
   };
}

XML::Atom::App->new({
  title     => "Reuben Thomas: $path",
  author    => {name => "Reuben Thomas", email => "rrt\@sc3d.org", homepage => "http://rrt.sc3d.org/"},
  id        => "Reuben Thomas: $path",
  # FIXME: Use most recent time of feed entries?
  updated   => XML::Atom::App->datetime_as_rfc3339(DateTime->now),
  particles => \@atoms,
})->output_with_headers();
