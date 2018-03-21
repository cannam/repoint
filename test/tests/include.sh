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
    for testrepo in A B C; do
        if [ ! -d ../../testrepos/$testrepo ]; then
            ( cd ../../testrepos
              tar xf $testrepo.tar.gz
            )
        fi
    done
}

prepare 
vextdir=../../..
vext="$vextdir"/vext

write_project_file_with_extpath() {
    local extpath="$1"
    local libcontent=$(echo "$2" | sed 's/^/        /')
    local testrepopath=$(cd ../../testrepos ; pwd)
    cat > vext-project.json <<EOF
{
    "config": {
        "extdir": "$extpath"
    },
    "services": {
	"testfile": {
	    "vcs": ["hg", "git", "svn"],
	    "anonymous": "file://$testrepopath/{repository}"
	}
    },
    "libraries": {
$libcontent
    }
}
EOF
}

write_project_file() {
    write_project_file_with_extpath "ext" "$@"
}

check_expected_with_extpath() {
    echo "Checking external repo IDs against expected values..."
    local extpath="$1"
    local id_A="$2"
    local id_B="$3"
    local id_C="$4"
    local actual_id_A=$( cd "$extpath"/A ; hg id | awk '{ print $1 }' | sed 's/\+$//' )
    if [ "$actual_id_A" != "$id_A" ]; then
        echo "ERROR: id for repo A ($actual_id_A) does not match expected ($id_A)"
        exit 3
    fi
    local actual_id_B=$( cd "$extpath"/B ; git rev-parse HEAD )
    if [ "$actual_id_B" != "$id_B" ]; then
        echo "ERROR: id for repo B ($actual_id_B) does not match expected ($id_B)"
        exit 3
    fi
    # NB we don't use "svn info --show-item revision" because we still
    # want svn 1.8 compatibility (at the time of writing)a
    local actual_id_C=$( cd "$extpath"/C ; svn info | grep '^Revision:' | awk '{ print $2; }' )
    if [ "$actual_id_C" != "$id_C" ]; then
        echo "ERROR: id for repo C ($actual_id_C) does not match expected ($id_C)"
        exit 3
    fi
    cat > expected-lock.json <<EOF
{
  "libraries": {
    "A": {
      "pin": "$id_A"
    },
    "B": {
      "pin": "$id_B"
    },
    "C": {
      "pin": "$id_C"
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

check_expected() {
    check_expected_with_extpath "ext" "$@"
}

assert_failure() {
    local task="$1"
    local error_text="$2"
    echo "Checking expected failure mode for vext $task (expected error text: \"$error_text\")"
    local output
    if output=$( "$vext" "$task" 2>&1 ); then
        echo "ERROR: vext $task was expected to fail here (expected error text: \"$error_text\")"
        exit 3
    else
        if echo "$output" | fgrep -q "$error_text"; then
            echo OK
        else
            echo "ERROR: vext $task printed unexpected error message \"$output\" (expected to see text \"$error_text\")"
            exit 3
        fi
    fi
}

assert_outputs() {
    local task="$1"
    local expected="$2"
    echo "Checking $task outputs against expected values..."
    local output=$("$vext" "$task" | grep '|' | tail -3 |
                       awk -F'|' '{ print $2 }' |
                       sed 's/ //g' |
                       fmt -80)
    if [ "$output" != "$expected" ]; then
        echo "ERROR: output for task $task ($output) does not match expected ($expected)"
        exit 3
    else
        echo OK
    fi
}    

assert_local_outputs() {
    local task="$1"
    local expected="$2"
    echo "Checking $task local outputs against expected values..."
    local output=$("$vext" "$task" | grep '|' | tail -3 |
                       awk -F'|' '{ print $3 }' |
                       sed 's/ //g' |
                       fmt -80)
    if [ "$output" != "$expected" ]; then
        echo "ERROR: local output for task $task ($output) does not match expected ($expected)"
        exit 3
    else
        echo OK
    fi
}    

assert_all() {
    assert_outputs "$1" "$2 $2 $2"
}

assert_all_present() {
    assert_all "$1" "Present"
}

assert_all_correct() {
    assert_all "$1" "Correct"
}

assert_all_superseded() {
    assert_all "$1" "Superseded"
}

assert_contents() {
    local file="$1"
    local expected="$2"
    local contents=$(cat "$file")
    if [ "$contents" != "$expected" ]; then
        echo "ERROR: contents of file $file ($contents) does not match expected ($expected)"
        exit 3
    else
        echo OK
    fi
}
