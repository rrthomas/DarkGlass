# DarkGlass
# Serve a directory tree as web pages
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2024
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

# Non-core dependencies (all in Debian/Ubuntu):
# CGI.pm, File::Slurp, File::MimeInfo, HTML::Parser, HTML::Tagset

use v5.010;
package DarkGlass;

use utf8;
use strict;
use warnings;

use POSIX 'strftime';
use File::Basename;
use File::Spec::Functions qw(abs2rel);
use File::stat;
use Encode;
use Cwd qw(abs_path);

use CGI 4.37 qw(:standard unescapeHTML);
use CGI::Carp qw(fatalsToBrowser set_message);
use constant IS_CGI => exists $ENV{'GATEWAY_INTERFACE'};
use CGI::Util qw(escape unescape);
use HTML::Parser ();
use HTML::Tagset;
use File::Slurp qw(slurp);
use File::MimeInfo qw(extensions describe);

# For debugging, uncomment the following:
# use lib "/home/rrt/.local/share/perl/5.22.1";
# use CGI::Carp::StackTrace;

use RRT::Misc 0.12;
use RRT::Macro 3.10;


# Config vars
use vars qw($ServerUrl $BaseUrl $DocumentRoot $Title $Author $Email %Macros);

BEGIN {
  sub handle_errors {
    my $msg = shift;
    print "<!DOCTYPE html>";
    print "<head><meta charset=\"utf-8\"></head>";
    print "<h1>Software error:</h1>";
    print "<pre>$msg</pre>";
    print "<p>For help, please send mail to the webmaster (<a href=\"mailto:$Email\">$Email</a>), giving this error message and the time and date of the error.\n\n</p>";
  }
  set_message(\&handle_errors);
}

# Computed globals
use vars qw($DGSuffix @Index %Index);

$DGSuffix = ".dg";
@Index = ("README$DGSuffix", "README$DGSuffix.md", "index$DGSuffix.html", "README", "README.md", "index.html");
%Index = map { $_ => 1 } @Index;


# Read the list of MIME converters
open(READER, "-|", "hulot-converters", "--match=.") or die("hulot-converters failed (open)");
my @Converters = slurp \*READER, {chomp => 1, binmode => ":utf8"};
for (my $i = 0; $i <= $#Converters; $i++) {
  $Converters[$i] = decode_utf8($Converters[$i]);
}
close READER or die("hulot-converters failed (close)");

# Remove MIME type conversions we don't want
@Converters = grep(!m _^(?:application/(?:json|javascript)|text/css)→text/html$_, @Converters);

# MIME type conversion
sub convertFile {
  my ($file, $srctype, $desttype) = @_;
  my @args = ("hulot", $file, "-", $desttype || "text/html");
  push @args, $srctype if $srctype;
  open(READER, "-|", @args)
    or die "convertFile @args failed (open)";
  my $output = slurp(\*READER, {binmode => ':raw'});
  close(READER) or die "convertFile @args failed (close)";
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
      my $is_dir = -d $path;

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
      $path .= "/" if $is_dir; # Make path a directory if original is
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
      my ($text, $class) = @_;
      $text = $Email if !defined($text);
      return $Macros{link}("mailto:$Email", $text, $class);
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
      return expand(scalar(slurp($file, {binmode => ':utf8'})), \%Macros);
    },

    paste => sub {
      my ($file) = @_;
      $file = $Macros{canonicalpath}($file);
      return scalar(slurp($file, {binmode => ':utf8'}));
    },

    pasteconvert => sub {
      my ($file) = @_;
      $file = $Macros{canonicalpath}($file);
      return getBody(convertFile($file));
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

# Turn entities into characters
sub expandNumericEntities {
  my ($text) = @_;
  $text =~ s/&#(\pN+);/chr($1)/ge;
  return $text;
}

sub listDirectory {
  return html($Macros{directory}());
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
# starts with a URI scheme. Expand it at once, as by this point expand() has
# already run.
sub rewriteLink {
  my ($val, $attr, $tag) = @_;
  $val = expand("\$url{$val}", \%Macros) unless $val =~ m/^(?:\$|[a-z]+:)/;
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
  $file = untaint(abs_path($file));
  # FIXME: Return 404 instead of 403 for directories; need to stop
  # Apache bailing out when it can't read the .htaccess file in the
  # directory.
  my $abs_DocumentRoot = abs_path($DocumentRoot);
  if ($file !~ /^$abs_DocumentRoot/ || !-e $file) {
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
        $body = expand($body, \%Macros) if $srctype eq "text/plain" || $srctype eq "text/x-readme" || $srctype eq "text/markdown"; # FIXME: this is a hack
        $body = rewriteLinks($body) unless IS_CGI;
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
