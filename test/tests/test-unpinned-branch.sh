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
}
EOF
          )

for task in install update ; do
    prepare
    write_project_file "$libcontent"
    "$vextdir"/vext $task
    check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2
done
