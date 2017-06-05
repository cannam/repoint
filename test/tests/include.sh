#!/bin/bash

set -eu
mydir=$(dirname "$0")
case "$mydir" in
    /*) ;;
    *) mydir=$(pwd)/"$mydir" ;;
esac
current="$mydir"/current

prepare() {
    mkdir -p "$current"
    cd "$current"
    if [ ! -f ../include.sh ]; then
        echo "ERROR: Failed safety check: Path passed to prepare should be a subdir of test directory"
        exit 2
    fi
    rm -rf ext *.json
    if [ ! -d ../../testrepos/A ]; then
        ( cd ../../testrepos
          tar xf A.tar.gz
          tar xf B.tar.gz
        )
    fi
}

write_project_file() {
    local libcontent=$(echo "$1" | sed 's/^/        /')
    cat > vext-project.json <<EOF
{
    "config": {
        "extdir": "ext"
    },
    "providers": {
	"testfile": {
	    "vcs": ["hg", "git"],
	    "anon": "file://$(pwd)/../../testrepos/{repo}"
	}
    },
    "libs": {
$libcontent
    }
}
EOF
}

check_expected() {
    echo "Checking external repo IDs against expected values..."
    local id_A="$1"
    local id_B="$2"
    local actual_id_A=$( cd ext/A ; hg id | awk '{ print $1 }' )
    if [ "$actual_id_A" != "$id_A" ]; then
        echo "ERROR: id for repo A ($actual_id_A) does not match expected ($id_A)"
        exit 3
    fi
    local actual_id_B=$( cd ext/B ; git rev-parse HEAD )
    if [ "$actual_id_B" != "$id_B" ]; then
        echo "ERROR: id for repo B ($actual_id_B) does not match expected ($id_B)"
        exit 3
    fi
    cat > expected-lock.json <<EOF
{
  "libs": {
    "A": {
      "pin": "$id_A"
    },
    "B": {
      "pin": "$id_B"
    }
  }
}
EOF
    if cmp -s vext-lock.json expected-lock.json ; then
        echo OK
    else
        echo "ERROR: Contents of vext-lock.json does not match expected"
        echo "Diff follows (vext-lock.json on left, expected on right):"
        sdiff -w120 vext-lock.json expected-lock.json
        exit 3
    fi
}

prepare 
vextdir=../../..

