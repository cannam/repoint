#!/bin/bash

. $(dirname "$0")/include.sh

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

for task in install update ; do
    prepare
    write_project_file "$libcontent"

    "$vext" $task
    check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

    # Now switch manually to an earlier revision and make sure vext
    # still behaves sensibly afterwards

    ( cd ext/A ; hg update -r8796fac39bdc )
    ( cd ext/B ; git checkout --detach da969d8e5b1adc776615be523045cf3d28bedc09 )
    ( cd ext/C ; svn update -r 1 )

    assert_outputs status "Superseded Superseded Present"
    assert_all_superseded review

    "$vext" $task
    check_expected f94ae9d7e5c9 3199655c658ff337ce24f78c6d1f410f34f4c6f2 2

done

