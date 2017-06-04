#!/bin/bash

write_project_file() {
    local libcontent=$(echo "$1" | sed 's/^/        /')
    cat > vext-project.json <<EOF
{
    "config": {
        "extdir": "ext"
    },
    "providers": {
	"testfile": {
	    "vcs": ["hg", "git"],
	    "anon": "file://$(pwd)/{repo}"
	}
    },
    "libs": {
$libcontent
    }
}
EOF
}

