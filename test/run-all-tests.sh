#!/bin/bash

if [ "$1" = "-v" ]; then
    verbose="-v"
elif [ -n "$1" ]; then
    echo
    echo " Usage: $0 [-v]"
    echo
    echo "        -v   Show verbose output from tests"
    echo
    exit 2
else
    verbose=""
fi

set -eu

cd $(dirname "$0")

count=4
failcount=0
failing=""

echo

for sml in default polyml smlnj mlton mlkit; do
    if [ "$sml" = mlkit ]; then
        if ! mlkit 1>/dev/null 2>&1 ; then
            echo "MLKit apparently not installed, skipping that implementation"
            continue
        fi
    fi
    echo "Testing with implementation: $sml"
    export REPOINT_SML
    REPOINT_SML=""
    if [ "$sml" != "default" ]; then
	REPOINT_SML="$sml"
    fi
    if time ./run-tests.sh $verbose; then
        echo
    else
        failcount=$(($failcount+1))
        failing="$failing $sml"
    fi
done

if [ "$failcount" = "0" ]; then
    echo "** PASS: All implementation test suites ($count/$count) passed"
    echo
else
    echo "** FAIL: $failcount implementation test suites (of $count) failed"
    echo "** Failing implementations:$failing"
    if [ -z "$verbose" ]; then
        echo "** Re-run with -v for verbose output"
    fi
    echo
    exit 3
fi

