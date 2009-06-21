# DarkGlass::Render
# Turn an object into HTML or an HTML link
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2009
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

require 5.8.7;
package DarkGlass::Render;

use utf8;
use strict;
use warnings;

use Perl6::Slurp;
use Encode;
use Cwd qw(abs_path);
use CGI::Pretty qw(:standard);
use CGI::Carp qw(fatalsToBrowser);

use RRT::Misc;
use RRT::Macro;
use MIME::Convert;
use DarkGlass;

# Computed globals
use vars qw($Page $ServerUrl $BaseUrl $DocumentRoot);


# FIXME: get rid of this nonsense
sub decode_utf8_opt {
  my ($text) = @_;
  $text = decode_utf8($text) if !utf8::is_utf8($text);
  return $text;
}

sub renderSmut {
  my ($file) = @_;
  my $script = untaint(abs_path("smut-html.pl"));
  open(READER, "-|:utf8", $script, $file, $Page, $ServerUrl, $BaseUrl, $DocumentRoot);
  my $oldpage = $DarkGlass::page;
  $DarkGlass::page = $Page;
  my $text = expand(scalar(slurp \*READER), \%DarkGlass::Macros);
  $DarkGlass::page = $oldpage;
  return $text;
}

sub render {
  my ($file, $page, $srctype, $desttype, $serverurl, $baseurl, $documentroot) = @_;
  $Page = $page;
  $ServerUrl = $serverurl;
  $BaseUrl = $baseurl;
  $DocumentRoot = $documentroot;
  my ($text, $altDownload);
  # FIXME: Do this more elegantly
  $MIME::Convert::Converters{"text/plain>text/html"} = \&renderSmut;
  $desttype = $srctype unless $MIME::Convert::Converters{"$srctype>$desttype"};
  # FIXME: Should give an error if asked by convert parameter for impossible conversion
  ($text, $altDownload) = MIME::Convert::convert($file, $srctype, $desttype, $page, $BaseUrl);
  if ($desttype eq "text/html") {
    $text = decode_utf8_opt($text);
    # Pull out the body element of the HTML
    $text =~ m|<body[^>]*>(.*)</body>|gsmi;
    $text = $1;
  } #else {
    # N.B.: we can't embed arbitrary objects. This is the best we can
    # do. Another problem is that with this, we'd be forced to use
    # ...?convert URLs for anything we actually wanted to download.
    #$text = object(-data => "$BaseUrl$file", -width => "100%", -height => "100%");
  #}
  return ($text, $desttype, $altDownload);
}


1;                              # return a true value
