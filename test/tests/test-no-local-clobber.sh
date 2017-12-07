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

"$vext" install
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

echo "modified" > ext/A/file.txt
echo "new" > ext/A/new.txt
echo "modified-b" > ext/B/file-b.txt
echo "new-b" > ext/B/new-b.txt
echo "modified-c" > ext/C/file.txt
echo "new-c" > ext/C/new.txt

write_project_file "$libcontent_pinned"

"$vext" install # obeys lock file, so should do nothing
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

assert_contents ext/A/file.txt "modified"
assert_contents ext/A/new.txt "new"
assert_contents ext/B/file-b.txt "modified-b"
assert_contents ext/B/new-b.txt "new-b"
assert_contents ext/C/file.txt "modified-c"
assert_contents ext/C/new.txt "new-c"

# should refuse to clobber local modifications

if "$vext" update ; then
    echo "ERROR: vext update to locally modified dir was expected to fail"
    exit 3
else
    :
fi

# NB the expected results here for the SVN repo are the *wrong* values
# -- SVN will always clobber locally and I think there's nothing we can do
# about it, because it updates file-by-file and keeps no local history

##!!! This fails at the moment because the hg and git libraries fail
##!!! to update and cause Vext to bail out before rewriting the lock
##!!! file, while the svn library updates (it shouldn't but it does,
##!!! and I don't think we can help that) which means the lock file is
##!!! left in an incorrect state. Ultimately the problem here is that
##!!! we are rewriting the lock file once, but only if all updates
##!!! have been successful -- whereas it's possible for some updates
##!!! to succeed and others to fail, which will still mean the lock
##!!! file needs to be written. I should write a test for that case
##!!! before going on to fix it.

check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 1

assert_contents ext/A/file.txt "modified"
assert_contents ext/A/new.txt "new"
assert_contents ext/B/file-b.txt "modified-b"
assert_contents ext/B/new-b.txt "new-b"
assert_contents ext/C/file.txt "modified-c"


