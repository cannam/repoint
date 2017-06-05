#!/bin/bash

if [ "$1" = "-v" ]; then
    verbose="-v"
elif [ -n "$1" ]; then
    echo
    echo " Usage: $0 [-v]"
    echo "where -v : Show verbose output from tests"
    echo
    exit 2
else
    verbose=""
fi

set -eu

cd $(dirname "$0")

count=$(ls -1 test-*.sh | wc -l | sed 's/[^0-9]//g')
i=1
passcount=0
failcount=0
failing=""

run_a_test() {
    local test="$1"
    if [ -n "$verbose" ]; then
        ./$t
    else
        ./$t >/dev/null 2>&1
    fi
}

if [ -z "$verbose" ]; then echo; fi

for t in test-*.sh ; do
    if [ -n "$verbose" ]; then 
        echo
        echo "Test $i/$count: $t..."
    fi
    if run_a_test $t; then
        echo "PASS: $t"
        passcount=$(($passcount+1))
    else
        echo "FAIL: $t"
        failcount=$(($failcount+1))
        failing="$failing $t"
    fi
    i=$(($i + 1))
done

if [ "$passcount" = "$count" ]; then
    echo
    echo "** PASS: All tests ($passcount/$count) passed"
    echo
else
    echo
    echo "** FAIL: $failcount tests (of $count) failed"
    echo "** Failing tests:$failing"
    if [ -z "$verbose" ]; then
        echo "** Re-run with -v for verbose output"
    fi
    echo
    exit 3
fi



