#!/usr/bin/env bash

export RUNONCREATECOMMAND=<value>

if [ "$RUNONCREATECOMMAND" = "false" ] && [ "$ON_CREATE_COMMAND" = "true" ]; then
  echo "Exiting because runOnCreateCommand is false and ON_CREATE_COMMAND is true"
  exit 0
fi

# Directory to search in (default to current directory if not specified)
SEARCH_DIR="${1:-$(pwd)}"

# Find all west workspaces
WEST_WORKSPACES=$(find "$SEARCH_DIR" -type d -name ".west" -exec dirname {} \; 2>/dev/null)

if [ -z "$WEST_WORKSPACES" ]; then
    echo "No West workspaces found in $SEARCH_DIR. Running west init..."

    MANIFEST_REPO_URL="https://github.com/zephyrproject-rtos/zephyr"

    LATEST_TAG=$(git ls-remote --tags --sort="-v:refname" "$MANIFEST_REPO_URL" | \
                 grep -E 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' | \
                 head -n 1 | \
                 sed 's?.*refs/tags/??')

    if [ -n "$LATEST_TAG" ]; then
        echo "Using the latest found manifest tag: $LATEST_TAG"
        west init "$SEARCH_DIR" --mr "$LATEST_TAG"
    else
        echo "ERROR: Could not determine the latest manifest tag."
        exit 1
    fi

    WEST_WORKSPACES=$(find "$SEARCH_DIR" -type d -name ".west" -exec dirname {} \; 2>/dev/null)
fi

echo "Found West workspace(s):"

# Create an array of workspaces
readarray -t WORKSPACE_ARRAY <<< "$WEST_WORKSPACES"

# Keep track of successes and failures
success_count=0
failure_count=0

for workspace in "${WORKSPACE_ARRAY[@]}"; do
    echo "Processing workspace: $workspace"

    # Save current directory to return to it later
    original_dir=$(pwd)

    # Change to the workspace directory
    cd "$workspace" || continue

    # Verify if RUST_SUPPORT is enabled
    if [ "${RUST_SUPPORT}" = "true" ]; then
        echo "Adding Rust support to the project."
        west config manifest.project-filter +zephyr-lang-rust
    fi

    echo "Running 'west update' in workspace: $workspace"
    if west update --narrow -o=--depth=1; then
        echo "✅ West update completed successfully in: $workspace"
        ((success_count++))
    else
        echo "❌ West update failed in: $workspace"
        ((failure_count++))
    fi

    # VIRTUAL_ENV set by install.sh
    "${VIRTUAL_ENV}/bin/pip" install --no-cache-dir -r zephyr/scripts/requirements.txt

    # Return to original directory
    cd "$original_dir" || exit 1

    echo "-------------------------------------------"
done

echo "Summary: West update succeeded in $success_count workspace(s) and failed in $failure_count workspace(s)"

# Return non-zero exit code if any updates failed
[ "$failure_count" -eq 0 ] || exit 1