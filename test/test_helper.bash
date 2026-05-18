#!/usr/bin/env bash
# test/test_helper.bash — shared setup and command mocks for easy-proxy bats tests.
#
# Each test runs against an isolated copy of the CLI built under the per-test
# temp dir, so nothing touches the real repo. MOCK_BIN is prepended to PATH so
# command mocks (docker, pass) take precedence over host binaries.

# Project root — test/ lives directly under it.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Build the isolated CLI copy and export the environment `easy` expects.
easy_setup() {
  EASY_CLI_DIR="$BATS_TEST_TMPDIR/cli"
  mkdir -p "$EASY_CLI_DIR/commands"
  cp "$PROJECT_ROOT/easy"              "$EASY_CLI_DIR/easy"
  cp "$PROJECT_ROOT/package.json"      "$EASY_CLI_DIR/package.json"
  cp "$PROJECT_ROOT/commands/proxy.sh" "$EASY_CLI_DIR/commands/proxy.sh"
  cp -R "$PROJECT_ROOT/easyhome"       "$EASY_CLI_DIR/easyhome"
  chmod +x "$EASY_CLI_DIR/easy"

  export EASY_LETSENCRYPT_DIR="$BATS_TEST_TMPDIR/letsencrypt"
  export EASY_DOMAINS_DIR="$BATS_TEST_TMPDIR/domains"
  mkdir -p "$EASY_LETSENCRYPT_DIR" "$EASY_DOMAINS_DIR"

  MOCK_BIN="$BATS_TEST_TMPDIR/mockbin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$EASY_CLI_DIR:$PATH"

  # Deterministic: never inherit real credentials/config from the host shell.
  unset IONOS_API_KEY IONOS_API_SECRET EASY_LETSENCRYPT_EMAIL EASY_LETSENCRYPT_DOMAIN
}

# Mock `docker` so `docker ps` reports a fake running easy-proxy container.
# Every other docker subcommand is a no-op — tests never reach real Docker.
mock_docker_running() {
  cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  ps) echo "deadbeefcafe1234" ;;
  *)  exit 0 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/docker"
}

# Mock `pass` so credential lookups always miss (no stored secrets).
mock_pass_empty() {
  printf '#!/usr/bin/env bash\nexit 1\n' > "$MOCK_BIN/pass"
  chmod +x "$MOCK_BIN/pass"
}

# Mock `docker` with no easy-proxy container present: `ps` finds nothing and
# every subcommand is a no-op success. Keeps tests hermetic — no real Docker.
mock_docker_stopped() {
  printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/docker"
  chmod +x "$MOCK_BIN/docker"
}

# Mock `docker`: the proxy is running, but `docker exec` (e.g. `nginx -t`) fails.
mock_docker_nginx_invalid() {
  cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  ps)   echo "deadbeefcafe1234" ;;
  exec) exit 1 ;;
  *)    exit 0 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/docker"
}
