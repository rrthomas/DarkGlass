# DarkGlass
# Serve a directory tree as web pages
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2024
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

use v5.010;
package DarkGlass;

use strict;
use warnings;

use POSIX 'strftime';
use File::Basename;
use File::stat;
use Encode;
use Cwd qw(abs_path);

use File::Slurp qw(slurp);


# Config vars
use vars qw($BaseUrl $DocumentRoot $Title $Author $Email %Macros);

# Computed globals
use vars qw($DGSuffix @Index %Index);

$DGSuffix = ".dg";
@Index = ("README.md", "index.html");
%Index = map { $_ => 1 } @Index;


# Macros

our ($page);

sub doMacro {
  my ($macro, $arg, $macros) = @_;
  my @arg = split /(?<!\\),/, ($arg || "");
  for (my $i = 0; $i <= $#arg; $i++) {
    $arg[$i] =~ s/\\,/,/g; # Remove escaping backslashes
    $arg[$i] = expand($arg[$i], $macros);
  }
  return $macros->{$macro}(@arg) if defined($macros->{$macro});
  my $ret = "\$$macro";
  $ret .= "{$arg}" if defined($arg);
  return $ret;
}

sub expand {
  my ($text, $macros) = @_;
  # Note: Writing the next line as "return $text =~ s/.../.../ger" causes
  # Perl (up to at least 5.30) to panic with some inputs.
  $text =~ s/(\\?)\$([[:lower:]]+)(\{((?:[^{}]++|(?3))*)})?/$1 ? "\$$2" . ($3 ? $3 : "") : doMacro($2, $4, $macros)/ge;
  return $text;
}

sub canonicalpath {
  my ($file) = @_;
  my $dir = abs_path($DocumentRoot);
  $dir .= "/" . $page if $file !~ m|^/|;
  $dir = dirname($dir) if !-d $dir; # strip base component if any
  return "$dir/$file";
}

sub alink {
  my ($url, $desc, $class) = @_;
  my $attrs = "href=\"$url\"";
  $attrs .= "class=\"$class\"" if $class;
  $desc ||= $url;
  return "<a $attrs>$desc</a>";
}

# Return the readable non-dot files & directories in a directory as a list
sub readDir {
  my ($dir, $test) = @_;
  $test ||= sub { return (-f shift || -d _) && -r _; };
  opendir(DIR, $dir) || return ();
  my @entries = map { decode_utf8($_) } readdir(DIR);
  @entries = grep {/^[^.]/ && &{$test}($dir . "/" . $_)} @entries;
  closedir DIR;
  return @entries;
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
      $files .= "<li>" . alink("/$path/$entry", $entry, $linkClasses) . "</li>";
    } elsif (-d $dir . $entry) {
      $dirs .= "<li>" . alink("/$path/$entry", $entry, $dirLinkClasses) . "</li>";
    }
  }
  return $dirs . $files;
}

%Macros =
  (
    # Macros

    page => sub {
      return $page;
    },

    pagename => sub {
      my $name = $page || "";
      $name =~ s|/$||;
      return basename($name);
    },

    # FIXME: Ugly hack: should be a customization
    pageinsite => sub {
      my $pagename = $Macros{pagename}();
      return "" if $pagename eq "" || $pagename =~ m|./?|;
      return ": " . $pagename;
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
      return alink("mailto:$Email", $text, $class);
    },

    lastmodified => sub {
      my $time = stat(pageToFile($page))->mtime or 0;
      return strftime("%Y/%m/%d", localtime $time);
    },

    paste => sub {
      my ($file) = @_;
      $file = canonicalpath($file);
      return scalar(slurp($file));
    },

    include => sub {
      my ($file) = @_;
      return expand($Macros{paste}($file));
    },

    menudirectory => sub {
      my ($dir, $linkClasses, $dirLinkClasses) = @_;
      $linkClasses ||= 'nav-link';
      $dirLinkClasses ||= 'nav-link nav-directory';
      $dir = dirname($page) unless defined($dir);
      my ($name, $path, $suffix) = fileparse($dir);
      $path = "" if $path eq "./";
      $dir = "$DocumentRoot/$path";
      my $override = "$dir$DGSuffix";
      return expand(scalar(slurp($override)), \%Macros) if -f $override;
      return makeDirectory($dir, sub {-d shift && -r _}, $linkClasses, $dirLinkClasses);
    },

    breadcrumb => sub {
      my ($name, $path, $suffix) = fileparse($page);
      $path = "" if $path eq "./";
      my $parents = $path;
      $parents =~ s|/$||;
      my $desc = basename($parents);
      my $tree = "";
      while ($parents ne "" && $parents ne "." && $parents ne "/") {
        # FIXME: Add class breadcrumb-active to first-produced (last) item
        $tree = '<li class="breadcrumb-item">' . alink($BaseUrl . $parents, $desc) . "</li>" . $tree;
        $parents = dirname($parents);
        $desc = basename($parents);
      }
      $desc = $Title;
      $tree = '<li class="breadcrumb-item">' . alink($BaseUrl, $desc) . "</li>" . $tree;
      return $tree;
    },
   );

sub pageToFile {
  my ($page) = @_;
  return "$DocumentRoot/$page";
}


# Decode and execute request

sub doRequest {
  my ($cmdlineUrl) = @_;
  local $page = decode_utf8($cmdlineUrl);
  # FIXME: Better fix for this (also see url macro)
  $page =~ s/\$/%24/;     # re-escape $ to avoid generating macros
  my $text = slurp(\*STDIN);
  my $template = slurp(abs_path("view.html"));
  $template =~ s/\$text/$text/ge;
  print expand($template, \%Macros);
}


1;                              # return a true value
