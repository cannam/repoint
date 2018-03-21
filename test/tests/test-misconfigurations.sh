#!/bin/bash

. $(dirname "$0")/include.sh

# 1. Config file is not valid JSON (in this case, is truncated)

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile"
},
"B": {
    "vcs": "git",
    "service": "testfile"
EOF
          )

prepare
write_project_file "$libcontent"
assert_failure install "Failed to parse"

# 2. Config file requests unknown VCS

libcontent=$(cat <<EOF
"A": {
    "vcs": "flarp",
    "service": "testfile"
}
EOF
          )

prepare
write_project_file "$libcontent"
assert_failure install "Unknown version-control system"

# 3. Config file contains unknown keys - this should not be a fatal
# error (might be nice to have a warning, but I don't think we even do
# that yet)

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile",
    "comment": "I like cheese"
}
EOF
          )

prepare
write_project_file "$libcontent"
"$vext" install

# 4. Config file defines same library more than once

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile"
},
"A": {
    "vcs": "hg",
    "service": "testfile"
}
EOF
          )

prepare
write_project_file "$libcontent"
assert_failure install "Duplicate key"


