#!/bin/bash

. $(dirname "$0")/include.sh

libcontent_nobranch=$(cat <<EOF
"B": {
    "vcs": "git",
    "service": "testfile"
},
"Bmain": {
    "vcs": "git",
    "service": "testfile"
}
EOF
          )

libcontent_branch=$(cat <<EOF
"B": {
    "vcs": "git",
    "service": "testfile",
    "branch": "b2"
},
"Bmain": {
    "vcs": "git",
    "service": "testfile",
    "branch": "b2"
}
EOF
          )

prepare
write_project_file "$libcontent_nobranch"

"$repoint" install

id_default=3199655c658ff337ce24f78c6d1f410f34f4c6f2
id_b2=7219cf6e6d4706295246d278a3821ea923e1dfe2

actual=$( cd ext/B ; git rev-parse HEAD )
check_id "$actual" "$id_default" "B"    

actual=$( cd ext/Bmain ; git rev-parse HEAD )
check_id "$actual" "$id_default" "Bmain"

write_project_file "$libcontent_branch"

"$repoint" update

actual=$( cd ext/B ; git rev-parse HEAD )
check_id "$actual" "$id_b2" "B"    

actual=$( cd ext/Bmain ; git rev-parse HEAD )
check_id "$actual" "$id_b2" "Bmain"

write_project_file "$libcontent_nobranch"

"$repoint" update

actual=$( cd ext/B ; git rev-parse HEAD )
check_id "$actual" "$id_default" "B"

actual=$( cd ext/Bmain ; git rev-parse HEAD )
check_id "$actual" "$id_default" "Bmain"

