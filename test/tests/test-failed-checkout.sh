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

for dir in A B C; do
    
    prepare
    write_project_file "$libcontent"

    # Make dir exist already and have something in it, so our clone
    # should fail
    ( mkdir ext ; cd ext ; mkdir $dir ; touch $dir/blah )

    if "$vext" install ; then
        echo "ERROR: vext install to non-empty local dir was expected to fail"
        exit 3
    else
        echo "(The prior command was expected to print an error, continuing)"
    fi
done


