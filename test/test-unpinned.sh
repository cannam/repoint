#!/bin/bash

set -eu

cd $(dirname "$0")
vextdir=..

. include.sh

libcontent=$(cat <<EOF
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

write_project_file "$libcontent"
rm -f vext-lock.spec
rm -rf ext

"$vextdir"/vext status
"$vextdir"/vext review
"$vextdir"/vext install
"$vextdir"/vext status


