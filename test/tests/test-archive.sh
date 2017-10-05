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
}
EOF
          )

archive_file="/tmp/vext-test-$$.tar.gz"

# archive requires project is version-controlled and should support
# the same set of VCS as supported for libraries

for project_vcs in hg git ; do

    author_flag=$(case "$project_vcs" in
                      hg) echo "--user";;
                      git) echo "--author";;
                  esac)
    
    rm -rf "$current"
    
    prepare
    write_project_file "$libcontent"

    # doesn't actually matter whether the project is updated before
    # archiving or not
    
    $project_vcs init
    $project_vcs add vext-project.json
    $project_vcs commit -m "Commit vext-project file" "$author_flag" "Test Person <test@example.com>"

    rm -f "$archive_file"
    "$vext" archive "$archive_file"

    for expected in A/file.txt B/file-b.txt ; do
        if ! tar tf "$archive_file" | grep -q "$expected" ; then
            echo "ERROR: expected to find file A/file.txt in archive"
            exit 3
        fi
    done

    # Add and commit a new file, re-archive, check that new file is
    # present; then drop back to the earlier revision, re-archive, and
    # check the archive is back to the original (i.e. we are archiving
    # the current revision, not the tip)

    id=$(case "$project_vcs" in
             hg)  hg id | awk '{ print $1 }';;
             git) git rev-parse HEAD;;
         esac)
    
    touch newfile
    $project_vcs add newfile
    $project_vcs commit -m "Add new file" "$author_flag" "Other Test Person <other@example.com>"

    rm -f "$archive_file"
    "$vext" archive "$archive_file"

    if ! tar tf "$archive_file" | grep -q newfile ; then
        echo "ERROR: expected to find newly-added file newfile in archive"
        exit 3
    fi 
    
    case "$project_vcs" in
        hg) hg update -r"$id";;
        git) git checkout --detach "$id";;
    esac
    
    rm -f "$archive_file"
    "$vext" archive "$archive_file"

    if tar tf "$archive_file" | grep -q newfile ; then
        echo "ERROR: expected *not* to find newly-added file newfile in archive when archiving from earlier revision"
        exit 3
    fi 
    
done

# if we don't have a project vcs, we can't archive

rm -rf "$current"
rm -f "$archive_file"
    
prepare
write_project_file "$libcontent"

if "$vext" archive "$archive_file" ; then
    echo "ERROR: vext archive from non-version-controlled project was expected to fail"
    exit 3
else
    echo "(The prior command was expected to print an error, continuing)"
fi

