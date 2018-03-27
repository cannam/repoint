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
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

for task in status review ; do
    assert_local_outputs $task "Clean Clean Clean"
done

( cd ext/A ; hg update -r 1379d75f0b4f )
( cd ext/B ; git checkout --detach 7219cf6e6d4706295246d278a3821ea923e1dfe2 )
( cd ext/C ; svn update -r1 )

for task in status review ; do
    assert_local_outputs $task "DiffersfromLock DiffersfromLock DiffersfromLock"
done

"$repoint" lock
check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2 1

for task in status review ; do
    assert_local_outputs $task "Clean Clean Clean"
done

