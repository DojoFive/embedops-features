#!/bin/bash

# This test file will be executed against one of the scenarios devcontainer.json test that
# includes the 'color' feature with "greeting": "hello" option.

set -e

source dev-container-features-test-lib

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib. Syntax is...
# check <LABEL> <cmd> [args...]
check "gcc" bash -c "gcc --version | grep 'This is free software'"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults