#!/usr/bin/env bats
# Tests for `easy proxy verify` and the auto-verify wired into `easy proxy create`.

load test_helper

setup() { easy_setup; }

@test "easy proxy help lists verify" {
  run easy proxy help
  [ "$status" -eq 0 ]
  [[ "$output" == *"easy proxy verify"* ]]
}

@test "easy proxy verify exits 0 when the proxy is running" {
  mock_docker_running
  run easy proxy verify
  [ "$status" -eq 0 ]
  [[ "$output" == *"running"* ]]
}

@test "easy proxy verify fails when there is no proxy container" {
  mock_docker_stopped
  run easy proxy verify
  [ "$status" -ne 0 ]
  [[ "$output" == *"NOT running"* ]]
}

@test "easy proxy verify surfaces the startup error when the container has exited" {
  mock_docker_lifecycle      # DOCKER_PROXY_HEALTHY unset → container not running
  touch "$DOCKER_STATE"      # ...but a container exists
  run easy proxy verify
  [ "$status" -ne 0 ]
  [[ "$output" == *"emerg"* ]]
}

@test "easy proxy create auto-verifies a healthy proxy" {
  mock_docker_lifecycle
  export DOCKER_PROXY_HEALTHY=1
  run easy proxy create
  [ "$status" -eq 0 ]
  [[ "$output" == *"running"* ]]
}

@test "easy proxy create fails when the proxy crashes on startup" {
  mock_docker_lifecycle      # no DOCKER_PROXY_HEALTHY → nginx 'crashes'
  run easy proxy create
  [ "$status" -ne 0 ]
  [[ "$output" == *"emerg"* ]]
}
