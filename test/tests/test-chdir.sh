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

mkdir -p random/subdirectory

pushd random/subdirectory
assert_failure install "Failed to open project spec file"
popd

echo "Checking expected failure when run in right directory with wrong --directory"
if output=$( "$repoint" install --directory random/subdirectory 2>&1 ); then
    echo "ERROR: repoint install was expected to fail here"
    exit 3
else
    echo OK
fi    

echo "Checking expected failure when run in right directory with nonexistent --directory"
if output=$( "$repoint" install --directory random/subdirectory/that/does/not/exist 2>&1 ); then
    echo "ERROR: repoint install was expected to fail here"
    exit 3
else
    echo OK
fi

pushd random/subdirectory
"$repoint" --directory ../.. install
popd

check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

rmdir random/subdirectory
rmdir random

rm -rf ext

tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t '${TMPDIR:-/tmp}/repoint.XXXXXXXXX')

trap "rm -rf $tmpdir" 0

pushd "$tmpdir"
"$repoint" install --directory "$current"
popd

check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

