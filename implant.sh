#!/bin/bash

# Copy the Repoint program files from the directory containing this
# script into the directory from which the script is run.

set -eu

src=$(dirname "$0")
target=$(pwd)

if [ ! -f "$src/repoint" ]; then
    echo "Failed to find $src/repoint, giving up"
    exit 2
fi

repointfiles="repoint repoint.bat repoint.ps1 repoint.sml"

echo -n "Copying Repoint files from $src to $target... "

for f in $repointfiles; do
    cp "$src/$f" "$target/"
done

chmod +x "$target/repoint"

echo "Done"

vcs=""
if [ -d "$target/.hg" ]; then
    vcs="Mercurial"
elif [ -d "$target/.git" ]; then
    vcs="Git"
fi

if [ -n "$vcs" ]; then
    echo -n "Add Repoint scripts to local $vcs repo? [yN] "
    read answer
    case "$answer" in
	Y|y) ( cd "$target"
               if [ -d ".hg" ]; then
                   hg add $repointfiles
                   echo 'glob:.repoint*' >> .hgignore
                   hg add .hgignore
               elif [ -d ".git" ]; then
                   git add $repointfiles
                   echo '.repoint*' >> .gitignore
                   git add .gitignore
               fi ) ; echo "Done" ;;
	*) echo "Not adding to repo" ;;
    esac
fi

