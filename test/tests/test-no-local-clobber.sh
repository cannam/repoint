#!/bin/bash

. $(dirname "$0")/include.sh

libcontent_pinned=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile",
    "pin": "1379d75"
},
"B": {
    "vcs": "git",
    "service": "testfile",
    "pin": "7219cf6e6"
},
"C": {
    "vcs": "svn",
    "service": "testfile",
    "pin": "1"
}
EOF
          )

libcontent_unpinned=$(cat <<EOF
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
write_project_file "$libcontent_unpinned"

"$repoint" install
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

echo "modified" > ext/A/file.txt
echo "new" > ext/A/new.txt
echo "modified-b" > ext/B/file-b.txt
echo "new-b" > ext/B/new-b.txt
echo "modified-c" > ext/C/file-c.txt
echo "new-c" > ext/C/new-c.txt

write_project_file "$libcontent_pinned"

"$repoint" install # obeys lock file, so should do nothing
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

assert_contents ext/A/file.txt "modified"
assert_contents ext/A/new.txt "new"
assert_contents ext/B/file-b.txt "modified-b"
assert_contents ext/B/new-b.txt "new-b"
assert_contents ext/C/file-c.txt "modified-c"
assert_contents ext/C/new-c.txt "new-c"

# should refuse to clobber local modifications

if "$repoint" update ; then
    echo "ERROR: repoint update to locally modified dir was expected to fail"
    exit 3
else
    :
fi

# NB the expected results here for the SVN repo are the *wrong* values
# -- SVN will always clobber locally and I think there's nothing we can do
# about it, because it updates file-by-file and keeps no local history

check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 1

assert_contents ext/A/file.txt "modified"
assert_contents ext/A/new.txt "new"
assert_contents ext/B/file-b.txt "modified-b"
assert_contents ext/B/new-b.txt "new-b"
# File C will contain some merge conflict affair that we're not going
# to check here


