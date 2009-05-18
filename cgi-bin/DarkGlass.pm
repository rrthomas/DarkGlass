# DarkGlass
# Serve a directory tree as web pages
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2009
# http://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

# Non-core dependencies (all in Debian/Ubuntu):
# Perl6::Slurp, File::MimeInfo, Image::ExifTool, Audio::File, Time::Duration
# imagemagick | graphicsmagick-imagemagick-compat

require 5.8.7;
package DarkGlass;

use utf8;
use strict;
use warnings;

use Perl6::Slurp;
use List::Util 'min';
use POSIX 'strftime';
use File::Basename;
use File::stat;
use Encode;
use Cwd qw(abs_path getcwd);
use CGI::Pretty qw(:standard unescapeHTML);
use CGI::Carp qw(fatalsToBrowser);
use CGI::Util qw(unescape);
use Image::ExifTool qw(ImageInfo);
use Audio::File;
use MIME::Base64;
use File::MimeInfo qw(extensions);
use Time::Duration;

use RRT::Misc;
use RRT::Macro;
use MIME::Convert;


# Config vars
use vars qw($ServerUrl $BaseUrl $DocumentRoot $Recent $Administrator %Macros);

# Computed globals
use vars qw($DGSuffix %Index);

$DGSuffix = ".dg";
%Index = ("README$DGSuffix" => 1, "README" => 1);


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

our $page;

%Macros =
  (
    # Macros

    page => sub {
      return $page;
    },

    url => sub {
      my ($path, $param) = @_;
      $path = unescapeHTML(normalizePath($path, $Macros{page}()));
      $path =~ s/\?/%3F/g;   # escape ? to avoid generating parameters
      $path =~ s/\$/%24/g;   # escape $ to avoid generating macros
      $path = $BaseUrl . $path;
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

    email => sub {
      my ($text) = @_;
      return $Macros{link}("mailto:$Administrator", $text);
    },

    # FIXME: Use this
    lastmodified => sub {
      my $time = stat(pageToFile($Macros{page}))->mtime or 0;
      return strftime("%Y/%m/%d", localtime $time);
    },

    canonicalpath => sub {
      my ($file) = @_;
      return "$DocumentRoot/" . normalizePath($file, $Macros{page}());
    },

    link => sub {
      my ($url, $desc) = @_;
      $desc = $url if !$desc || $desc eq "";
      return a({-href => $url}, $desc);
    },

    include => sub {
      my ($file) = @_;
      $file = $Macros{canonicalpath}($file);
      return scalar(slurp '<:utf8', $file);
    },

    filesize => sub {
      my ($file) = @_;
      return numberToSI(-s $Macros{canonicalpath}($file) || 0) . "b";
    },

    directory => sub {
      my ($name, $path, $suffix) = fileparse($Macros{page}());
      $path = "" if $path eq "./";
      my $dir = "$DocumentRoot/$path";
      my $override = "$dir$DGSuffix";
      return scalar(slurp '<:utf8', $override) if -f $override;
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

    # FIXME: add a film method that gets a thumbnail from a grab of
    # the first frame of a video (or optionally one given by an argument)
    image => sub {
      my ($image, $alt, $width, $height) = @_;
      my (%attr, $text);
      $attr{-src} = $Macros{url}($image);
      $attr{-alt} ||= "";
      $attr{-width} = $width if $width;
      $attr{-height} = $height if $height;
      # FIXME: Always set height and width
      if ($image !~ /^http:/) {
        my $file = $Macros{canonicalpath}($image);
        # FIXME: factor this into a "getThumbnail" function
        # FIXME: Use libgraphics-magick-perl
        my $thumb = ImageInfo($file, "ThumbnailImage");
        my $data;
        if ($thumb && $$thumb{ThumbnailImage}) {
          $data = ${$$thumb{ThumbnailImage}};
        } else {
          system "identify", $file;
          if ($? != -1 && ($? & 0x7f) == 0 && $? >> 8 == 1) {
            my $mimetype = getMimeType($file);
            if ($MIME::Convert::Converters{"$mimetype>image/png"}) {
              my $img = MIME::Convert::convert($file, $mimetype, "image/png");
              $data = pipe2("convert", $img, "", "", "png:-", "-size", "160x160", "-resize", "160x160", "jpeg:-");
            }
          } else {
            open(READER, "-|", "convert", $file, "-size", "160x160", "-resize", "160x160", "jpeg:-");
            $data = scalar(slurp '<:raw', \*READER);
          }
        }
        if ($data) {
          # N.B. EXIF thumbnails are always JPEGs
          $attr{-src} = "data:image/jpeg;base64," . encode_base64($data);
          $text = $Macros{link}($Macros{url}($image), (img \%attr));
        }
      }
      $text = img \%attr if !$text;
      return $text . $alt;
    },

    # FIXME: add smut syntax?
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

    # FIXME: add smut syntax?
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
      my ($file, $format) = @_;
      my $size = $Macros{filesize}($file);
      my $info = Audio::File->new($Macros{canonicalpath}($file));
      my $length = concise(duration($info->audio_properties->length()));
      return $Macros{link}($Macros{url}($file), $format) . " ($length, $size)";
    },

    twitterstatus => sub {
      return "<!-- Twitter -->\n" .
        "<hr><span id=\"twitter_update_list\"></span>" .
          "<a href=\"http://twitter.com/sc3d\" id=\"twitter-link\" style=\"display:block;text-align:right;font-size:x-small;\">follow me on Twitter</a>" .
            "<hr>\n" .
              "<!-- End Twitter -->";
      },

      twittersupport => sub {
        return "<!-- Twitter scripts; here so if Twitter breaks the rest of the page still loads -->" .
          "<script type=\"text/javascript\" src=\"http://twitter.com/javascripts/blogger.js\"></script>" .
            "<script type=\"text/javascript\" src=\"http://twitter.com/statuses/user_timeline/sc3d.json?callback=twitterCallback2&amp;count=1\"></script>" .
              "<!-- End Twitter scripts -->";
        },
   );


# Convert page

sub addIndex {
  my ($page) = @_;
  my $file = $page;
  $file =~ s|/$||;
  if (-d "$DocumentRoot/$file") {
    foreach my $index (keys %Index) {
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

sub renderSmut {
  my ($file) = @_;
  my $script = untaint(abs_path("smut-html.pl"));
  open(READER, "-|:utf8", $script, $file, $Macros{page}(), $ServerUrl, $BaseUrl, $DocumentRoot);
  my $text = slurp \*READER;
  $text = expand($text, \%Macros);
  return $text;
}

sub getSortedDir {
  my ($name, $path, $suffix) = fileparse($Macros{page}());
  $path = "" if $path eq "./";
  my $dir = "$DocumentRoot/$path";
  my @entries = readDir($dir);
  return "" if !@entries;
  my @times = ();
  foreach my $entry (@entries) {
    push @times, stat($dir . decode_utf8($entry))->mtime;
  }
  return $dir, @entries[sort {$times[$b] <=> $times[$a]} 0 .. $#times];
}

sub summariseDirectory {
  my ($from, $to);
  $from = getParam("from") || 0;
  $to = getParam("to") || $from + 9;
  my ($dir, @sorted) = getSortedDir();
  my $text = h1($Macros{pagename}());
  for (my $i = $from; $i <= min($#sorted, $to); $i++) {
    my $file = decode_utf8($sorted[$i]);
    my $path = untaint(abs_path($dir . $file));
    my $page = $path;
    $page =~ s|^$DocumentRoot||;
    if (-f $path && !$Index{$file}) {
      my ($entry) = render($path, $page, getMimeType($path), "text/html");
      $text .= $entry . hr;
    } elsif (-d $path) {
      $text .= "&nbsp;&nbsp;&nbsp;" . $Macros{link}($Macros{url}($file), "&gt;" . $file) . hr;
    }
  }
  # FIXME: Want some way of measuring length to divide up page: keep
  # going until a certain number of bytes has been exceeded?
  $text .= $Macros{link}($Macros{url}() . "?from=" . ($to + 1), "Older entries");
  return html(body($text));
}

sub makeFeed {
  open(READER, "-|", "atom.pl", $DocumentRoot, $BaseUrl, $Macros{pagename}());
  return scalar(slurp '<:raw', \*READER);
}

sub render {
  my $file = shift;
  local $page = shift;
  my ($srctype, $desttype) = @_;
  my ($text, $altDownload);
  if (!($MIME::Convert::Converters{"$srctype>$desttype"})) {
    # If we wanted HTML but can't have it, try PDF instead
    $desttype = "application/pdf" if $desttype eq "text/html";
    $desttype = $srctype unless $MIME::Convert::Converters{"$srctype>$desttype"};
  }
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

sub doRequest {
  local $page = url();
  $page =~ s|\+|%2B|g; # Re-escape unescaped plus signs (FIXME: is this a bug in CGI.pm?)
  $page = decode_utf8(unescape($page));
  my $base = url(-base => 1);
  $base = untaint($base);
  $page =~ s|^$base$BaseUrl||;
  $page =~ s|^/||;
  # FIXME: Better fix for this (also see url macro)
  $page =~ s/\$/%24/;     # re-escape $ to avoid generating macros
  my $desttype = getParam("convert") || "text/html";
  $page = "" if !defined($page) || !cleanPath($page);
  my ($text, $altDownload);
  my $file = pageToFile($page);
  my $srctype = getMimeType($file) || "application/octet-stream";
  my $headers = {};
  if (-d "$DocumentRoot/$page" && $page ne "" && $page !~ m|/$|) {
    $page .= "/";
    $file = pageToFile($page);
  }
  # FIXME: Do this more elegantly
  $MIME::Convert::Converters{"text/plain>text/html"} = \&renderSmut;
  $MIME::Convert::Converters{"application/x-directory>text/html"} = \&summariseDirectory;
  $MIME::Convert::Converters{"application/x-directory>application/atom+xml"} = \&makeFeed;
  # FIXME: Return 404 instead of 403 for directories; need to stop
  # Apache bailing out when it can't read the .htaccess file in the
  # directory.
  if (!-e $file) {
    print header(-status => 404, -charset => "utf-8") . expand(scalar(slurp '<:utf8', untaint(abs_path("notfound.htm"))), \%Macros);
  } else {
    ($text, $desttype, $altDownload) = render($file, $page, $srctype, $desttype);
    # FIXME: This next stanza should be turned into a custom Convert rule
    if ($desttype eq "text/html") {
      my $body = $text;
      $Macros{file} = sub {addIndex($page)};
      # FIXME: Put text in next line in file; should be generated from convert (which MIME types can we get from this one?)
      $Macros{download} = sub {$altDownload || ""};
      $text = expand(scalar(slurp '<:utf8', untaint(abs_path("view.htm"))), \%Macros);
      $text =~ s/\$text/$body/ge; # Avoid expanding macros in body
      $text = encode_utf8($text); # Re-encode for output
    } else {
      my $ext = extensions($desttype);
      # FIXME: Fix for spaces in filename
      $headers->{"-content_disposition"} = "inline; filename=" . fileparse($file, qr/\.[^.]*/) . ".$ext"
        if $ext && $ext ne "";
      $headers->{"-content_length"} = length($text);
    }
    $headers->{-type} = $desttype;
    $headers->{-charset} = "utf-8"; # FIXME: This looks wrong for binary types
    # FIXME: get length of HTML pages too
    $headers->{-expires} = "now";
    print header($headers) . $text;
  }
}


1;                              # return a true value
