#!/usr/bin/env bats
# Tests for the `easy` dispatcher — top-level command routing.

load test_helper

setup() { easy_setup; }

@test "easy --version prints the package.json version" {
  run easy --version
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "easy --version works without the runtime env vars set" {
  unset EASY_LETSENCRYPT_DIR EASY_DOMAINS_DIR
  run easy --version
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "easy with no command prints usage and fails" {
  run easy
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid command"* ]]
  [[ "$output" == *"Available commands"* ]]
}

@test "easy with an unknown command prints usage and fails" {
  run easy definitely-not-a-command
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid command: definitely-not-a-command"* ]]
}

@test "easy routes a known command to its .sh implementation" {
  run easy proxy help
  [ "$status" -eq 0 ]
  [[ "$output" == *"easy proxy create"* ]]
}
