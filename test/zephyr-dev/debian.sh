#!/bin/bash

# This test file will be executed against one of the scenarios devcontainer.json test that
# includes the 'color' feature with "greeting": "hello" option.

set -e

source dev-container-features-test-lib

# simple project to build
./create-project.sh
cd zephyr_blinky_project

# simulate onCreateCommand
/usr/local/bin/update-west-workspaces.sh

# Feature-specific tests
# The 'check' command comes from the dev-container-features-test-lib. Syntax is...
# check <LABEL> <cmd> [args...]
check "debian: west update" bash -c "west update --narrow -o=--depth=1"
check "debian: west build" bash -c "west build -b reel_board -s app"

# Report results
# If any of the checks above exited with a non-zero exit code, the test will fail.
reportResults