#!/usr/bin/env bash
set -e

YOCTO_SDK_TAR_FILE=${YOCTO_SDK_TAR_FILE:-"./yocto-standard-sdk.tar.gz"}
YOCTO_SDK_DIR=${YOCTO_SDK_DIR:-"$PWD"}
YOCTO_SDK_SUBDIR="yocto-standard-sdk"
YOCTO_SDK_ENV_DIR="${YOCTO_SDK_DIR}/${YOCTO_SDK_SUBDIR}"

checksum_file="${YOCTO_SDK_DIR}/.yocto_sdk_extracted"

run_yocto_setup() {
    if [ "$(id -u)" -ne 0 ]; then
        exec sudo yocto-setup.sh
    else
        exec yocto-setup.sh
    fi
}

if [ ! -d "$YOCTO_SDK_ENV_DIR" ]; then
    rm -f $checksum_file
    run_yocto_setup
fi

if [ -f "$checksum_file" ]; then
    old_checksum=$(cat "$checksum_file")
    current_checksum=$(sha256sum "${YOCTO_SDK_TAR_FILE}" | awk '{print $1}')
    if [ "$current_checksum" = "$old_checksum" ]; then
        echo "Tarball hasn't changed. Skipping re-extraction."
        exit 0
    else
        echo "Tarball has changed. Removing old directory and re-extracting."
        if [ "$(id -u)" -ne 0 ]; then
            sudo rm -rf "$checksum_file" "$YOCTO_SDK_ENV_DIR"
        else
            rm -rf "$checksum_file" "$YOCTO_SDK_ENV_DIR"
        fi
        run_yocto_setup
    fi
fi