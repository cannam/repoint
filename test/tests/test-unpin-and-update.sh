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
write_project_file "$libcontent_pinned"

"$vext" install
check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2 1

write_project_file "$libcontent_unpinned"

"$vextdir"/vext install # obeys lock file, so should do nothing
check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2 1

# The pinned id here is actually on a non-default branch, so status
# should be able to tell we're now in the wrong place, not just
# present or superseded - at least for VCSes for which we support
# branches (i.e. not SVN)

assert_outputs status "Wrong Wrong Present"
assert_outputs review "Wrong Wrong Superseded"

"$vextdir"/vext update
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

assert_all_present status
assert_all_correct review

