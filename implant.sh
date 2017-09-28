#!/bin/bash

# Copy the Vext program files from the directory containing this
# script into the directory from which the script is run.

set -eu

src=$(dirname "$0")
target=$(pwd)

if [ ! -f "$src/vext" ]; then
    echo "Failed to find $src/vext, giving up"
    exit 2
fi

vextfiles="vext vext.bat vext.ps1 vext.sml"

echo -n "Copying Vext files from $src to $target... "

for f in $vextfiles; do
    cp "$src/$f" "$target/"
done

chmod +x "$target/vext"

echo "Done"

vcs=""
vcscmd=""

if [ -d "$target/.hg" ]; then
    vcs="Mercurial"
    vcscmd="hg add"
elif [ -d "$target/.git" ]; then
    vcs="Git"
    vcscmd="git add"
fi

if [ -n "$vcs" ]; then
    echo -n "Add Vext scripts to local $vcs repo? [yN] "
    read answer
    case "$answer" in
	Y|y) ( cd "$target" ; $vcscmd $vextfiles ) ; echo "Done" ;;
	*) echo "Skipping" ;;
    esac
fi

