#!/bin/bash

. $(dirname "$0")/include.sh

# Here our remote repo is one that has been cloned from the original
# test repo, rather than the actual original test repo itself. We
# perform a repoint install, then commit something to the remote, then
# request a specific pin to the id that was just committed, and check
# that repoint install now updates to that id.

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
},
"C": {
    "vcs": "svn",
    "service": "testfile",
    "repository": "C2"
}
EOF
          )

( cd ../../testrepos
  rm -rf A2 B2 C2 C2_checkout
  hg clone A A2
  git clone -bmaster B B2
  cp -a C C2
  svn co file://$(pwd)/C2 C2_checkout
)

prepare
write_project_file "$libcontent"

"$repoint" install
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

( cd ../../testrepos
  cd A2
  echo 5 > file.txt
  hg commit -m 5 -u testuser
  cd ../B2
  echo 5 > file-b.txt
  git commit -a -m 5
  cd ../C2_checkout
  echo 5 > file.txt
  svn commit -m 5
  svn update
)

newidA=$( cd ../../testrepos/A2 ; hg id | awk '{ print $1; }' )
newidB=$( cd ../../testrepos/B2 ; git rev-parse HEAD )
newidC=$( cd ../../testrepos/C2_checkout ; svn info | grep '^Revision:' | awk '{ print $2; }' )

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
},
"C": {
    "vcs": "svn",
    "service": "testfile",
    "repository": "C2",
    "pin": "$newidC"
}
EOF
          )

write_project_file "$libcontent_pinned"

"$repoint" install # always obeys lock file, so should do nothing here
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

rm repoint-lock.json

"$repoint" install
check_expected $newidA $newidB $newidC

