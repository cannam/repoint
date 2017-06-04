#!/bin/bash

set -eu

cd $(dirname "$0")

for t in ./test-*.sh ; do
    echo "Test: $t..."
    $t
done

