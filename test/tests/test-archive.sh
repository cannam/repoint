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

archive_file="/tmp/repoint-test-$$.tar.gz"

# archive requires project is version-controlled and should support
# the same set of VCS as supported for libraries

for project_vcs in hg git svn ; do

    author_flag="--author"
    if [ "$project_vcs" = "hg" ]; then
	author_flag="--user"
    elif [ "$project_vcs" = "svn" ]; then
        author_flag="--username" # should be ignored for file URL,
                                 # which is what we want
    fi
    
    rm -rf "$current"
    rm -rf "$current.svn"
    
    prepare
    write_project_file "$libcontent"

    # doesn't actually matter whether the project is updated before
    # archiving or not

    if [ "$project_vcs" = "svn" ]; then
        svnadmin create "$current.svn"
        ( cd ..
          svn checkout file://"$current.svn" "$current" )
    else
        $project_vcs init
    fi
    
    $project_vcs add repoint-project.json
    $project_vcs commit -m "Commit repoint-project file" "$author_flag" "Test Person <test@example.com>"

    if [ "$project_vcs" = "svn" ]; then
        # need to update after committing
        $project_vcs update
    fi

    rm -f "$archive_file"
    "$repoint" archive "$archive_file"

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

    id=""
    if [ "$project_vcs" = "hg" ]; then
	id=$(hg id | awk '{ print $1 }')
    elif [ "$project_vcs" = "git" ]; then
	id=$(git rev-parse HEAD)
    elif [ "$project_vcs" = "svn" ]; then
	id=$(svn info | grep '^Revision:' | awk '{ print $2; }')
    else
        echo "Internal error: unknown VCS" 1>&2
        exit 2
    fi
    
    touch newfile
    $project_vcs add newfile
    $project_vcs commit -m "Add new file" "$author_flag" "Other Test Person <other@example.com>"

    if [ "$project_vcs" = "svn" ]; then
        # need to update after committing
        $project_vcs update
    fi
    
    rm -f "$archive_file"
    "$repoint" archive "$archive_file"

    if ! tar tf "$archive_file" | grep -q newfile ; then
        echo "ERROR: expected to find newly-added file newfile in archive"
        exit 3
    fi

    rm -f "$archive_file"
    "$repoint" archive "$archive_file" --exclude newfile
    
    if tar tf "$archive_file" | grep -q newfile ; then
        echo "ERROR: expected *not* to find newfile in archive when listed as exclusion"
        exit 3
    fi

    rm -f "$archive_file"
    "$repoint" archive "$archive_file" --exclude newfile file.txt file-b.txt file-c.txt
    
    if tar tf "$archive_file" | grep -q file ; then
        echo "ERROR: expected not to find files in archive that were listed as exclusions"
        exit 3
    fi
    
    case "$project_vcs" in
        hg) hg update -r"$id";;
        git) git checkout --detach "$id";;
        svn) svn update -r"$id";;
    esac
    
    rm -f "$archive_file"
    "$repoint" archive "$archive_file"

    if tar tf "$archive_file" | grep -q newfile ; then
        echo "ERROR: expected *not* to find newly-added file newfile in archive when archiving from earlier revision"
        exit 3
    fi 
    
done

# if we don't have a project vcs, we can't archive

rm -rf "$current"
rm -rf "$current.svn"
rm -f "$archive_file"
    
prepare
write_project_file "$libcontent"

if "$repoint" archive "$archive_file" ; then
    echo "ERROR: repoint archive from non-version-controlled project was expected to fail"
    exit 3
else
    echo "(The prior command was expected to print an error, continuing)"
fi

