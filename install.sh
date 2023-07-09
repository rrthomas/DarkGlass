#!/bin/sh
# Install DarkGlass in a cgi-bin directory
# (c) Reuben Thomas <rrt@sc3d.org> 2023
# https://rrt.sc3d.org/Software/DarkGlass
# Distributed under the GNU General Public License version 3, or (at
# your option) any later version.

# Check we're being run from the right place
if [ ! -f "About DarkGlass.md" ]; then
    echo "This script must be run from the DarkGlass top-level directory"
    exit 1
fi

# Process command-line arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 INSTALL-DIR"
    exit 1
fi
INSTALL_DIR=$1
shift
if [ ! -d "$INSTALL_DIR" ]; then
    echo "INSTALL-DIR must be a directory"
fi

# Copy files
INSTALL_DATA="install --mode=644"
install cgi-bin/*.pl "$INSTALL_DIR"
$INSTALL_DATA cgi-bin/*.htm cgi-bin/*.pm "$INSTALL_DIR"
$INSTALL_DATA -D --target-directory "$INSTALL_DIR"/RRT perl/Macro.pm perl/Misc.pm
$INSTALL_DATA -D --target-directory "$INSTALL_DIR"/MIME Hulot/MIME/*
