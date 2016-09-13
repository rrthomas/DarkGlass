# DarkGlass
# Serve a directory tree as web pages
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2016
# http://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

# Non-core dependencies (all in Debian/Ubuntu):
# File::Slurp, File::MimeInfo, Image::ExifTool,
# Audio::Scan, Time::Duration, DateTime, XML::LibXSLT, XML::Atom
# imagemagick | graphicsmagick-imagemagick-compat

require 5.8.7;
package DarkGlass;

use utf8;
use strict;
use warnings;

use List::Util 'min';
use POSIX 'strftime';
use File::Basename;
use File::stat;
use File::Temp qw(tempdir);
use Encode;
use Cwd qw(abs_path getcwd);
use CGI 4.05 qw(:standard unescapeHTML);
use CGI::Carp qw(fatalsToBrowser);
use CGI::Util qw(escape unescape);
use MIME::Base64;

use File::Slurp qw(slurp);
use File::MimeInfo qw(extensions);
use Image::ExifTool qw(ImageInfo);

use RRT::Misc;
use RRT::Macro 3.10;
use MIME::Convert;


# Config vars
use vars qw($ServerUrl $BaseUrl $DocumentRoot $Recent $Author $Email %Macros);

# Computed globals
use vars qw($DGSuffix @Index %Index);

$DGSuffix = ".dg";
@Index = ("README$DGSuffix", "README", "index.html");
%Index = map { $_ => 1 } @Index;


# Macros

# FIXME: get rid of this nonsense
sub decode_utf8_opt {
  my ($text) = @_;
  $text = decode_utf8($text) if !utf8::is_utf8($text);
  return $text;
}

# Directory listing generator
sub makeDirectory {
  my ($dir, $test) = @_;
  my @entries = readDir($dir, $test);
  return "" if !@entries;
  my $files = "";
  my $dirs = "";
  $dir = decode_utf8($dir);
  foreach my $entry (sort @entries) {
    $entry = decode_utf8($entry);
    if (-f $dir . $entry && !$Index{$entry}) {
      $files .= br if $files ne "";
      $files .= "&nbsp;&nbsp;&nbsp;" . $Macros{link}($Macros{url}($entry), $entry);
    } elsif (-d $dir . $entry) {
      $dirs .= br if $dirs ne "";
      $dirs .= "&nbsp;&nbsp;&nbsp;" . $Macros{link}($Macros{url}($entry), "&gt;" . $entry);
    }
  }
  $dirs .= br if $dirs ne "";
  return $dirs . $files;
}

sub getThumbnail {
  my ($file, $width, $height) = @_;
  my $thumb = ImageInfo($file, "ThumbnailImage");
  my $data;
  if ($thumb && $$thumb{ThumbnailImage}) {
    $data = ${$$thumb{ThumbnailImage}};
    my $thumbInfo = ImageInfo($$thumb{ThumbnailImage});
    $width ||= $thumbInfo->{ImageWidth};
    $height ||= $thumbInfo->{ImageHeight};
  } else {
    # FIXME: Use libgraphics-magick-perl
    open(READER, "-|", "identify", "-quiet", $file);
    close READER;
    if ($? != -1) {
      if (($? & 0x7f) == 0 && $? >> 8 == 1) {
        my $mimetype = getMimeType($file);
        if ($MIME::Convert::Converters{"$mimetype>image/jpeg"}) {
          $data = MIME::Convert::convert($file, $mimetype, "image/jpeg");
          my $tempdir = tempdir(CLEANUP => 1);
          $file = "$tempdir/tmp.jpg";
          write_file($file, {binmode => ':raw'}, $data);
        }
      }
      $width ||= 160;
      $height ||= 160;
      open(READER, "-|", "convert", "-quiet", $file, "-size", $width ."x" .$height, "-resize", $width . "x" .$height, "jpeg:-");
      $data = scalar(slurp(\*READER, {binmode => ':raw'}));
    }
  }
  return ($data, $width, $height);
}

our $page;

%Macros =
  (
    # Macros

    page => sub {
      return $page;
    },

    url => sub {
      my ($path, $param) = @_;
      $path = unescapeHTML($path);
      $path =~ s/\?/%3F/g;   # escape ? to avoid generating parameters
      $path =~ s/\$/%24/g;   # escape $ to avoid generating macros
      $path =~ s/ /%20/g;    # escape space
      $path = dirname(addIndex($Macros{page}())) . "/$path" if $path !~ m|^/|;
      $path = $BaseUrl . $path;
      $path =~ s|//+|/|;     # compress /'s; mostly cosmetic, & avoid leading // in output
      $path .= "?$param" if $param;
      return $path;
    },

    pagename => sub {
      my $name = $Macros{page}() || "";
      $name =~ s|/$||;
      return basename($name);
    },

    # FIXME: Ugly hack: should be a customization
    pageinsite => sub {
      return "" if $Macros{pagename}() eq "" || $Macros{pagename}() eq "./";
      return ": " . $Macros{pagename}();
    },

    author => sub {
      return $Author;
    },

    email => sub {
      my ($text) = @_;
      $text = $Email if !defined($text);
      return $Macros{link}("mailto:$Email", $text);
    },

    lastmodified => sub {
      my $time = stat(pageToFile($Macros{page}()))->mtime or 0;
      return strftime("%Y/%m/%d", localtime $time);
    },

    canonicalpath => sub {
      my ($file) = @_;
      $file = $Macros{page}() . "/$file" if $file !~ m|^/|;
      return "$DocumentRoot/$file";
    },

    link => sub {
      my ($url, $desc) = @_;
      $desc = $url if !$desc || $desc eq "";
      return a({-href => $url}, $desc);
    },

    include => sub {
      my ($file) = @_;
      $file = $Macros{canonicalpath}($file);
      return expand(scalar(slurp($file, {binmode => ':utf8'})));
    },

    filesize => sub {
      my ($file) = @_;
      return numberToSI(-s $Macros{canonicalpath}($file) || 0) . "b";
    },

    menudirectory => sub {
      my ($name, $path, $suffix) = fileparse($Macros{page}());
      $path = "" if $path eq "./";
      my $dir = "$DocumentRoot/$path";
      my $override = "$dir$DGSuffix";
      return scalar(slurp($override, {binmode => ':utf8'})) if -f $override;
      my $parents = $path;
      $parents =~ s|/$||;
      my $tree = "";
      my $desc = basename($parents);
      while ($parents ne "" && $parents ne "." && $parents ne "/") {
        $tree = $Macros{link}($BaseUrl . $parents, $desc) . $tree;
        $parents = dirname($parents);
        $desc = basename($parents) . "&gt;";
      }
      $desc = "Home";
      $desc .= "&gt;" if $tree ne "";
      $tree = $Macros{link}($BaseUrl, $desc) . $tree . br;
      return $tree . makeDirectory($dir, sub {-d shift && -r _});
    },

    directory => sub {
      my ($name, $path, $suffix) = fileparse($Macros{page}());
      $path = "" if $path eq "./";
      my $dir = "$DocumentRoot/$path";
      return body(h1(basename($dir)) . makeDirectory("$dir", sub {-f shift && -r _}));
    },

    # FIXME: add a film method that gets a thumbnail from a grab of
    # the first frame of a video (or optionally one given by an argument)
    image => sub {
      my ($image, $alt, $width, $height) = @_;
      my (%attr, $text, $data);
      $alt ||= "";
      my $file = $Macros{canonicalpath}($image);
      $attr{-src} = $Macros{url}($image);
      $attr{-alt} = $alt;
      $attr{-width} = $width if $width;
      $attr{-height} = $height if $width;
      if ($image !~ /^http:/) {
        ($data, $width, $height) = getThumbnail($file, $width, $height);
        if ($data) {
          $attr{-width} ||= $width;
          $attr{-height} ||= $height;
          # N.B. EXIF thumbnails are always JPEGs
          $attr{-src} = "data:image/jpeg;base64," . encode_base64($data);
          $text = $Macros{link}($Macros{url}($image), (img \%attr));
        }
      }
      $text = img \%attr if !$text;
      return $text . $alt;
    },

    imagecomment => sub {
      my ($image) = @_;
      my $info = ImageInfo($Macros{canonicalpath}($image), "Comment");
      return decode_utf8($$info{Comment}) if $info;
      return "";
    },

    webfile => sub {
      my ($file, $format) = @_;
      my $size = $Macros{filesize}($file);
      return $Macros{link}($Macros{url}($file), $format) . " $size";
    },

    pdfpages => sub {
      my ($file) = @_;
      $file = $Macros{canonicalpath}($file);
      my $n = `pdfinfo "$file"`;
      if ($n =~ /Pages:\s*(\pN+)/) {
        return $1 . ($1 eq "1" ? "p." : "pp.");
      } else {
        return "$file pp.";
      }
    },

    pdffile => sub {
      my ($file) = @_;
      return $Macros{link}($Macros{url}($file), "PDF") .
        " " . $Macros{pdfpages}($file);
    },

    # FIXME: This should be a customization
    musicfile => sub {
      my ($file, $comment) = @_;
      $comment = "" if !$comment;
      return em($file) . " ($comment" .
        $Macros{webfile}("$file.sib", "Sibelius") . ", " .
          $Macros{pdffile}("$file.pdf") .
            ", ". $Macros{webfile}("$file.mid", "MIDI") . ")";
    },

    audiofile => sub {
      use Audio::Scan;
      use Time::Duration;
      my ($file, $format) = @_;
      my $size = $Macros{filesize}($file);
      my $info = Audio::Scan->scan_info($Macros{canonicalpath}($file))->{info};
      my $length = concise(duration($info->{song_length_ms} / 1000));
      return $Macros{link}($Macros{url}($file), $format) . " ($length, $size)";
    },

    # FIXME: This should be a customization
    twitterstatus => sub {
      return hr . span({-id => "tweets"}, "") . a({-href => "http://twitter.com/sc3d", -id => "twitter-link", -style => "display:block;text-align:right;font-size:small;"}, "follow me on Twitter") . hr;
      },
    twittersupport => sub {
      return script({-type => "text/javascript", -src => $Macros{url}("/public_html/tweets.js")}, "");
    },
   );


# Convert page

sub addIndex {
  my ($page) = @_;
  my $file = $page;
  $file =~ s|/$||;
  if (-d "$DocumentRoot/$file") {
    foreach my $index (@Index) {
      if (-f "$DocumentRoot/$file/$index") {
        $file .= "/" if $file ne "";
        $file .= $index;
        last;
      }
    }
  }
  return $file;
}

sub pageToFile {
  my ($page) = @_;
  return "$DocumentRoot/" . addIndex($page);
}


# Decode and execute request

sub getParam {
  my ($name) = @_;
  my $var = param($name);
  return decode_utf8_opt(untaint($var)) if defined($var);
  return undef;
}

sub renderDir {
  my ($name, $path, $suffix) = fileparse($Macros{page}());
  $path = "" if $path eq "./";
  my $dir = "$DocumentRoot/$path";
  my @entries = readDir($dir);
  return "" if !@entries;
  my @times = ();
  my @pages = ();
  my @files = ();
  my @paths = ();
  my @pagenames = ();
  foreach my $file (@entries) {
    push @files, $file;
    my $path = untaint(abs_path($dir . decode_utf8($file)));
    push @paths, $path;
    push @times, stat($path)->mtime;
    my $page = $path;
    $page =~ s|^$DocumentRoot||;
    push @pagenames, $page;
    if (-f $path) {
      my ($text) = render($path, $page, getMimeType($path), "text/html");
      push @pages, $text;
    } else{
      push @pages, "($file)";
    }
  }
  my @order = sort {$times[$b] <=> $times[$a]} 0 .. $#times;
  return $dir, \@order, \@files, \@pagenames, \@times, \@pages, \@paths;
}

# Turn entities into characters
sub expandNumericEntities {
  my ($text) = @_;
  $text =~ s/&#(\pN+);/chr($1)/ge;
  return $text;
}

sub renderSmut {
  my ($file) = @_;
  my $script = untaint(abs_path("smut-html.pl"));
  open(READER, "-|:utf8", $script, $file, $page, $BaseUrl, $DocumentRoot);
  return expandNumericEntities(scalar(slurp(\*READER)));
}

# Demote HTML headings by one level
sub demote {
  my ($text) = @_;
  use XML::LibXSLT;
  use XML::LibXML;
  my $parser = XML::LibXML->new();
  my $xslt = XML::LibXSLT->new();
  my $html = $parser->parse_string($text);
  my $style_doc = $parser->parse_string(<<'EOT');
<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xhtml="http://www.w3.org/1999/xhtml"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    exclude-result-prefixes="xhtml">

  <xsl:output method="xml" indent="yes" encoding="utf-8"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="xhtml:h1">
    <h2><xsl:apply-templates/></h2>
  </xsl:template>

  <xsl:template match="xhtml:h2">
    <h3><xsl:apply-templates/></h3>
  </xsl:template>

  <xsl:template match="xhtml:h3">
    <h4><xsl:apply-templates/></h4>
  </xsl:template>

  <xsl:template match="xhtml:h4">
    <h5><xsl:apply-templates/></h5>
  </xsl:template>

  <xsl:template match="xhtml:h5">
    <h6><xsl:apply-templates/></h6>
  </xsl:template>

</xsl:stylesheet>
EOT
  my $stylesheet = $xslt->parse_stylesheet($style_doc);
  my $res = $stylesheet->transform($html);
  return $stylesheet->output_string($res);
}

sub listDirectory {
  return html($Macros{directory}());
}

# FIXME: Only render required pages, or cache them
sub summariseDirectory {
  my ($from, $to);
  $from = getParam("from") || 0;
  $to = getParam("to") || $from + 9;
  my ($dir, $order, $files, $pagenames, $times, $pages, $paths) = renderDir();
  my $text = h1($Macros{pagename}());
  for (my $i = $from; $i <= min($#{$order}, $to); $i++) {
    my $path = @{$paths}[@{$order}[$i]];
    if (-f $path) {
      # FIXME: Get demote working again
      #$text .= getBody(demote(@{$pages}[@{$order}[$i]])) . hr;
      $text .= getBody(@{$pages}[@{$order}[$i]]) . hr;
    } elsif (-d $path) {
      my $file = @{$files}[@{$order}[$i]];
      $text .= "&nbsp;&nbsp;&nbsp;" . $Macros{link}($Macros{url}($file), "&gt;" . $file) . hr;
    }
  }
  # FIXME: Want some way of measuring length to divide up page: keep
  # going until a certain number of bytes has been exceeded?
  # FIXME: Don't add this if there aren't any more!
  $text .= $Macros{link}($Macros{url}() . "?from=" . ($to + 1), "Older entries");
  return html(body($text));
}

# Adapted from XML::Atom::App
sub datetime_as_rfc3339 {
  use DateTime;
  my ($dt) = @_;
  $dt = DateTime->new(@{$dt}) if ref $dt eq 'ARRAY';
  my $offset = $dt->offset != 0 ? '%z' : 'Z';
  return $dt->strftime('%FT%T$offset');
}

sub makeFeed {
  my ($path, $order, $files, $pagenames, $times, $pages, $paths) = renderDir();

  use XML::Atom::Feed;
  use XML::Atom::Entry;
  use XML::Atom::Link;
  use XML::Atom::Person;
  $XML::Atom::DefaultVersion = "1.0";

  # Create feed
  my $feed = XML::Atom::Feed->new;
  $feed->title("$Author: " . $Macros{pagename}());
  my $author = XML::Atom::Person->new;
  $author->name($Author);
  $author->email($Email);
  $author->homepage($ServerUrl . $Macros{url}("/"));
  $feed->author($author);
  $feed->id($ServerUrl . $Macros{url}("")); # URL of current page
  $feed->updated(datetime_as_rfc3339(DateTime->now));
  $feed->icon("$ServerUrl${BaseUrl}favicon.ico");

  # Add entries
  for (my $i = 0; $i <= $#{$order}; $i++) {
    my $file = @{$files}[@{$order}[$i]];
    my $entry = XML::Atom::Entry->new;
    my $title = fileparse($file, qr/\.[^.]*/);
    my $pagename = @{$pagenames}[@{$order}[$i]];
    $entry->title($title);
    my $url = $ServerUrl . $Macros{url}($pagename);
    $entry->id($url); # FIXME: Improve this. See http://diveintomark.org/archives/2004/05/28/howto-atom-id
    my $link = XML::Atom::Link->new;
    my ($text) = @{$pages}[@{$order}[$i]];
    $entry->content($text);
    $link->type("text/html");
    $link->href($url);
    $entry->add_link($link);
    $entry->updated(datetime_as_rfc3339(DateTime->from_epoch(epoch => @{$times}[@{$order}[$i]])));
    $feed->add_entry($entry);
  }

  return $feed->as_xml;
}

# Return <body> element of HTML, or the entire input if no such element
sub getBody {
  my ($text) = @_;
  $text = decode_utf8_opt($text);
  # Pull out the body element of the HTML
  $text =~ m|<body[^>]*>(.*)</body>|gsmi;
  return $1 || $text;
 }

sub typesToLinks {
  my ($srctype, @types) = @_;
  my $download;
  for my $type (@types) {
    # FIXME: Move text below into files that can be internationalised
    # FIXME: Add page count for PDF using pdfpages macro
    # FIXME: Translate $desttype back into human-readable description
    my $desttype = $type;
    $desttype =~ s/^$srctype>//;
    $download .= a({-href => $Macros{url}($Macros{pagename}()) . "?convert=$desttype"}, "Download $desttype") . br();
  }
  return $download;
}

sub render {
  local $page;
  my ($file, $srctype, $desttype);
  ($file, $page, $srctype, $desttype) = @_;
  # FIXME: Do this more elegantly
  $MIME::Convert::Converters{"text/plain>text/html"} = \&renderSmut;
  $MIME::Convert::Converters{"text/x-readme>text/html"} = \&renderSmut;
  $MIME::Convert::Converters{"inode/directory>text/html"} = \&listDirectory;
  $MIME::Convert::Converters{"inode/directory>application/atom+xml"} = \&makeFeed;
  $desttype = $srctype unless $MIME::Convert::Converters{"$srctype>$desttype"};
  # FIXME: Should give an error if asked by convert parameter for impossible conversion
  my $text = MIME::Convert::convert($file, $srctype, $desttype, $page, $BaseUrl);
  my $altDownload = typesToLinks($srctype, MIME::Convert::converters(qr/^$srctype/));
  # N.B.: we can't embed arbitrary objects. This is the best we can
  # do. Another problem is that with this, we'd be forced to use
  # ...?convert URLs for anything we actually wanted to download.
  #$text = object(-data => "$BaseUrl$file", -width => "100%", -height => "100%");
  return ($text, $desttype, $altDownload);
}

sub doRequest {
  local $page = url(-absolute => 1);
  $page = decode_utf8(unescape($page));
  $page =~ s|^$BaseUrl||;
  $page =~ s|^/||;
  # FIXME: Better fix for this (also see url macro)
  $page =~ s/\$/%24/;     # re-escape $ to avoid generating macros
  my $desttype = getParam("convert") || "text/html";
  $page = "" if !defined($page);
  my ($text, $altDownload);
  my $file = pageToFile($page);
  my $srctype = getMimeType($file) || "application/octet-stream";
  my $headers = {};
  if (-d "$DocumentRoot/$page" && $page ne "" && $page !~ m|/$|) {
    $page .= "/";
    $file = pageToFile($page);
  }
  # FIXME: Return 404 instead of 403 for directories; need to stop
  # Apache bailing out when it can't read the .htaccess file in the
  # directory.
  if (!-e $file) {
    print header(-status => 404, -charset => "utf-8") . expand(expandNumericEntities(scalar(slurp(untaint(abs_path("notfound.htm")), {binmode => '<:utf8'}))), \%Macros);
  } else {
    ($text, $desttype, $altDownload) = render($file, $page, $srctype, $desttype);
    # FIXME: Following stanza made redundant by Nancy
    if (basename($file) eq "index.html") {
      $text = slurp $file;
    }
    # FIXME: This next stanza should be turned into a custom Convert rule
    elsif ($desttype eq "text/html") {
      my $body = getBody($text);
      $body = expand($body, \%DarkGlass::Macros) if $srctype eq "text/plain" || $srctype eq "text/x-readme" || $srctype eq "text/markdown"; # FIXME: this is a hack
      $Macros{file} = sub {addIndex($page)};
      # FIXME: Put text in next line in file; should be generated from convert (which MIME types can we get from this one?)
      $Macros{download} = sub {$altDownload || a({-href => $Macros{url}(-f $file ? basename($Macros{file}()) : "", "convert=text/plain")}, "Download page source")};
      $text = expand(expandNumericEntities(scalar(slurp(untaint(abs_path("view.htm")), {binmode => ':utf8'}))), \%Macros);
      $text =~ s/\$text/$body/ge; # Avoid expanding macros in body
      $text = encode_utf8($text); # Re-encode for output
    } else {
      my $ext = extensions($desttype);
      # FIXME: put "effective" file extension in the URL, "real" extension in script parameters (and MIME type?), and remove content-disposition
      if ($ext && $ext ne "") {
        my $filename = fileparse($file, qr/\.[^.]*/) . ".$ext";
        my $latin1_filename = encode("iso-8859-1", $filename);
        $latin1_filename =~ s/[%"]//g;
        my $utf8_filename = escape($filename);
        $headers->{"-content_disposition"} = "inline; filename=\"$latin1_filename\"; filename*=utf-8''$utf8_filename";
      }
      $headers->{"-content_length"} = length($text);
    }
    $headers->{-type} = $desttype;
    if ($desttype =~ m|^text/|) {
      $headers->{-charset} = "utf-8";
    } else {
      $headers->{-charset} = ""; # Explicitly unset charset, otherwise CGI.pm defaults it to ISO-8859-1
    }
    # FIXME: get length of HTML pages too
    $headers->{-expires} = "now";
    print header($headers) . $text;
  }
}


1;                              # return a true value
