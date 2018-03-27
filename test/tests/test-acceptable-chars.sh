#!/bin/bash

. $(dirname "$0")/include.sh

# Not in any way exhaustive. There are different expected behaviours
# for URLs and filenames, but the tool doesn't actually distinguish --
# it just tries to reject anything that might cause a problem with
# shell quoting

unacceptable_names="re'po|re\"po|re\\\npo|re\\\\po|re>po|!repo"
acceptable_names="repo|re_po|re-po|re+po|re,po|re po|re?po|repø|مستودع"

# We also allow through # and @ for use in URLs, but they are often
# parsed by the VCS so we can't just use a matching filename and
# expect it to work. Not quite sure how to handle that.

try_name() {
    name="$1"
    is_acceptable="$2"

    for vcs in hg git svn ; do
        ( cd ../../testrepos
          rm -rf "$name"
          case "$vcs" in
              hg) hg clone "A" "$name" ;;
              git) git clone -bmaster "B" "$name" ;;
              svn) cp -a "C" "$name" ;;
          esac
        )
            
        libcontent=$(cat <<EOF
"$name": {
    "vcs": "$vcs",
    "service": "testfile",
    "repository": "$name"
}
EOF
                  )

        prepare
        write_project_file "$libcontent"

        if [ "$is_acceptable" = "yes" ]; then
            "$repoint" install
        elif "$repoint" install; then
            echo "ERROR: repoint install with unacceptable name $name was expected to fail"
            exit 3
        else
            echo "(The prior command was expected to print an error, continuing)"
        fi

        ( cd ../../testrepos
          rm -rf "$name"
        )
    done
}

echo "$unacceptable_names" | sed 's/|/\n/g' | while read name; do
    try_name "$name" "no"
done

echo "$acceptable_names" | sed 's/|/\n/g' | while read name; do
    try_name "$name" "yes"
done


