#!/usr/bin/env bats
# Tests for `easy proxy` edge-network management — EASY_PROXY_NETWORK,
# attach/detach, and the proxy network audit/prune.

load test_helper

setup() { easy_setup; }

@test "easy proxy help lists the network commands" {
  run easy proxy help
  [ "$status" -eq 0 ]
  [[ "$output" == *"easy proxy attach"* ]]
  [[ "$output" == *"easy proxy networks"* ]]
}

@test "easy proxy create joins EASY_PROXY_NETWORK and auto-creates it" {
  export EASY_PROXY_NETWORK=ethicnet
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  mock_docker_record
  run easy proxy create
  [ "$status" -eq 0 ]
  grep -q "network create ethicnet" "$DOCKER_LOG"
  grep -q -- "--network ethicnet" "$DOCKER_LOG"
}

@test "easy proxy create stays on the default network when EASY_PROXY_NETWORK is unset" {
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  mock_docker_record
  run easy proxy create
  [ "$status" -eq 0 ]
  ! grep -q -- "--network" "$DOCKER_LOG"
}

@test "easy proxy attach without a container prints usage" {
  mock_docker_stopped
  export EASY_PROXY_NETWORK=ethicnet
  run easy proxy attach
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "easy proxy attach without EASY_PROXY_NETWORK fails" {
  mock_docker_stopped
  run easy proxy attach mysite
  [ "$status" -ne 0 ]
  [[ "$output" == *"EASY_PROXY_NETWORK"* ]]
}

@test "easy proxy attach connects a container to the edge network" {
  export EASY_PROXY_NETWORK=ethicnet
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  mock_docker_record
  run easy proxy attach mysite
  [ "$status" -eq 0 ]
  grep -q "network connect ethicnet mysite" "$DOCKER_LOG"
}

@test "easy proxy detach disconnects a container from the edge network" {
  export EASY_PROXY_NETWORK=ethicnet
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  mock_docker_record
  run easy proxy detach mysite
  [ "$status" -eq 0 ]
  grep -q "network disconnect ethicnet mysite" "$DOCKER_LOG"
}

@test "easy proxy networks lists the proxy networks and flags the extras" {
  export EASY_PROXY_NETWORK=ethicnet
  mock_docker_multinet
  run easy proxy networks
  [ "$status" -eq 0 ]
  [[ "$output" == *"ethicnet"* ]]
  [[ "$output" == *"edge"* ]]
  [[ "$output" == *"extra"* ]]
}

@test "easy proxy networks prune disconnects the proxy from non-edge networks" {
  export EASY_PROXY_NETWORK=ethicnet
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  mock_docker_multinet
  run easy proxy networks prune
  [ "$status" -eq 0 ]
  grep -q "network disconnect bridge easy-proxy" "$DOCKER_LOG"
  grep -q "network disconnect legacynet easy-proxy" "$DOCKER_LOG"
  ! grep -q "network disconnect ethicnet" "$DOCKER_LOG"
}
