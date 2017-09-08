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
}
EOF
          )

prepare
write_project_file "$libcontent_unpinned"

"$vext" install
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2

echo "modified" > ext/A/file.txt
echo "new" > ext/A/new.txt
echo "modified-b" > ext/B/file-b.txt
echo "new-b" > ext/B/new-b.txt

write_project_file "$libcontent_pinned"

"$vext" install # obeys lock file, so should do nothing
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2

assert_contents ext/A/file.txt "modified"
assert_contents ext/A/new.txt "new"
assert_contents ext/B/file-b.txt "modified-b"
assert_contents ext/B/new-b.txt "new-b"

# should refuse to clobber local modifications

if "$vext" update ; then
    echo "ERROR: vext update to locally modified dir was expected to fail"
    exit 3
else
    :
fi
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2

assert_contents ext/A/file.txt "modified"
assert_contents ext/A/new.txt "new"
assert_contents ext/B/file-b.txt "modified-b"
assert_contents ext/B/new-b.txt "new-b"
