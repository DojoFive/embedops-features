#!/bin/bash

# This test file will be executed against one of the scenarios devcontainer.json test

set -e

# Optional: Import test library bundled with the devcontainer CLI
source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib.
check "execute command after building from source" bash -c "cppcheck | grep 'Cppcheck - A tool for static C/C++ code analysis'"
check "make sure matching version" bash -c "cppcheck --version | grep 'Cppcheck 2.16.0'"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults