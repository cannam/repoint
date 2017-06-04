#!/bin/bash

set -eu

cd $(dirname "$0")

for sml in default poly smlnj mlton; do
    echo
    echo "Testing with implementation: $sml"
    echo
    export VEXT_SML
    VEXT_SML=""
    if [ "$sml" != "default" ]; then
	VEXT_SML="$sml"
    fi
    ./run-tests.sh
    echo
done
