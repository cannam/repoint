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

# we are allowed all sorts of relative paths

for extpath in flarp \
               bloop \
               blop/plod \
               ../$(basename "$current")/squip ; do

    rm -rf "$current"
    prepare
    write_project_file_with_extpath "$extpath" "$libcontent"

    "$vext" install
    check_expected_with_extpath "$extpath" f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2

    "$vext" update
    check_expected_with_extpath "$extpath" f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2

done

# but absolute paths aren't supported

for extpath in "$current"/mrop ; do

    rm -rf "$current"
    prepare
    write_project_file_with_extpath "$extpath" "$libcontent"

    if "$vext" install ; then
        echo "ERROR: vext install with absolute extdir was expected to fail"
        exit 3
    else
        echo "(The prior command was expected to print an error, continuing)"
    fi

done
