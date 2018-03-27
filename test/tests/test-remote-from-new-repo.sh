#!/bin/bash

. $(dirname "$0")/include.sh

# Check that remotes work even if the repo is totally empty to begin
# with. Bit extreme, but may cover some edge cases for the state of
# remote metadata in a repo, and it is something that should work.

# This is one of several tests in which the metadata necessary for
# "repoint status" to report correctly is absent when it is run; it isn't
# expected to produce the right output until "repoint review" has been
# run. But it mustn't crash.

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

rm -rf "$current"
prepare
write_project_file "$libcontent"

mkdir -p "$current"/ext

( cd "$current"/ext
  hg init A
  git init B
  mkdir -p C # not meaningful for SVN
)

"$repoint" status
"$repoint" review
"$repoint" update

check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

assert_all_correct review

