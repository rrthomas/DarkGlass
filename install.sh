#!/bin/sh
# Install Linton in a bin directory
# (c) Reuben Thomas <rrt@sc3d.org> 2023-2024
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

# Check we're being run from the right place
if [ ! -f "doc/Why Linton?.md" ]; then
    echo "This script must be run from the Linton top-level directory"
    exit 1
fi

# Process command-line arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 DOCUMENT-ROOT-DIR INSTALL-DIR"
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
install bin/*.pl bin/linton "$INSTALL_DIR"
$INSTALL_DATA bin/*.html bin/*.pm "$INSTALL_DIR"
