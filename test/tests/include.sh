#!/bin/bash

set -eu
mydir=$(dirname "$0")
case "$mydir" in
    /*) ;;
    *) mydir=$(pwd)/"$mydir" ;;
esac
current="$mydir"/current

prepare() {
    cd "$mydir" && mkdir -p "$current" && cd "$current"
    if [ ! -f ../include.sh ]; then
        echo "ERROR: Failed safety check: Path used by prepare should be a subdir of test directory"
        exit 2
    fi
    cd "$mydir" && rm -rf "$current" && mkdir -p "$current" && cd "$current"
    for testrepo in A B Bmain C; do
        if [ ! -d ../../testrepos/$testrepo ]; then
            ( cd ../../testrepos
              tar xf $testrepo.tar.gz
            )
        fi
    done
}

prepare 
repointdir="$current"/../../..
repoint="$repointdir"/repoint

write_project_file_with_extpath() {
    local extpath="$1"
    local libcontent=$(echo "$2" | sed 's/^/        /')
    local testrepopath=$(cd ../../testrepos ; pwd)
    cat > repoint-project.json <<EOF
{
    "config": {
        "extdir": "$extpath"
    },
    "services": {
	"testfile": {
	    "vcs": ["hg", "git", "svn"],
	    "anonymous": "file://$testrepopath/{repository}"
	},
        "failing-localhost": {
            "vcs": ["hg", "git", "svn"],
	    "anonymous": "http://127.0.0.1:22/{repository}"
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

check_expected_lockfile() {
    echo "Checking lockfile pin IDs against expected values..."
    local id_A="$1"
    local id_B="$2"
    local id_C="$3"
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
    if cmp -s repoint-lock.json expected-lock.json ; then
        echo OK
    else
        echo "ERROR: Contents of repoint-lock.json does not match expected"
        echo "Diff follows (repoint-lock.json on left, expected on right):"
        sdiff -w120 repoint-lock.json expected-lock.json
        exit 3
    fi
}    

check_id() {
    local actual="$1"
    local expected="$2"
    local repo="$3"
    if [ "$actual" != "$expected" ]; then
        echo "ERROR: id for repo $repo ($actual) does not match expected ($expected)"
        exit 3
    fi
}

check_string() {
    local actual="$1"
    local expected="$2"
    local context="$3"
    if [ "$actual" != "$expected" ]; then
        echo "ERROR: incorrect $context: actual value ($actual) does not match expected ($expected)"
        exit 3
    fi
}

check_expected_with_extpath() {
    echo "Checking external repo IDs against expected values..."
    local extpath="$1"
    local id_A="$2"
    local id_B="$3"
    local id_C="$4"
    local actual_id_A=$( cd "$extpath"/A ; hg id | awk '{ print $1 }' | sed 's/\+$//' )
    check_id "$actual_id_A" "$id_A" "A"
    local actual_id_B=$( cd "$extpath"/B ; git rev-parse HEAD )
    check_id "$actual_id_B" "$id_B" "B"
    # NB we don't use "svn info --show-item revision" because we still
    # want svn 1.8 compatibility (at the time of writing)
    local actual_id_C=$( cd "$extpath"/C ; svn info | grep '^Revision:' | awk '{ print $2; }' )
    check_id "$actual_id_C" "$id_C" "C"
    check_expected_lockfile "$id_A" "$id_B" "$id_C"
}

check_expected() {
    check_expected_with_extpath "ext" "$@"
}

assert_failure() {
    local task="$1"
    local error_text="$2"
    echo "Checking expected failure mode for repoint $task (expected error text: \"$error_text\")"
    local output
    if output=$( "$repoint" "$task" 2>&1 ); then
        echo "ERROR: repoint $task was expected to fail here (expected error text: \"$error_text\")"
        exit 3
    else
        if echo "$output" | fgrep -q "$error_text"; then
            echo OK
        else
            echo "ERROR: repoint $task printed unexpected error message \"$output\" (expected to see text \"$error_text\")"
            exit 3
        fi
    fi
}

assert_outputs() {
    local task="$1"
    local expected="$2"
    echo "Checking $task outputs against expected values..."
    local output=$("$repoint" "$task" | grep '|' | tail -3 |
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
    local output=$("$repoint" "$task" | grep '|' | tail -3 |
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
