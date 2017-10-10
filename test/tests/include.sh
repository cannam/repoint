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

prepare 
vextdir=../../..
vext="$vextdir"/vext

write_project_file_with_extpath() {
    local extpath="$1"
    local libcontent=$(echo "$2" | sed 's/^/        /')
    cat > vext-project.json <<EOF
{
    "config": {
        "extdir": "$extpath"
    },
    "services": {
	"testfile": {
	    "vcs": ["hg", "git"],
	    "anonymous": "file://$(pwd)/../../testrepos/{repository}"
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
    cat > expected-lock.json <<EOF
{
  "libraries": {
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

check_expected() {
    check_expected_with_extpath "ext" "$@"
}

assert_outputs() {
    local task="$1"
    local expected="$2"
    echo "Checking $task outputs against expected values..."
    local output=$("$vext" "$task" | grep '|' | tail -2 |
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
    local output=$("$vext" "$task" | grep '|' | tail -2 |
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
    assert_outputs "$1" "$2 $2"
}

assert_all_wrong() {
    assert_all "$1" "Wrong"
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
