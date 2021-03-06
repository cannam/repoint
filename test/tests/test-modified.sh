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

"$repoint" install

for task in status review ; do
    assert_local_outputs $task "Clean Clean Clean"
done

echo "modified" > ext/A/file.txt
echo "modified-b" > ext/B/file-b.txt
echo "modified-c" > ext/C/file-c.txt

for task in status review ; do
    assert_local_outputs $task "Modified Modified Modified"
done


