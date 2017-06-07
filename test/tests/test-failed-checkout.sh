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
}
EOF
          )

for dir in A B; do
    
    prepare
    write_project_file "$libcontent"

    # Make dir exist already, so both hg and git should refuse to clone
    ( mkdir ext ; cd ext ; mkdir $dir ; touch $dir/blah )

    if "$vext" install ; then
        echo "ERROR: vext install to non-empty local dir was expected to fail"
        exit 3
    else
        :
    fi
done


