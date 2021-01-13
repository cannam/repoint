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

echo "new" > ext/A/new.txt
echo "new-b" > ext/B/new-b.txt
echo "new-c" > ext/C/new-c.txt

for task in status review ; do
    assert_local_outputs $task "Clean Clean Clean"
done

( cd ext/A ; hg add new.txt )
( cd ext/B ; git add new-b.txt )
( cd ext/C ; svn add new-c.txt )

for task in status review ; do
    assert_local_outputs $task "Modified Modified Modified"
done


