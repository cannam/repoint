#!/bin/bash

. $(dirname "$0")/include.sh

# If we have several libraries & only some of them can be updated for
# any reason, then when we ask for an update, those ones will be
# updated, the rest will fail, and the lock file needs to be updated
# to reflect the reality on the ground. We need to make sure the lock
# file is neither (i) left as it was before, without reflecting the
# successful updates, nor (ii) updated as if everything had gone ok
# including the failed updates.

libcontent_working=$(cat <<EOF
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

libcontent_nonworking=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile"
},
"B": {
    "vcs": "git",
    "service": "testfile",
    "pin": "12345678"
},
"C": {
    "vcs": "svn",
    "service": "testfile",
    "pin": "6"
}
EOF
          )

prepare
write_project_file "$libcontent_working"

"$repoint" install
check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2 1

write_project_file "$libcontent_nonworking"

if "$repoint" update; then
    echo "ERROR: command that was intended to fail did not"
    exit 3
fi

check_expected f94ae9d7e5c9 7219cf6e6d4706295246d278a3821ea923e1dfe2 1
