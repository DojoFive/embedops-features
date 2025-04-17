if [ -f /etc/profile.d/devcontainer-feature-stz-secure.sh ]; then
    source /etc/profile.d/devcontainer-feature-stz-secure.sh
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

install_stz_secure() {
  if [[ -z "$STZ_SECURE_DEB_PATH" ]]; then
    fatal "STZ_SECURE_DEB_PATH is unset or empty. Please verify your configuration and try again."
  fi

  echo "$STZ_SECURE_DEB_PATH"
  export BYPASS_CONTEXT_UPGRADE="y"
  apt-get install -y --no-install-recommends "$STZ_SECURE_DEB_PATH"
  export PATH="/opt/iarsystems/secure-application-maker-tool/bin/:$PATH"
}

main() {
  echo "Starting Stz Secure setup..."
  install_stz_secure
  echo "Stz Secure setup completed successfully. You can run 'run_stz_secure' manually now."
}

main "$@"