#!/bin/bash

. $(dirname "$0")/include.sh

# We should always pull from / push to the remote specified in the
# repoint-project file, even if that is not the default remote for the
# repo as actually checked out (or even, is not yet configured as a
# remote at all). It might be nice as well if repoint status/review
# warned for this situation, but that's not essential.

# This is one of several tests in which the metadata necessary for
# "repoint status" to report correctly is absent when it is run; it isn't
# expected to produce the right output until "repoint review" has been
# run. But it mustn't crash.

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

break_hg_remote() {

    if ! grep -q "^ *default *=" "$current"/ext/A/.hg/hgrc ; then
        echo "ERROR: No default remote found in hg repo!?"
        exit 2
    fi

    perl -i -p -e \
         's,^ *default *=.*$,default = file:///nonexistent/path,' \
         "$current/ext/A/.hg/hgrc"
}

break_git_remote() {

    if ! grep -q "url =" "$current"/ext/B/.git/config ; then
        echo "ERROR: No remote urls found in git repo!?"
        exit 2
    fi

    perl -i -p -e \
         's,^([^a-z]*)url =.*$,$1url = file:///nonexistent/path,' \
         "$current/ext/B/.git/config"
}

break_svn_remote() {

    ( cd ../../testrepos
      cp -a C C2
    )

    ( cd "$current/ext/C"
      url=$(svn info | grep '^URL:' | awk '{ print $2; }')
      svn switch --relocate "$url" "$url"2
    )

    ( cd ../../testrepos
      rm -rf C2
    )
}

break_remotes() {
    break_hg_remote
    break_git_remote
    break_svn_remote
}

prepare
write_project_file "$libcontent"

"$repoint" install

break_remotes

"$repoint" status
"$repoint" review
"$repoint" install

break_remotes

"$repoint" update
