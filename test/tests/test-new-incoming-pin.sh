#!/bin/bash

. $(dirname "$0")/include.sh

# Here our remote repo is one that has been cloned from the original
# test repo, rather than the actual original test repo itself. We
# perform a vext install, then commit something to the remote, then
# request a specific pin to the id that was just committed, and check
# that vext install now updates to that id.

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile",
    "repository": "A2"
},
"B": {
    "vcs": "git",
    "service": "testfile",
    "repository": "B2"
}
EOF
          )

( cd ../../testrepos
  rm -rf A2 B2
  hg clone A A2
  git clone -bmaster B B2
)

prepare
write_project_file "$libcontent"

"$vext" install
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2

( cd ../../testrepos
  cd A2
  echo 5 > file.txt
  hg commit -m 5
  cd ../B2
  echo 5 > file-b.txt
  git commit -a -m 5
)

newidA=$( cd ../../testrepos/A2 ; hg id | awk '{ print $1; }' )
newidB=$( cd ../../testrepos/B2 ; git rev-parse HEAD )

libcontent_pinned=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile",
    "repository": "A2",
    "pin": "$newidA"
},
"B": {
    "vcs": "git",
    "service": "testfile",
    "repository": "B2",
    "pin": "$newidB"
}
EOF
          )

write_project_file "$libcontent_pinned"

"$vext" install # always obeys lock file, so should do nothing here
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2

rm vext-lock.json

"$vext" install
check_expected $newidA $newidB

