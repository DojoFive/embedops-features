#!/usr/bin/env bash

#!/usr/bin/env bash
set -uxvT -o pipefail
set -e

. /etc/os-release

# Determine base Linux distribution
if [[ "${ID}" != "debian" && ! "${ID_LIKE}" =~ "debian" ]]; then
    echo "Error: Unsupported Linux distribution '${ID}'."
    exit 1
fi

pkg_mgr_update() {
    apt-get update -y
}


verify_architecture() {
    if [[ "$(uname -m)" != "x86_64" ]]; then
        echo "Error: Unsupported architecture '$(uname -m)'. Stz Secure is only available for x86_64."
        exit 1
    fi
}

check_packages() {
    apt-get install -y --no-install-recommends "$@"
}

install_dependencies() {
    check_packages libusb-1.0-0 wget ca-certificates gettext texinfo cpio git openssh-client
    wget --progress=dot:giga https://github.com/mikefarah/yq/releases/download/v"${YQ_VERSION}"/yq_linux_amd64.tar.gz -O - |\
                tar xz && mv yq_linux_amd64 /usr/bin/yq
    cat << 'EOF' > /etc/profile.d/devcontainer-feature-stz-secure.sh
#!/usr/bin/env bash
export BYPASS_CONTEXT_UPGRADE="y"
export PATH="/opt/iarsystems/secure-application-maker-tool/bin/:$PATH"

run_stz_secure() {
  get_iar_config_path () {
      EO_CONFIG_ROOT=.embedops
      IAR_CONFIG_PATH=${EO_CONFIG_ROOT}/iar/config.yml
      IAR_ENVSUBST_CONFIG_PATH=${EO_CONFIG_ROOT}/iar/envsubst.config.yml
      if [[ -f ${IAR_CONFIG_PATH} ]]
      then
          envsubst < ${IAR_CONFIG_PATH} > ${IAR_ENVSUBST_CONFIG_PATH}
          echo ${IAR_ENVSUBST_CONFIG_PATH}
      else
          echo "[INFO] file not found: ${EO_CONFIG_ROOT}/iar/config.yml"
          exit 1
      fi
  }

  if ! IAR_CONFIG_PATH=$(get_iar_config_path); then
      echo "[ERROR] ${EO_CONFIG_ROOT}/iar/config.yml required"
      exit 1
  fi
  (
      if [ "$( yq .IAR_PROTECT  "$IAR_CONFIG_PATH")" == "null" ]; then
          echo "[ERROR] Bad configuration: IAR_PROTECT array is required"
          exit 1
      fi
      ARTIFACTS_DIR=$(echo artifacts/$EMBEDOPS_JOB_NAME)
      if [ ! -d "$ARTIFACTS_DIR" ]; then
          echo "[ERROR] No IAR artifacts directory found"
          exit 1
      fi
      set -u -e -o pipefail
      export EMBEDOPS_INPUT_FILE=build.log
      : >$EMBEDOPS_INPUT_FILE
      readarray iarProtectMappings < <(yq -o=j -I=0 '.IAR_PROTECT[]' "$IAR_CONFIG_PATH" )
      for iarProtectMapping in "${iarProtectMappings[@]}"; do
          args=(
              "CONFIG"
              "UNMASTERED_IMAGE_INPUT_SREC_FILE_PATH"
              "MASTERED_IMAGE_OUTPUT_SREC_FILE_PATH"
              "STZSTEF_OUTPUT_BINARY_FILE_PATH"
              "DIEI_OUTPUT_BINARY_FILE_PATH"
              "VERSION"
          )
          for arg in "${args[@]}"
          do
              value=$(echo "$iarProtectMapping" | yq '.'"$arg" -)

              if [[ "$value" == "null" && ( "$arg" == "CONFIG" || "$arg" == "UNMASTERED_IMAGE_INPUT_SREC_FILE_PATH" ) ]]; then
                  echo "[ERROR] Bad configuration: IAR_PROTECT must contain the field $arg"
                  exit 1
              fi
              if [ "$value" != "null" ]; then
                  export "$arg=$value"
              fi
          done
          if ! { [ -v MASTERED_IMAGE_OUTPUT_SREC_FILE_PATH ] || [ -v STZSTEF_OUTPUT_BINARY_FILE_PATH ] || [ -v DIEI_OUTPUT_BINARY_FILE_PATH ];}; then
              echo "[ERROR] Bad configuration: IAR_PROTECT needs MASTERED_IMAGE_OUTPUT_SREC_FILE_PATH, STZSTEF_OUTPUT_BINARY_FILE_PATH, or DIEI_OUTPUT_BINARY_FILE_PATH"
              exit 1
          fi
          OPTIONAL_ARGS=""
          if [ -v MASTERED_IMAGE_OUTPUT_SREC_FILE_PATH ]; then
              OPTIONAL_ARGS="--output-swup $ARTIFACTS_DIR/$MASTERED_IMAGE_OUTPUT_SREC_FILE_PATH"
          fi
          if [ -v STZSTEF_OUTPUT_BINARY_FILE_PATH ]; then
              OPTIONAL_ARGS="$OPTIONAL_ARGS --output-stztef $ARTIFACTS_DIR/$STZSTEF_OUTPUT_BINARY_FILE_PATH"
          fi
          if [ -v DIEI_OUTPUT_BINARY_FILE_PATH ]; then
              OPTIONAL_ARGS="$OPTIONAL_ARGS --output-bypass $ARTIFACTS_DIR/$DIEI_OUTPUT_BINARY_FILE_PATH"
          fi
          if [ -v VERSION ]; then
              OPTIONAL_ARGS="$OPTIONAL_ARGS --version $VERSION"
          fi
          ( stz_secure_app protect --config "$CONFIG" --logfile /tmp/logfile --input "$ARTIFACTS_DIR"/"$UNMASTERED_IMAGE_INPUT_SREC_FILE_PATH" $OPTIONAL_ARGS 2>&1 | tee -a "$EMBEDOPS_INPUT_FILE" ) && cat /tmp/logfile && rm /tmp/logfile
      done
  )
}
EOF
    EMBEDOPS_JOB_NAME="${EMBEDOPS_JOB_NAME:-iar}"
    echo "export STZ_SECURE_DEB_PATH=\"${STZ_SECURE_DEB_PATH}\"" >> /etc/profile.d/devcontainer-feature-stz-secure.sh
    echo "export EMBEDOPS_JOB_NAME=\"${EMBEDOPS_JOB_NAME}\"" >> /etc/profile.d/devcontainer-feature-stz-secure.sh
    echo "source /etc/profile.d/devcontainer-feature-stz-secure.sh" >> /etc/bash.bashrc
    chmod +x /etc/profile.d/devcontainer-feature-stz-secure.sh

    cat << 'EOF' > /usr/local/bin/run_stz_secure
#!/usr/bin/env bash
source /etc/profile.d/devcontainer-feature-stz-secure.sh
run_stz_secure
EOF

    chmod +x /usr/local/bin/run_stz_secure

}

clean() {
  apt-get clean
  rm -rf /var/lib/apt/lists/*
}

main() {
    echo "Starting Stz Secure installation process..."
    verify_architecture
    pkg_mgr_update
    install_dependencies
    clean
    install -m 755 stz-secure-setup.sh /usr/local/bin
    echo "Stz Secure installation process completed successfully"
}

main "$@"