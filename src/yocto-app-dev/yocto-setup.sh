#!/usr/bin/env bash
set -e

# Environment variables from devcontainer feature options
# Default SDK tar file location if not specified
YOCTO_SDK_TAR_FILE=${YOCTO_SDK_TAR_FILE:-"./yocto-standard-sdk.tar.gz"}
# Default SDK directory if not specified
YOCTO_SDK_DIR=${YOCTO_SDK_DIR:-"$PWD"}
# Default unzipped SDK path
YOCTO_SDK_SUBDIR="yocto-standard-sdk"
YOCTO_SDK_ENV_DIR="${YOCTO_SDK_DIR}/${YOCTO_SDK_SUBDIR}"

# Extract Yocto SDK if not already extracted
extract_yocto_sdk() {
    echo "Setting up Yocto SDK..."
    
    # Check if SDK has already been extracted (check for a marker file or directory)
    if [ ! -f "${YOCTO_SDK_DIR}/.yocto_sdk_extracted" ]; then
        echo "Extracting Yocto SDK from ${YOCTO_SDK_TAR_FILE}..."
        
        # Check if tar file exists
        if [ ! -f "${YOCTO_SDK_TAR_FILE}" ]; then
            echo "Error: Yocto SDK tar file not found at ${YOCTO_SDK_TAR_FILE}"
            exit 1
        fi
        
        # Create SDK directory if it doesn't exist
        mkdir -p "${YOCTO_SDK_DIR}"
        
        # Extract the SDK to the specified directory
        tar -xzf "${YOCTO_SDK_TAR_FILE}" -C "${YOCTO_SDK_DIR}"
        
        # Create a marker file to indicate extraction has been done
        echo $(sha256sum "${YOCTO_SDK_TAR_FILE}" | awk '{print $1}') > "${YOCTO_SDK_DIR}/.yocto_sdk_extracted"
        
        echo "Yocto SDK extracted successfully to ${YOCTO_SDK_DIR}"
    else
        echo "Yocto SDK has already been extracted to ${YOCTO_SDK_DIR}, skipping extraction"
    fi
    echo "Using environment setup directory: ${YOCTO_SDK_ENV_DIR}"
}

# Setup environment for Yocto SDK app build
setup_yocto_environment() {
    echo "Setting up Yocto SDK environment..."
    
    # Check if SDK environment directory exists
    if [ ! -d "${YOCTO_SDK_ENV_DIR}" ]; then
        echo "Error: Yocto SDK environment directory not found at ${YOCTO_SDK_ENV_DIR}"
        exit 1
    fi
    # Check if directory exists before creating
    if [ ! -d "/eo_workdir" ]; then
        mkdir -p /eo_workdir
    fi

    ln -sf "$(pwd)/${YOCTO_SDK_SUBDIR}" "/eo_workdir/${YOCTO_SDK_SUBDIR}"

    # Check if environment setup scripts exist
    if ls "${YOCTO_SDK_ENV_DIR}"/environment-setup-* >/dev/null 2>&1; then
        # Create a script in /etc/profile.d to source the environment setup script
        cat <<EOL > /etc/bash.bashrc
#!/bin/bash
# Source Yocto SDK environment
for script in $(find "${YOCTO_SDK_ENV_DIR}" -name "environment-setup-*" 2>/dev/null); do
    if [ -f "\$script" ]; then
        . "\$script"
    fi
done
EOL
        chmod +x /etc/bash.bashrc
        
        echo "Yocto SDK environment setup completed successfully"
    else
        echo "Warning: Yocto SDK environment setup script not found in ${YOCTO_SDK_ENV_DIR}"
        # Continue anyway as the SDK might have a different structure
    fi
}

# Main function
main() {
    echo "Starting Yocto SDK installation process..."
    extract_yocto_sdk
    setup_yocto_environment
    echo "Yocto SDK installation process completed successfully"
}

# Run the main function
main
