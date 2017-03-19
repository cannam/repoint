#!/bin/bash

set -e

usage() {
    echo "Usage: $0 <command>" 1>&2
    echo "where <command> is check or update" 1>&2
    exit 1
}

command="$1"
    
case "$command" in
    check|update) ;;
    *) usage ;;
esac

shift
set -u

config=$(pwd)/.vex
external=$(pwd)/ext

if [ ! -f "$config" ]; then
    echo "ERROR: Config file $config not found, exiting" 1>&2
fi

mkdir -p "$external"

cat .vex | while IFS='|' read name vcs service user tag ; do
    dir="$external/$name"
    if [ -z "$name" ] || [ -z "$user" ]; then
	echo "ERROR: Name and user fields (first and fourth fields) are mandatory" 1>&2
	exit 1
    fi
    case "$vcs" in
	hg) ;;
	git) ;;
	*) echo "ERROR: VCS $vcs not supported (may be \"hg\" or \"git\") [for name $name]" 1>&2
	   exit 1;;
    esac
    case "$service" in
	github) ;;
	bitbucket) ;;
	soundsoftware) ;;
	*) echo "ERROR: Service $service not supported [for name $name]" 1>&2
	   exit 1;;
    esac
    if [ -d "$dir" ] ; then
	if [ ! -d "$dir/.$vcs" ]; then
	    echo "ERROR: Directory $dir already exists and is not of repo type $vcs" 1>&2
	    exit 1
	fi
    fi
done

cat .vex | while IFS='|' read name vcs service user tag ; do
    dir="$external/$name"
    case "$vcs,$service" in
	git,github) url="ssh://git@github.com/$user/$name" ;;
	git,bitbucket) url="ssh://git@bitbucket.org/$user/$name" ;;
	hg,bitbucket) url="ssh://hg@bitbucket.org/$user/$name" ;;
	hg,soundsoftware) url="https://code.soundsoftware.ac.uk/hg/$name" ;;
    esac
    if [ -z "$tag" ]; then
	case "$vcs" in
	    git) tag=master;;
	    hg) tag=tip;;
	esac
    fi
    case "$command" in
	update)
	    echo "Retrieving $name from $url to $dir..."
	    case "$vcs" in
		git)
		    if [ -d "$dir" ]; then
			( cd "$dir"; git fetch "$url" && git checkout "$tag" )
		    else
			git clone "$url" "$dir"
		    fi;;
		hg)
		    if [ -d "$dir" ]; then
			( cd "$dir"; hg pull && hg update "$tag" )
		    else
			hg clone "$url" "$dir"
		    fi;;
	    esac;;
	check)
	    echo "Checking $name from $url..."
	    if [ -d "$dir" ]; then
		case "$vcs" in
		    git)
			( cd "$dir"; git fetch "$url" && git status );;
		    hg)
			( cd "$dir"; hg incoming || true );;
		esac
	    else
		echo "Directory does not exist yet"
	    fi;;
    esac
done
