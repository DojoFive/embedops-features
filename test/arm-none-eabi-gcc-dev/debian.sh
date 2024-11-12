#!/bin/bash

# This test file will be executed against one of the scenarios devcontainer.json test that
# includes the 'color' feature with "greeting": "hello" option.

set -e

source dev-container-features-test-lib

# simple project to build
./create-project.sh
cd arm_project/build

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib. Syntax is...
# check <LABEL> <cmd> [args...]
check "debian: cmake config" bash -c "cmake -GNinja -DCMAKE_TOOLCHAIN_FILE=../toolchain.cmake .. | grep 'Build files have been written to'"
check "debian: ninja build" bash -c "ninja | grep 'Linking C executable arm_project'"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults