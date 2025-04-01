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

if [ -n "$WEST_WORKSPACES" ]; then
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
    
else
    echo "No West workspaces found in $SEARCH_DIR"
    exit 1
fi