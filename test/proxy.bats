#!/usr/bin/env bats
# Tests for `easy proxy` subcommand routing and error paths.
# Docker- and credential-dependent paths use the mocks from test_helper.bash.

load test_helper

setup() { easy_setup; }

@test "easy proxy with no subcommand prints usage and fails" {
  run easy proxy
  [ "$status" -eq 1 ]
  [[ "$output" == *"easy proxy create"* ]]
}

@test "easy proxy help prints the command list" {
  run easy proxy help
  [ "$status" -eq 0 ]
  [[ "$output" == *"easy proxy certbot-ionos <domain>"* ]]
}

@test "easy proxy help works without the runtime env vars set" {
  unset EASY_LETSENCRYPT_DIR EASY_DOMAINS_DIR
  run easy proxy help
  [ "$status" -eq 0 ]
  [[ "$output" == *"easy proxy create"* ]]
}

@test "easy proxy with an unknown subcommand prints usage and fails" {
  run easy proxy not-a-real-subcommand
  [ "$status" -eq 1 ]
  [[ "$output" == *"easy proxy create"* ]]
}

@test "easy proxy rfc2136 without an email reports the missing variable" {
  run easy proxy rfc2136
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid Email"* ]]
}

@test "easy proxy status reports the running container" {
  mock_docker_running
  run easy proxy status
  [ "$status" -eq 0 ]
  [ "$output" = "deadbeefcafe1234" ]
}

@test "easy proxy status is empty when no container is running" {
  mock_docker_stopped
  run easy proxy status
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "easy proxy create refuses when an instance already exists" {
  mock_docker_running
  run easy proxy create
  [ "$status" -eq 1 ]
  [[ "$output" == *"already an easy proxy instance"* ]]
}

@test "easy proxy create writes no state file into the install dir (#5)" {
  mock_docker_lifecycle
  export DOCKER_PROXY_HEALTHY=1
  chmod -w "$EASY_CLI_DIR"
  run easy proxy create
  chmod +w "$EASY_CLI_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Permission denied"* ]]
  [ ! -e "$EASY_CLI_DIR/.id" ]
}

@test "easy proxy certbot-ionos reports when the proxy is not running" {
  mock_docker_stopped
  run easy proxy certbot-ionos
  [ "$status" -eq 1 ]
  [[ "$output" == *"Proxy is not running"* ]]
}

@test "easy proxy certbot-ionos requires a domain when the proxy is running" {
  mock_docker_running
  export EASY_LETSENCRYPT_EMAIL="test@example.com"
  run easy proxy certbot-ionos
  [ "$status" -eq 1 ]
  [[ "$output" == *"Domain required"* ]]
}

@test "easy proxy certbot-ionos reports missing IONOS credentials" {
  mock_docker_running
  mock_pass_empty
  export EASY_LETSENCRYPT_EMAIL="test@example.com"
  run easy proxy certbot-ionos example.com
  [ "$status" -eq 1 ]
  [[ "$output" == *"IONOS API credentials not found"* ]]
}
