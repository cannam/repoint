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

"$vext" install

for task in status review ; do
    assert_local_outputs $task "Clean Clean Clean"
done

for dir in ext/A ext/B ext/C; do
    ( cd "$dir" ; echo "more!" >> file.txt )
done

for task in status review ; do
    assert_local_outputs $task "Modified Modified Modified"
done


