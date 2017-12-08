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
},
"C": {
    "vcs": "svn",
    "service": "testfile"
}
EOF
          )

for task in install update ; do
    prepare
    write_project_file "$libcontent"
    "$vextdir"/vext $task
    # Our SVN support doesn't include tags, so the third value here is
    # just the head revision
    check_expected 8c914da153bd 2d31b1afbec4dbd43a8c4428f0e4be8c407017c5 2
done


