#!/bin/bash

. $(dirname "$0")/include.sh

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile",
    "branch": "b2"
},
"B": {
    "vcs": "git",
    "service": "testfile",
    "branch": "b2"
},
"C": {
    "vcs": "svn",
    "service": "testfile"
}
EOF
          )

# NB our SVN support doesn't include branches, so we don't do anything
# with that repo in the tests

for task in install update ; do
    prepare
    write_project_file "$libcontent"
    "$repointdir"/repoint $task
    check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2 2
done

