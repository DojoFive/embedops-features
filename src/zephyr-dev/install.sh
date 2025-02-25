#!/usr/bin/env bash
set -x

export DEBIAN_FRONTEND=noninteractive
# Load system info, including OS type
. /etc/os-release

# Determine base Linux distribution
if [[ "${ID}" != "debian" && ! "${ID_LIKE}" =~ "debian" ]]; then
    echo "Error: Unsupported Linux distribution '${ID}'."
    exit 1
fi

pkg_mgr_update() {
    apt-get update -y
}

check_packages() {
    apt-get install -y --no-install-recommends "$@"
}

# Determine system architecture and store it in a variable
case "$(uname -m)" in
    x86_64)
        ARCH="x86_64"
        ;;
    aarch64)
        ARCH="aarch64"
        ;;
    *)
        echo "Error: Unsupported architecture '$(uname -m)'. Zephyr SDK is only available for x86_64 and aarch64."
        exit 1
        ;;
esac

install_python_and_dependencies() {
    echo "Installing Python dependencies for Debian..."

    # Install `build-essential` only if the architecture is aarch64
    if [[ "${ARCH}" == "aarch64" ]]; then
        echo "Detected architecture: aarch64. Installing 'build-essential'."
        check_packages build-essential
    fi


    check_packages wget git python3 python3-pip python3-venv python3-dev cmake ninja-build gperf device-tree-compiler xz-utils
}

install_zephyr_sdk() {
    echo "Installing Zephyr SDK..."

    # Check if ZEPHYR_SDK_VERSION is set, otherwise exit
    if [[ -z "${ZEPHYR_SDK_VERSION}" ]]; then
        echo "Error: ZEPHYR_SDK_VERSION is not set. Please provide the SDK version as a feature variable."
        exit 1
    fi

    local SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-${ARCH}_minimal.tar.xz"
    local INSTALL_DIR="/opt/zephyr-sdk"

    mkdir -p "${INSTALL_DIR}"
    wget -q "${SDK_URL}" -O /tmp/zephyr-sdk.tar.xz || { echo "Error: Failed to download Zephyr SDK."; exit 1; }
    tar -xf /tmp/zephyr-sdk.tar.xz -C "${INSTALL_DIR}" --strip-components=1 || { echo "Error: Failed to extract Zephyr SDK."; exit 1; }
    rm /tmp/zephyr-sdk.tar.xz

    if [[ ! -f "${INSTALL_DIR}/setup.sh" ]]; then
        echo "Error: Zephyr SDK install script not found!"
        exit 1
    fi

    "${INSTALL_DIR}/setup.sh" -c -t arm-zephyr-eabi

    echo 'export ZEPHYR_TOOLCHAIN_VARIANT=zephyr' >> /etc/profile
    echo "export ZEPHYR_SDK_INSTALL_DIR=${INSTALL_DIR}" >> /etc/profile

    # Load environment variables for the current shell
    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=${INSTALL_DIR}
}

setup_zephyr_venv() {
    echo "Setting up Zephyr Python Virtual Environment..."
    local VENV_DIR="/opt/zephyrproject/.venv"

    mkdir -p /opt/zephyrproject

    # Create venv
    if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
        echo "Creating Python virtual environment at ${VENV_DIR}..."
        python3 -m venv "${VENV_DIR}" || { echo "Error: Failed to create Python venv."; exit 1; }
    fi

    export VIRTUAL_ENV="${VENV_DIR}"
    export PATH="${VENV_DIR}/bin:${PATH}"

    echo "Virtual environment configured: VIRTUAL_ENV=${VIRTUAL_ENV}"
    echo "Installing west and setuptools in virtual environment..."

    "${VIRTUAL_ENV}/bin/pip" install --no-cache-dir --upgrade pip setuptools west || { echo "Error: Failed to install dependencies in venv."; exit 1; }
}

initialize_zephyr_project() {
    echo "Initializing Zephyr project..."

    local ZEPHYR_PROJECT_DIR="/opt/zephyrproject"

    if [[ ! -d "${ZEPHYR_PROJECT_DIR}/zephyr" ]]; then
        echo "Cloning Zephyr repository and modules..."
        west init -m https://github.com/zephyrproject-rtos/zephyr.git "${ZEPHYR_PROJECT_DIR}" || { echo "Error: Failed to initialize Zephyr repository."; exit 1; }
    fi

    cd "${ZEPHYR_PROJECT_DIR}" || { echo "Error: Zephyr project directory not found."; exit 1; }

    west update
    west zephyr-export

    "${VIRTUAL_ENV}/bin/pip" install --no-cache-dir -r zephyr/scripts/requirements.txt || { echo "Error: Failed to install Zephyr dependencies."; exit 1; }
}

persist_zephyr_env() {
    echo "Persisting Zephyr environment in /etc/profile.d/zephyr.sh..."

    cat <<EOL > /etc/profile.d/zephyr.sh
# Zephyr Environment
export VIRTUAL_ENV=/opt/zephyrproject/.venv
export PATH="\$VIRTUAL_ENV/bin:\$PATH"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk
EOL

    chmod +x /etc/profile.d/zephyr.sh
}

main() {
    echo "Starting Zephyr installation process..."
    pkg_mgr_update
    install_python_and_dependencies
    install_zephyr_sdk
    setup_zephyr_venv
    initialize_zephyr_project
    persist_zephyr_env

    echo "Zephyr installation process completed successfully."
}

main "$@"