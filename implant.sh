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
if [ -d "$target/.hg" ]; then
    vcs="Mercurial"
elif [ -d "$target/.git" ]; then
    vcs="Git"
fi

if [ -n "$vcs" ]; then
    echo -n "Add Vext scripts to local $vcs repo? [yN] "
    read answer
    case "$answer" in
	Y|y) ( cd "$target"
               if [ -d ".hg" ]; then
                   hg add $vextfiles
                   echo 'glob:.vext-*.bin' >> .hgignore
                   hg add .hgignore
               elif [ -d ".git" ]; then
                   git add $vextfiles
                   echo '.vext-*.bin' >> .gitignore
                   git add .gitignore
               fi ) ; echo "Done" ;;
	*) echo "Not adding to repo" ;;
    esac
fi

