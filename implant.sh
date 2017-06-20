#!/bin/bash

# Copy the Vext program files from the directory containing this
# script into the directory from which the script is run.

mydir=$(dirname "$0")

if [ ! -f "$mydir/vext" ]; then
    echo "Failed to find $mydir/vext, giving up" 1>&2
    exit 2
fi

cp "$mydir/vext" "$mydir/vext.bat" "$mydir/vext.ps1" "$mydir/vext.sml" .
chmod +x vext

