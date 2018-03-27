#!/bin/bash

. $(dirname "$0")/include.sh

libcontent_nobranch=$(cat <<EOF
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

libcontent_branch=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile",
    "branch": "b2"
},
"B": {
    "vcs": "git",
    "service": "testfile",
    "branch": "b2"
},
"C": {
    "vcs": "svn",
    "service": "testfile"
}
EOF
          )

# NB our SVN support doesn't include branches, so we don't do anything
# with that repo in the tests

prepare
write_project_file "$libcontent_nobranch"

"$repoint" install
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

write_project_file "$libcontent_branch"

"$repoint" install # obeys lock file, so should do nothing
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

# As far as Hg is concerned, we are now on the wrong branch, and both
# status and review should report that. For Git we are actually on the
# right branch but just out-of-date, because the b2 branch was
# branched off from master and so is a descendent of the current head
assert_outputs status "Wrong Superseded Present"
assert_outputs review "Wrong Superseded Correct"

"$repoint" update
check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2 2

assert_all_present status
assert_all_correct review
