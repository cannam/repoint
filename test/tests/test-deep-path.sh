#!/bin/bash

. $(dirname "$0")/include.sh

# A library path can have (forward) slashes in it, to show that the
# library should be checked out into a subdirectory rather than
# directly within the external library root.
#
# In this case Vext must create the full path to check out into, and
# the default repository name it uses as source for the checkout
# should be the directory name (from the last "/" onwards) rather than
# the full path, since repo names seldom have slashes in them with
# real providers like Github.
#
# If a repo name is explicitly provided with slashes in it, though, we
# should take it literally.

libcontent=$(cat <<EOF
"path/to/A": {
    "vcs": "hg",
    "service": "testfile"
},
"path/to/B": {
    "vcs": "git",
    "service": "testfile"
}
EOF
          )

prepare
write_project_file "$libcontent"

"$vext" install

rm -rf "$current"

libcontent=$(cat <<EOF
"path/to/A": {
    "vcs": "hg",
    "service": "testfile",
    "repository": "source/of/A"
},
"path/to/B": {
    "vcs": "git",
    "service": "testfile",
    "repository": "source/of/B"
}
EOF
          )

prepare
write_project_file "$libcontent"

rm -rf "$mydir/../testrepos/source"
mkdir -p "$mydir/../testrepos/source/of"
mv "$mydir/../testrepos/A" "$mydir/../testrepos/source/of/" 
mv "$mydir/../testrepos/B" "$mydir/../testrepos/source/of/" 

"$vext" install

rm -rf "$mydir/../testrepos/source"

