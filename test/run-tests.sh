#!/bin/bash

set -eu

cd $(dirname "$0")

for t in ./test-*.sh ; do
    echo "Test: $t..."
    if $t; then
        echo "PASS: $t"
    else
        echo "FAIL: $t"
        exit 3
    fi
done

echo
echo "All tests passed"

