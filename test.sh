#!/bin/bash
set -e

# Build `lexv`
c3c build lexv

# Get path to the C3 standard library.
# If this causes problems, enter the path manually.
stdlib=$(c3c --build-env build lexv | awk '/^Stdlib/{print $3}')
echo "Using the C3 standard libary in: ${stdlib}"

# Locate unit tests
unittests="$(dirname $stdlib)/test/unit"
echo "Using the unit tests in: ${unittests}"

# Collect all files from the C3 standard library and unit tests.
files=()
files+=( $(find ${stdlib} -name "*.c3") )
files+=( $(find ${unittests} -name "*.c3") )

# Run the validation against the `c3c` compiler lexical output.
c3c -E compile-only ${files[@]} | build/lexv
