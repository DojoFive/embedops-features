#!/usr/bin/env bash

VERSION_SPECIFIED=${VERSION}

# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release
# Get an adjusted ID independent of distro variants
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [ "${ID}" = "alpine" ]; then
    ADJUSTED_ID="alpine"
elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID}" = "mariner" || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* || "${ID_LIKE}" = *"mariner"* ]]; then
    ADJUSTED_ID="rhel"
    VERSION_CODENAME="${ID}${VERSION_ID}"
else
    echo "Linux distro ${ID} not supported."
    exit 1
fi

if [ "${ADJUSTED_ID}" = "rhel" ] && [ "${VERSION_CODENAME-}" = "centos7" ]; then
    # As of 1 July 2024, mirrorlist.centos.org no longer exists.
    # Update the repo files to reference vault.centos.org.
    sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
    sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
    sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
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

# Clean up
clean_up() {
    case $ADJUSTED_ID in
        debian)
            rm -rf /var/lib/apt/lists/*
            ;;
        alpine)
            rm -rf /var/cache/apk/*
            ;;
        rhel)
            rm -rf /var/cache/dnf/*
            rm -rf /var/cache/yum/*
            ;;
    esac
}
clean_up

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
    elif [ ${INSTALL_CMD} = "dnf" ] || [ ${INSTALL_CMD} = "yum" ]; then
        if [ "$(find /var/cache/${INSTALL_CMD}/* | wc -l)" = "0" ]; then
            echo "Running ${INSTALL_CMD} check-update ..."
            ${INSTALL_CMD} check-update
        fi
    fi
}


# Checks if packages are installed and installs them if not
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
    elif [ ${INSTALL_CMD} = "dnf" ] || [ ${INSTALL_CMD} = "yum" ]; then
        _num_pkgs=$(echo "$@" | tr ' ' \\012 | wc -l)
        _num_installed=$(${INSTALL_CMD} -C list installed "$@" | sed '1,/^Installed/d' | wc -l)
        if [ ${_num_pkgs} != ${_num_installed} ]; then
            pkg_mgr_update
            ${INSTALL_CMD} -y install "$@"
        fi
    elif [ ${INSTALL_CMD} = "microdnf" ]; then
        ${INSTALL_CMD} -y install \
            --refresh \
            --best \
            --nodocs \
            --noplugins \
            --setopt=install_weak_deps=0 \
            "$@"
    else
        echo "Linux distro ${ID} not supported."
        exit 1
    fi
}

export DEBIAN_FRONTEND=noninteractive

if [ "${VERSION_SPECIFIED}" = "latest" ]; then
    check_packages gcc \
    binutils \
    make
else
    echo "At the moment, this feature does not support specifying a version number."
    exit 1
fi

clean_up
exit 0