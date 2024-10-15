# DarkGlass
# Serve a directory tree as web pages
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2024
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

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
use CGI::Util qw(unescape);
use File::Slurp qw(slurp);

use RRT::Misc 0.12;
use RRT::Macro 3.10;


# Config vars
use vars qw($BaseUrl $DocumentRoot $Title $Author $Email %Macros);

# Computed globals
use vars qw($DGSuffix @Index %Index);

$DGSuffix = ".dg";
@Index = ("README", "README.md", "index.html");
%Index = map { $_ => 1 } @Index;


# Macros

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

our ($page);

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

      my $abs_root = abs_path($DocumentRoot); # strip DocumentRoot off again
      $path =~ s/^$abs_root//;
      $path =~ s/\?/%3F/g;   # escape ? to avoid generating parameters
      $path =~ s/\$/%24/g;   # escape $ to avoid generating macros
      $path =~ s/ /%20/g;    # escape space
      $path = $BaseUrl . $path;
      $path =~ s|//+|/|g;     # compress /'s; mostly cosmetic, & avoid leading // in output
      my $new_dir = $BaseUrl . $Macros{file}();
      $new_dir = dirname($new_dir) unless -d pageToFile($Macros{page}());
      $path = abs2rel($path, $new_dir); # Make path relative to page
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
   );

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

sub render {
  local $page;
  my ($file);
  ($file, $page) = @_;
  my @args = ("markdown", "-f", "footnote,nopants,noalphalist,nostyle,fencedcode", $file);
  open(READER, "-|", @args)
    or die "render @args failed (open)";
  my $output = slurp(\*READER, {binmode => ':raw'});
  close(READER) or die "render @args failed (close)";
  return $output;
}

sub doRequest {
  my ($cmdlineUrl) = @_;
  local $page = untaint($cmdlineUrl);
  $page = decode_utf8(unescape($page));
  # FIXME: Better fix for this (also see url macro)
  $page =~ s/\$/%24/;     # re-escape $ to avoid generating macros
  my $file = untaint(abs_path(pageToFile($page)));
  # Forbid files above DocumentRoot
  my $abs_DocumentRoot = abs_path($DocumentRoot);
  if ($file !~ /^$abs_DocumentRoot/ || !-e $file) {
    die "No such file $file";
  } else {
    my $text = render($file, $page);
    my $template = slurp(untaint(abs_path("view.html")), {binmode => ':utf8'});
    $template =~ s/\$text/$text/ge;
    print encode_utf8(expand($template, \%Macros));
  }
}


1;                              # return a true value
