#!/usr/bin/perl
# DarkGlass
# Serve a directory tree as web pages
# (c) Reuben Thomas <rrt@sc3d.org> 2002-2024
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

use v5.010;

use strict;
use warnings;

use File::Slurp qw(slurp);


# Global variables
use vars qw($Page $File $BaseUrl $DocumentRoot %Macros $Macros);

# Macros
%Macros =
  (
    paste => sub {
      my ($file) = @_;
      shift;
      my $path = "$DocumentRoot/$file";
      return scalar(slurp($path)) unless -x $path;
      open(READER, "-|", $path, @_) or die "error running $path (open)";
      my $output = slurp(\*READER);
      close(READER) or die "error running $path (close)";
      return $output;
    },

    include => sub {
      return expand($Macros{paste}(@_));
    },
   );

sub doMacro {
  my ($macro, $arg) = @_;
  my @arg = split /(?<!\\),/, ($arg || "");
  for (my $i = 0; $i <= $#arg; $i++) {
    $arg[$i] =~ s/\\,/,/g; # Remove escaping backslashes
    $arg[$i] = expand($arg[$i]);
  }
  return $Macros{$macro}(@arg) if defined($Macros{$macro});
  my $ret = "\$$macro";
  $ret .= "{$arg}" if defined($arg);
  return $ret;
}

sub expand {
  my ($text) = @_;
  # Note: Writing the next line as "return $text =~ s/.../.../ger" causes
  # Perl (up to at least 5.30) to panic with some inputs.
  $text =~ s/(\\?)\$([[:lower:]]+)(\{((?:[^{}]++|(?3))*)})?/$1 ? "\$$2" . ($3 ? $3 : "") : doMacro($2, $4)/ge;
  return $text;
}


# Get command-line arguments and set environment variables for $include
# scripts from them.
($Page, $File, $BaseUrl, $DocumentRoot) = @ARGV;
$ENV{LINTON_PAGE} = $Page;
$ENV{LINTON_FILE} = $File;
$ENV{LINTON_BASE_URL} = $BaseUrl;
$ENV{LINTON_DOCUMENT_ROOT} = $DocumentRoot;

# Read input and expand it into template.
my $text = slurp(\*STDIN);
my $template = slurp("$DocumentRoot/view.html");
$template =~ s/\$text/$text/ge;
print expand($template);
