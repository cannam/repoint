#!/bin/bash

. $(dirname "$0")/include.sh

# A failed pull attempt in install or update should leave both the
# repo and the repo's record in the project lock file unchanged.

libcontent=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile"
},
"B": {
    "vcs": "git",
    "service": "testfile"
},
"C": {
    "vcs": "svn",
    "service": "testfile"
}
EOF
          )

# Each of these still has two working repo remotes in it, in case that
# makes Repoint think the whole thing has succeeded when it hasn't

broken_libcontent_A=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "failing-localhost"
},
"B": {
    "vcs": "git",
    "service": "testfile"
},
"C": {
    "vcs": "svn",
    "service": "testfile"
}
EOF
          )

broken_libcontent_B=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile"
},
"B": {
    "vcs": "git",
    "service": "failing-localhost"
},
"C": {
    "vcs": "svn",
    "service": "testfile"
}
EOF
          )

broken_libcontent_C=$(cat <<EOF
"A": {
    "vcs": "hg",
    "service": "testfile"
},
"B": {
    "vcs": "git",
    "service": "testfile"
},
"C": {
    "vcs": "svn",
    "service": "failing-localhost"
}
EOF
          )

still_ok() {
    check_expected_lockfile f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2
}

prepare

for repo in A B C ; do

    write_project_file "$libcontent"

    "$repoint" install
    check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

    case "$repo" in
        A) write_project_file "$broken_libcontent_A";;
        B) write_project_file "$broken_libcontent_B";;
        C) write_project_file "$broken_libcontent_C";;
    esac

    "$repoint" install
    still_ok

    assert_failure update "Some operations failed"
    still_ok

    ( cd ext/A ; hg update -r5bc0 )
    ( cd ext/B ; git checkout da969 )
    ( cd ext/C ; svn update -r1 )

    case "$repo" in
        C) assert_failure install "Some operations failed";;
        *) "$repoint" install
    esac
    still_ok

    assert_failure update "Some operations failed"
    still_ok

    rm -rf ext/A ext/B ext/C
    
    assert_failure install "Some operations failed"
    still_ok

done

write_project_file "$libcontent"
"$repoint" install
check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2
