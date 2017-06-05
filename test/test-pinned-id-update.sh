#!/bin/bash

set -eu

. include.sh
prepare $(dirname "$0")/current
vextdir=../..

libcontent=$(cat <<EOF
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

write_project_file "$libcontent"

"$vextdir"/vext update

check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2

