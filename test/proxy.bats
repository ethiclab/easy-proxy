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

@test "easy proxy certbot-ionos reports when the proxy is not running" {
  run easy proxy certbot-ionos
  [ "$status" -eq 1 ]
  [[ "$output" == *"Proxy is not running"* ]]
}

@test "easy proxy certbot-ionos requires a domain when the proxy is running" {
  mock_docker_running
  mark_proxy_running
  export EASY_LETSENCRYPT_EMAIL="test@example.com"
  run easy proxy certbot-ionos
  [ "$status" -eq 1 ]
  [[ "$output" == *"Domain required"* ]]
}

@test "easy proxy certbot-ionos reports missing IONOS credentials" {
  mock_docker_running
  mock_pass_empty
  mark_proxy_running
  export EASY_LETSENCRYPT_EMAIL="test@example.com"
  run easy proxy certbot-ionos example.com
  [ "$status" -eq 1 ]
  [[ "$output" == *"IONOS API credentials not found"* ]]
}
