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

if output=$( "$vext" install 2>&1 ); then
    echo "ERROR: vext install of SVN repo with non-empty branch was expected to fail"
    exit 3
else
    case "$output" in
        *Branches\ not\ supported*) ;;
        *) echo "ERROR: vext install printed unexpected error message: $output";
           exit 3;;
    esac
fi





