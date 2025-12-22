#!/usr/bin/env bash
set -x

export DEBIAN_FRONTEND=noninteractive
# Load system info, including OS type
. /etc/os-release

# Determine base Linux distribution
if [[ "${ID}" = "debian" || "${ID_LIKE}" = "debian" ]]; then
    ADJUSTED_ID="debian"
elif [ "${ID}" = "alpine" ]; then
    ADJUSTED_ID="alpine"
else
    echo "Linux distro ${ID} not supported."
    exit 1
fi

if type apt-get > /dev/null 2>&1; then
    INSTALL_CMD=apt-get
elif type apk > /dev/null 2>&1; then
    INSTALL_CMD=apk
elif type microdnf > /dev/null 2>&1; then
    INSTALL_CMD=microdnf
elif type dnf > /dev/null 2>&1; then
    INSTALL_CMD=dnf
elif type yum > /dev/null 2>&1; then
    INSTALL_CMD=yum
else
    echo "(Error) Unable to find a supported package manager."
    exit 1
fi

pkg_mgr_update() {
    if [ ${INSTALL_CMD} = "apt-get" ]; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            echo "Running apt-get update..."
            ${INSTALL_CMD} update -y
        fi
    elif [ ${INSTALL_CMD} = "apk" ]; then
        if [ "$(find /var/cache/apk/* | wc -l)" = "0" ]; then
            echo "Running apk update..."
            ${INSTALL_CMD} update
        fi
    fi
}

check_packages() {
    if [ ${INSTALL_CMD} = "apt-get" ]; then
        if ! dpkg -s "$@" > /dev/null 2>&1; then
            pkg_mgr_update
            ${INSTALL_CMD} -y install --no-install-recommends "$@"
        fi
    elif [ ${INSTALL_CMD} = "apk" ]; then
        ${INSTALL_CMD} add \
            --no-cache \
            "$@"
    else
        echo "Linux distro ${ID} not supported."
        exit 1
    fi
}

clean_up() {
    case $ADJUSTED_ID in
        debian)
            rm -rf /var/lib/apt/lists/*
            ;;
        alpine)
            rm -rf /var/cache/apk/*
            ;;
    esac
}

install_dependencies() {
    echo "Installing dependencies for ${ADJUSTED_ID}..."

    check_packages curl jq ca-certificates
}

install_prek() {
    echo "Installing prek..."

    # Check if PREK_VERSION is set, otherwise exit
    if [[ -z "${PREK_VERSION}" ]]; then
        echo "Error: PREK_VERSION is not set. Please provide the version as a feature variable."
        exit 1
    fi

    if [[ "${PREK_VERSION}" = "latest" ]]; then
        PREK_VERSION=$(\
        curl -Lf -H "Accept: application/vnd.github+json"  "https://api.github.com/repos/j178/prek/releases?per_page=1" | jq -r '.[0].tag_name'\
        )
    fi 

    local SDK_URL="https://github.com/j178/prek/releases/download/${PREK_VERSION}/prek-installer.sh"
    export PREK_INSTALL_DIR=/usr/bin 

    curl --proto '=https' --tlsv1.2 -LsSfo prek-installer.sh ${SDK_URL}  || { echo "Error: Failed to get prek installer."; exit 1; }
    sh prek-installer.sh || { echo "Error: Failed to install prek."; exit 1; }

    rm prek-installer.sh
}

main() {
    echo "Starting prek installation process..."
    pkg_mgr_update
    install_dependencies
    install_prek

    echo "prek installation process completed successfully."
    clean_up
}

main