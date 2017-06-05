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
}
EOF
          )

write_project_file "$libcontent"

"$vextdir"/vext update

check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2



