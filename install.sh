#!/bin/sh
# Install DarkGlass in a cgi-bin directory
# (c) Reuben Thomas <rrt@sc3d.org> 2023
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

# Check we're being run from the right place
if [ ! -f "doc/Why DarkGlass?.md" ]; then
    echo "This script must be run from the DarkGlass top-level directory"
    exit 1
fi

# Process command-line arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 DOCUMENT-ROOT-DIR CGI-BIN-DIR"
    exit 1
fi
DOCUMENT_ROOT_DIR=$1
INSTALL_DIR=$2
shift 2
if [ ! -d "$DOCUMENT_ROOT_DIR" ]; then
    echo "DOCUMENT-ROOT-DIR must be a directory"
    exit 1
fi
if [ ! -d "$INSTALL_DIR" ]; then
    echo "INSTALL-DIR must be a directory"
    exit 1
fi

# Copy files
INSTALL_DATA="install --mode=644"
$INSTALL_DATA doc/style.css "$DOCUMENT_ROOT_DIR"
install cgi-bin/*.pl "$INSTALL_DIR"
$INSTALL_DATA cgi-bin/*.html cgi-bin/*.pm "$INSTALL_DIR"
$INSTALL_DATA -D --target-directory "$INSTALL_DIR"/RRT perl/Macro.pm perl/Misc.pm
$INSTALL_DATA -D --target-directory "$INSTALL_DIR"/MIME Hulot/MIME/*.*
$INSTALL_DATA -D --target-directory "$INSTALL_DIR"/MIME/converters Hulot/MIME/converters/*
