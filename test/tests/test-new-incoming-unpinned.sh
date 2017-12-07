#!/bin/bash

. $(dirname "$0")/include.sh

# Here our remote repo is one that has been cloned from the original
# test repo, rather than the actual original test repo itself. We
# perform (all unpinned) a vext install, then commit something to the
# remote, then check (i) that vext install does not change the local
# copy, and (ii) that vext update does.

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

"$vext" install
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
newidC=$( cd ../../testrepos/C2_checkout ; svn info --show-item revision )

"$vext" install
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

"$vext" update
check_expected $newidA $newidB $newidC

