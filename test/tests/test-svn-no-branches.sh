#!/bin/bash

. $(dirname "$0")/include.sh

libcontent=$(cat <<EOF
"C": {
    "vcs": "svn",
    "service": "testfile",
    "branch": "anything"
}
EOF
          )

# We don't support branches in SVN, we expect the user to change the
# URL to point at the branch instead

prepare
write_project_file "$libcontent"

assert_failure install "Branches not supported"

