#!/bin/bash

. $(dirname "$0")/include.sh

# Check that remotes work even if the original repo was cloned by some
# other means, e.g. not by Vext, or by an earlier version of Vext. We
# also request a different branch from the one originally cloned. In
# this case there will be no "vext" remote in the git case, and hg
# won't be able to check status of the desired branch because it won't
# be there yet.

# This is one of several tests in which the metadata necessary for
# "vext status" to report correctly is absent when it is run; it isn't
# expected to produce the right output until "vext review" has been
# run. But it mustn't crash.

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile",
    "branch": "b2"
},
"B": {
    "vcs": "git",
    "service": "testfile",
    "branch": "b2"
}
EOF
          )

prepare
write_project_file "$libcontent"

mkdir -p "$current"/ext

( cd "$current"/ext
  hg clone -b default ../../../testrepos/A
  git clone -b master ../../../testrepos/B
)

"$vext" status

# See test-switch-to-branch for rationale here
assert_outputs review "Wrong Superseded"

"$vext" update

check_expected 1379d75f0b4f 7219cf6e6d4706295246d278a3821ea923e1dfe2

