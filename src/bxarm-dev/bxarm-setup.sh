if [ -f /etc/profile.d/devcontainer-feature-bxarm.sh ]; then
    source /etc/profile.d/devcontainer-feature-bxarm.sh
fi

fatal() {
    error() {
        local input="$*"
        # color: red
        echo -e "\033[31m[ERROR] $input\033[0m"
    }

    local input="$*"
    error "${input}"
    exit 1
}

install_bxarm() {
  if [[ -z "$BXARM_DEB_PATH" ]]; then
    fatal "BXARM_DEB_PATH is unset or empty. Please verify your configuration and try again."
  fi

  echo "$BXARM_DEB_PATH"
  apt-get install -y --no-install-recommends "$BXARM_DEB_PATH"
  export PATH="$PATH:/opt/iarsystems/bxarm/common/bin/:/opt/iarsystems/bxarm/arm/bin/"
}

main() {
    echo "Starting BXARM setup process..."
    install_bxarm
    echo "BXARM setup process completed successfully. You can run 'build_with_bxarm' manually now."
}

main "$@"