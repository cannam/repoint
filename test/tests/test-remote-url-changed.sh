#!/bin/bash

. $(dirname "$0")/include.sh

# We should always pull from / push to the remote specified in the
# vext-project file, even if that is not the default remote for the
# repo as actually checked out (or even, is not yet configured as a
# remote at all). It might be nice as well if vext status/review
# warned for this situation, but that's not essential.

# This is one of several tests in which the metadata necessary for
# "vext status" to report correctly is absent when it is run; it isn't
# expected to produce the right output until "vext review" has been
# run. But it mustn't crash.

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

break_remotes() {

    if ! grep -q "^ *default *=" "$current"/ext/A/.hg/hgrc ; then
        echo "ERROR: No default remote found in hg repo!?"
        exit 2
    fi
    if ! grep -q "url =" "$current"/ext/B/.git/config ; then
        echo "ERROR: No remote urls found in git repo!?"
        exit 2
    fi

    perl -i -p -e \
         's,^ *default *=.*$,default = file:///nonexistent/path,' \
         "$current/ext/A/.hg/hgrc"

    perl -i -p -e \
         's,^([^a-z]*)url =.*$,$1url = file:///nonexistent/path,' \
         "$current/ext/B/.git/config"
}

prepare
write_project_file "$libcontent"

"$vext" install

break_remotes

"$vext" status
"$vext" review
"$vext" update
