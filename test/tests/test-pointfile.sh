#!/bin/bash

. $(dirname "$0")/include.sh

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile"
},
"B": {
    "vcs": "git",
    "service": "testfile"
},
"C": {
    "vcs": "svn",
    "service": "testfile"
}
EOF
          )

prepare
write_project_file "$libcontent"

if [ -f .repoint.point ]; then
    echo "ERROR: .repoint.point file was not expected to exist already before running repoint"
    exit 3
fi

"$repoint" install

if [ ! -f .repoint.point ]; then
    echo "ERROR: repoint install was expected to create .repoint.point"
    exit 3
fi

if [ repoint-project.json -nt .repoint.point ] ; then
    echo "ERROR: .repoint.point file should be newer than project file"
    exit 3
fi

