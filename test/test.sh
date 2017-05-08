#!/bin/bash

mydir=$(dirname "$0")

set -eu

cd "$mydir"

for sml in default smlnj mlton; do
    echo
    echo "Testing with implementation: $sml"
    echo
    export VEXT_SML
    VEXT_SML=""
    if [ "$sml" != "default" ]; then
	VEXT_SML="$sml"
    fi
    rm -rf ext
    ../vext check
    ../vext update
    ../vext check
    ls -l ext
    echo
done
