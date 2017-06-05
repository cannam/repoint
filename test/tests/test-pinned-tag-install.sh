#!/bin/bash

. $(dirname "$0")/include.sh

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile",
    "pin": "tag"
},
"B": {
    "vcs": "git",
    "service": "testfile",
    "pin": "tag"
}
EOF
          )

write_project_file "$libcontent"

"$vextdir"/vext install

check_expected 8c914da153bd 2d31b1afbec4dbd43a8c4428f0e4be8c407017c5

