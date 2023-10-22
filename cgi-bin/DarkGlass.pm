# DarkGlass
# Serve a directory tree as web pages
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2023
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

# Non-core dependencies (all in Debian/Ubuntu):
# CGI.pm, File::Slurp, File::MimeInfo, Image::ExifTool, DateTime, Module::Path,
# HTML::Parser, HTML::Tagset, HTML::Tiny, XML::LibXSLT, XML::Atom, PDF::API2
# imagemagick | graphicsmagick-imagemagick-compat

use v5.010;
package DarkGlass;

use utf8;
use strict;
use warnings;

use List::Util 'min';
use POSIX 'strftime';
use File::Basename;
use File::Spec::Functions qw(abs2rel catfile);
use File::stat;
use File::Temp qw(tempdir);
use Encode;
use Cwd qw(abs_path getcwd);
use MIME::Base64;

use CGI 4.37 qw(:standard unescapeHTML);
use CGI::Carp qw(fatalsToBrowser set_message);
use constant IS_CGI => exists $ENV{'GATEWAY_INTERFACE'};
BEGIN {
  sub handle_errors {
    my $msg = shift;
    print "<!DOCTYPE html>";
    print "<head><meta charset=\"utf-8\"></head>";
    print "<h1>Software error:</h1>";
    print "<pre>$msg</pre>";
    print "<p>For help, please send mail to the webmaster (<a href=\"mailto:webmaster\@localhost\">webmaster\@localhost</a>), giving this error message and the time and date of the error.\n\n</p>";
  }
  set_message(\&handle_errors);
}
use CGI::Util qw(escape unescape);
use HTML::Parser ();
use HTML::Tagset;
use HTML::Tiny; # For tags unknown to CGI.pm
use File::Slurp qw(slurp);
use File::MimeInfo qw(extensions describe);
use Image::ExifTool qw(ImageInfo);
use PDF::API2;
use Module::Path qw(module_path);

# For debugging, uncomment the following:
# use lib "/home/rrt/.local/share/perl/5.22.1";
# use CGI::Carp::StackTrace;

use RRT::Misc 0.12;
use RRT::Macro 3.10;


# Config vars
use vars qw($ServerUrl $BaseUrl $DocumentRoot $Title $Author $Email %Macros);

# Computed globals
use vars qw($DGSuffix @Index %Index);

$DGSuffix = ".dg";
@Index = ("README$DGSuffix", "README$DGSuffix.md", "index$DGSuffix.html", "README", "README.md", "index.html");
%Index = map { $_ => 1 } @Index;


# Read the list of MIME converters
my $module_dir = module_path("DarkGlass");
$module_dir =~ s|/DarkGlass.pm||;
my $mime_converters_prog = untaint(catfile($module_dir, "mime-converters"));
my $cv_prog = untaint(catfile($module_dir, "cv"));
open(READER, "-|", $mime_converters_prog, "--match=.") or die("mime-converters failed (open)");
my @Converters = slurp \*READER, {chomp => 1, binmode => ":utf8"};
for (my $i = 0; $i <= $#Converters; $i++) {
  $Converters[$i] = decode_utf8($Converters[$i]);
}
close READER or die("mime-converters failed (close)");

# MIME type conversion
sub convertFile {
  my ($file, $srctype, $desttype) = @_;
  open(READER, "-|", $cv_prog, $file, "-", $desttype, $srctype)
    or die "convertFile $file $srctype $desttype failed (open)";
  my $output = slurp(\*READER, {binmode => ':raw'});
  close(READER) or die "convertFile $file $srctype $desttype failed (close)";
  return $output;
}

# Macros

# FIXME: get rid of this nonsense
sub decode_utf8_opt {
  my ($text) = @_;
  $text = decode_utf8($text) if !utf8::is_utf8($text);
  return $text;
}

# Directory listing generator
sub makeDirectory {
  my ($path, $test, $linkClasses, $dirLinkClasses) = @_;
  my $dir = "$DocumentRoot/$path";
  my @entries = readDir($dir, $test);
  return "" if !@entries;
  my $files = "";
  my $dirs = "";
  foreach my $entry (sort @entries) {
    if (-f $dir . $entry && !$Index{$entry}) {
      $files .= li($Macros{link}($Macros{url}("/$path/$entry"), $entry, $linkClasses));
    } elsif (-d $dir . $entry) {
      $dirs .= li($Macros{link}($Macros{url}("/$path/$entry"), $entry, $dirLinkClasses));
    }
  }
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
    open(READER, "-|", "identify", "-quiet", $file);
    close READER;
    if ($? != -1) {
      if (($? & 0x7f) == 0 && $? >> 8 == 1) {
        my $mimetype = getMimeType($file);
        if (grep "$mimetype→image/jpeg", @Converters) {
          $data = convertFile($file, $mimetype, "image/jpeg");
          my $tempdir = tempdir(CLEANUP => 1);
          $file = "$tempdir/tmp.jpg";
          write_file($file, {binmode => ':raw'}, $data);
        }
      }
      $width ||= 160;
      $height ||= 160;
      open(READER, "-|", "convert", "-quiet", $file, "-size", $width ."x" .$height, "-resize", $width . "x" .$height, "jpeg:-");
      $data = slurp(\*READER, {binmode => ':raw'});
    }
  }
  return ($data, $width, $height);
}

our ($page, $outputDir, $srctype);

sub convert {
  my ($url, $mimetype) = @_;
  return "$url?convert=$mimetype" if IS_CGI;

  # If run in static mode, rewrite URL and output further conversions
  # required.
  my ($name, $dir, $suffix) = fileparse($url, qr/\.[^.]*/);
  $suffix = extensions($mimetype);
  say "$mimetype $suffix";
  return "$dir$name.$suffix";
}

%Macros =
  (
    # Macros

    page => sub {
      return $page;
    },

    file => sub {
      return addIndex($Macros{page}());
    },

    url => sub {
      my ($path, $param) = @_;
      $path = unescapeHTML($path);
      $path =~ m/(.*)(?:#([^#]*))?$/;
      $path = $1;
      my $fragment = $2;
      $path = $Macros{canonicalpath}($path); # follow symlinks

      # Rewrite file extension to `.html` if in static mode and file would
      # be converted to HTML by default.
      unless (IS_CGI) {
        my ($name, $dir, $suffix) = fileparse($path, qr/\.[^.]*/);
        $path = "$dir$name.html" if $suffix =~ /^\.(md|txt)$/ || $name eq "README";
      }

      my $abs_root = abs_path($DocumentRoot); # strip DocumentRoot off again
      $path =~ s/^$abs_root//;
      $path =~ s/\?/%3F/g;   # escape ? to avoid generating parameters
      $path =~ s/\$/%24/g;   # escape $ to avoid generating macros
      $path =~ s/ /%20/g;    # escape space
      $path = $BaseUrl . $path;
      $path =~ s|//+|/|g;     # compress /'s; mostly cosmetic, & avoid leading // in output
      my $dir = $BaseUrl . $Macros{file}();
      $dir = dirname($dir) unless -d pageToFile($Macros{page}());
      $path = abs2rel($path, $dir); # Make path relative to page
      $path .= "#$fragment" if $fragment;
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
      return "" if $Macros{pagename}() eq "" || $Macros{pagename}() =~ m|./?|;
      return ": " . $Macros{pagename}();
    },

    author => sub {
      return $Author;
    },

    title => sub {
      return $Title;
    },

    download => sub {
      my @types = grep /^\Q$srctype\E/u, @Converters;
      return typesToLinks($srctype, @types);
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
      my $dir = abs_path($DocumentRoot);
      $dir .= "/" . $Macros{page}() if $file !~ m|^/|;
      $dir = dirname($dir) if !-d $dir; # strip base component if any
      return "$dir/$file";
    },

    link => sub {
      my ($url, $desc, $class) = @_;
      my $attrs = {-href => $url};
      $attrs->{-class} = $class if $class;
      $desc = $url if !$desc || $desc eq "";
      return a($attrs, $desc);
    },

    include => sub {
      my ($file) = @_;
      $file = $Macros{canonicalpath}($file);
      return expand(scalar(slurp($file, {binmode => ':utf8'})));
    },

    paste => sub {
      my ($file) = @_;
      $file = $Macros{canonicalpath}($file);
      return scalar(slurp($file, {binmode => ':utf8'}));
    },

    filesize => sub {
      my ($file) = @_;
      return numberToSI(-s $Macros{canonicalpath}($file) || 0) . "b";
    },

    menudirectory => sub {
      my ($dir, $linkClasses, $dirLinkClasses) = @_;
      $linkClasses ||= 'nav-link';
      $dirLinkClasses ||= 'nav-link nav-directory';
      $dir = $Macros{page}() unless defined($dir);
      my ($name, $path, $suffix) = fileparse($dir);
      $path = "" if $path eq "./";
      my $override = "$DocumentRoot/$path$DGSuffix";
      return expand(scalar(slurp($override, {binmode => ':utf8'})), \%Macros) if -f $override;
      return makeDirectory($dir, sub {-d shift && -r _}, $linkClasses, $dirLinkClasses);
    },

    breadcrumb => sub {
      my ($name, $path, $suffix) = fileparse($Macros{page}());
      $path = "" if $path eq "./";
      my $parents = $path;
      $parents =~ s|/$||;
      my $desc = basename($parents);
      my $tree = "";
      while ($parents ne "" && $parents ne "." && $parents ne "/") {
        # FIXME: Add class breadcrumb-active to first-produced (last) item
        $tree = li({-class => "breadcrumb-item"}, $Macros{link}($BaseUrl . $parents, $desc)) . $tree;
        $parents = dirname($parents);
        $desc = basename($parents);
      }
      $desc = $Title;
      $tree = li({-class => "breadcrumb-item"}, $Macros{link}($BaseUrl, $desc) . $tree);
      return $tree;
    },

    directory => sub {
      my ($name, $path, $suffix) = fileparse($Macros{page}());
      $path = "" if $path eq "./";
      return body(h1(basename($path)) . ul(makeDirectory($path, sub {-f shift && -r _})));
    },

    inlinedirectory => sub {
      my ($name, $path, $suffix) = fileparse($Macros{page}());
      $path = "" if $path eq "./";
      my $dir = "$DocumentRoot/$path";
      return body(summariseDirectory($dir));
    },

    image => sub {
      my ($image, $alt, $width, $height) = @_;
      my (%attr, $text, $data);
      $alt ||= "";
      my $file = $Macros{canonicalpath}($image);
      $attr{-src} = $Macros{url}($image);
      $attr{-alt} = $alt;
      $attr{-width} = $width if $width;
      $attr{-height} = $height if $width;
      if ($image !~ /^https?:/) {
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

    # FIXME: Merge into $image (add comment only if there is one)
    imagecomment => sub {
      my ($image) = @_;
      my $info = ImageInfo($Macros{canonicalpath}($image), "Comment");
      return decode_utf8($$info{Comment}) if $info;
      return "";
    },

    # FIXME: Get a poster frame from an argument, or a given frame of the video
    video => sub {
      my ($video, $alt, $width, $height) = @_;
      my $file = $Macros{canonicalpath}($video);
      my $h = HTML::Tiny->new;
      my %attr;
      $attr{controls} = [];
      $attr{src} = $Macros{url}($video);
      $attr{width} = $width if $width;
      $attr{height} = $height if $width;
      return $h->tag('video', \%attr, $alt || "");
    },

    youtube => sub {
      my ($slug, $width, $height) = @_;
      my $h = HTML::Tiny->new;
      my %attr;
      $attr{width} = $width || 560;
      $attr{height} = $height || 315;
      $attr{src} = "https://www.youtube.com/embed/$slug";
      $attr{frameborder} = 0;
      $attr{allow} = "clipboard-write; encrypted-media; picture-in-picture; web-share";
      $attr{allowfullscreen} = "";
      return $h->tag('iframe', \%attr);
    },

    webfile => sub {
      my ($file, $format) = @_;
      my $size = $Macros{filesize}($file);
      return $Macros{link}($Macros{url}($file), $format) . " $size";
    },

    pdfpages => sub {
      my ($file) = @_;
      $file = $Macros{canonicalpath}($file);
      my $pdf = PDF::API2->open($file);
      my $n = $pdf->pages();
      return $n . ($n eq "1" ? "p." : "pp.");
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
      my ($audio, $alt, $mimetype) = @_;
      my $file = $Macros{canonicalpath}($audio);
      $mimetype ||= getMimeType($file);
      $mimetype = "audio/ogg" if $mimetype =~ /\+ogg$/;
      my $baseUrl = $Macros{url}($audio);
      my $url = convert($baseUrl, $mimetype);
      my $h = HTML::Tiny->new;
      my %attr;
      $attr{controls} = [];
      $attr{preload} = "metadata";
      my @contents = ($h->tag('source', {type => $mimetype, src => $url}));
      push @contents, $h->tag('source', {type => "audio/mpeg", src => convert($baseUrl, "audio/mpeg")})
        if $mimetype ne "audio/mpeg" && (grep "$mimetype→audio/mpeg", @Converters);
      push @contents, $alt if $alt;
      return $h->tag('audio', \%attr, \@contents) . a({href => $url}, "(Download)");
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
    my $path = untaint(abs_path($dir . decode_utf8($file)));
    my $stat = stat($path);
    if ($stat) {
      push @files, $file;
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
    next if $Index{@{$files}[@{$order}[$i]]};
    if (-f $path) {
      $text .= getBody(demote(@{$pages}[@{$order}[$i]])) . hr;
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

sub audioFile {
  my ($file, $srctype, $desttype) = @_;
  $file =~ s/$DocumentRoot//;
  return $Macros{audiofile}($file, "", $srctype);
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
  $text =~ m|<body[^>]*>(.*)</body>|smi;
  return $1 || $text;
}

# Construct a hash of tag names that may have links.
my %link_attr;
{
  # To simplify things, reformat the %HTML::Tagset::linkElements
  # hash so that it is always a hash of hashes.
  while (my ($k, $v) = each %HTML::Tagset::linkElements) {
    if (ref($v)) {
      $v = {map { $_ => 1 } @$v};
    } else {
      $v = {$v => 1};
    }
    $link_attr{$k} = $v;
  }
}

# Wrap a link target in a call to $url unless it is already a macro call or
# starts with a URI scheme.
sub rewriteLink {
  my ($val, $attr, $tag) = @_;
  $val = "\$url{$val}" unless $val =~ m/^(?:\$|[a-z]+:)/;
  return $val;
}

# Rewrite links in an HTML document.
# Based on hrefsub example from HTML::Parser
sub rewriteLinks {
  my ($text) = @_;
  my $p = HTML::Parser->new(api_version => 3);
  my @result = ();
  $p->handler(default => sub { push @result, shift }, "text");
  $p->handler(
    start => sub {
      my ($tagname, $pos, $text) = @_;
      if (my $link_attr = $link_attr{$tagname}) {
        while (4 <= @$pos) {

          # use attribute sets from right to left to avoid invalidating the
          # offsets when replacing the values
          my ($k_offset, $k_len, $v_offset, $v_len) = splice(@$pos, -4);
          my $attrname = lc(substr($text, $k_offset, $k_len));
          next unless $link_attr->{$attrname};
          next unless $v_offset; # 0 v_offset means no value
          my $v = substr($text, $v_offset, $v_len);
          $v =~ s/^([\'\"])(.*)\1$/$2/;
          my $new_v = rewriteLink($v, $attrname, $tagname);
          next if $new_v eq $v;
          $new_v =~ s/\"/&quot;/g; # since we quote with ""
          substr($text, $v_offset, $v_len) = qq("$new_v");
        }
      }
      push @result, $text;
    },
    "tagname, tokenpos, text"
   );
  $p->parse($text);
  $p->eof;
  return join "", @result;
}

sub typesToLinks {
  my ($srctype, @types) = @_;
  my $download = "";
  for my $type (@types) {
    # FIXME: Move text below into files that can be internationalised
    # FIXME: Add page count for PDF using pdfpages macro
    my $desttype = $type;
    $srctype = decode_utf8($srctype);
    $desttype =~ s/^\Q$srctype\E→//u;
    $download .= li(a({-href => convert($Macros{url}(basename(addIndex($Macros{page}()))), $desttype)}, "Download page as " . describe($desttype)))
      if $desttype ne "text/html";
  }
  return $download;
}

sub render {
  local $page;
  my ($file, $srctype, $desttype);
  ($file, $page, $srctype, $desttype) = @_;
  $desttype = $srctype unless (grep /^\Q$srctype→$desttype\E$/, @Converters);
  # FIXME: Should give an error if asked by convert parameter for impossible conversion
  my $text = convertFile($file, $srctype, $desttype);
  return ($text, $desttype);
}

sub doRequest {
  # FIXME: Resurrect these
  # $MIME::Convert::Converters{"inode/directory>text/html"} = \&listDirectory;
  # $MIME::Convert::Converters{"inode/directory>application/atom+xml"} = \&makeFeed;
  # $MIME::Convert::Converters{"audio/mpeg>text/html"} = \&audioFile;
  # $MIME::Convert::Converters{"audio/ogg>text/html"} = \&audioFile;
  # $MIME::Convert::Converters{"audio/x-opus+ogg>text/html"} = \&audioFile;
  # $MIME::Convert::Converters{"audio/mp4>text/html"} = \&audioFile;
  my ($cmdlineUrl, $outputDirArg) = @_;
  local $outputDir = decode_utf8(untaint($outputDirArg));
  local $page = untaint($cmdlineUrl) || path_info() || "";
  $page = decode_utf8(unescape($page));
  $page =~ s|^$BaseUrl||;
  $page =~ s|^/||;
  # FIXME: Better fix for this (also see url macro)
  $page =~ s/\$/%24/;     # re-escape $ to avoid generating macros
  $page = dirname($page) if $Index{basename($page)};
  my $desttype = getParam("convert") || "text/html";
  my $text;
  my $file = pageToFile($page);
  local $srctype = getMimeType($file) || "application/octet-stream";
  my $headers = {};
  if (-d "$DocumentRoot/$page" && $page ne "" && $page !~ m|/$|) {
    $page .= "/";
    $file = pageToFile($page);
  }
  # FIXME: Return 404 instead of 403 for directories; need to stop
  # Apache bailing out when it can't read the .htaccess file in the
  # directory.
  if (!-e $file) {
    # FIXME: If file does not exist at first, try case-insensitive path matching.
    print header(-status => 404, -charset => "utf-8") . expand(expandNumericEntities(scalar(slurp(untaint(abs_path("notfound.html")), {binmode => ':utf8'}))), \%Macros);
  } else {
    # FIXME: Following block made redundant by Nancy
    my $ext = "html";
    my $filename = fileparse($file, qr/\.[^.]*/) . ".html";
    if (basename($file) eq "index.html") {
      $text = slurp($file, {binmode => ':utf8'});
    } else {
      ($text, $desttype) = render($file, $page, $srctype, $desttype);
      # FIXME: This next block should be turned into a custom Convert rule
      if ($desttype eq "text/html") {
        my $body = getBody($text);
        $body = rewriteLinks($body) unless IS_CGI;
        $body = expand($body, \%DarkGlass::Macros) if $srctype eq "text/plain" || $srctype eq "text/x-readme" || $srctype eq "text/markdown"; # FIXME: this is a hack
        $text = expand(expandNumericEntities(scalar(slurp(untaint(abs_path("view.html")), {binmode => ':utf8'}))), \%Macros);
        $text =~ s/\$text/$body/ge; # Avoid expanding macros in body
        $text = encode_utf8($text); # Re-encode for output
      } else {
        $ext = extensions($desttype);
        # FIXME: put "effective" file extension in the URL, "real" extension in script parameters (and MIME type?), and remove content-disposition
        $filename = $file;
        if ($ext && $ext ne "") {
          $filename = fileparse($file, qr/\.[^.]*/) . ".$ext" if $desttype ne $srctype;
          my $latin1_filename = encode("iso-8859-1", $filename);
          $latin1_filename =~ s/[%"]//g;
          my $utf8_filename = escape($filename);
          $headers->{"-content_disposition"} = "inline; filename=\"$latin1_filename\"; filename*=utf-8''$utf8_filename";
        }
        $headers->{"-content_length"} = length($text);
      }
    }
    $headers->{-type} = $desttype;
    if ($desttype =~ m|^text/|) {
      $headers->{-charset} = "utf-8";
    } else {
      $headers->{-charset} = ""; # Explicitly unset charset, otherwise CGI.pm defaults it to ISO-8859-1
    }
    # FIXME: get length of HTML pages too
    $headers->{-expires} = "now";
    print header($headers) if IS_CGI;
    if ($outputDir) {
      my $outputFile = $Index{basename($file)} ? "index.html" : basename($filename);
      open(OUTPUT, ">$outputDir/$outputFile");
      print OUTPUT $text;
    } else {
      print $text;
    }
  }
}


1;                              # return a true value
