#!/usr/bin/env bats
# Tests for `easy proxy recover` — break-glass network recovery.

load test_helper

setup() { easy_setup; }

@test "easy proxy help lists recover" {
  run easy proxy help
  [ "$status" -eq 0 ]
  [[ "$output" == *"easy proxy recover"* ]]
}

@test "easy proxy recover fails when there is no proxy container" {
  mock_docker_stopped
  run easy proxy recover
  [ "$status" -ne 0 ]
}

@test "easy proxy recover reports when no backends are found" {
  mock_docker_topology
  run easy proxy recover
  [ "$status" -ne 0 ]
  [[ "$output" == *"no backend"* ]]
}

@test "easy proxy recover detects the edge network and connects the proxy" {
  mock_docker_topology
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export DOCKER_TOPOLOGY="$BATS_TEST_TMPDIR/topology"
  printf 'wp ethicnet\napi ethicnet\nlegacy oldnet\n' > "$DOCKER_TOPOLOGY"
  mkdir -p "$EASY_DOMAINS_DIR/site-a" "$EASY_DOMAINS_DIR/site-b"
  echo 'upstream a { server wp; }' > "$EASY_DOMAINS_DIR/site-a/app.conf"
  echo 'upstream b { server api; }' > "$EASY_DOMAINS_DIR/site-a/api.conf"
  echo 'upstream c { server legacy; }' > "$EASY_DOMAINS_DIR/site-b/legacy.conf"
  run easy proxy recover
  [[ "$output" == *"ethicnet"* ]]
  grep -q "network connect ethicnet easy-proxy" "$DOCKER_LOG"
  grep -q "network connect oldnet easy-proxy" "$DOCKER_LOG"
}

@test "easy proxy recover --consolidate attaches backends to the edge network" {
  mock_docker_topology
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export DOCKER_TOPOLOGY="$BATS_TEST_TMPDIR/topology"
  export EASY_PROXY_NETWORK=ethicnet
  printf 'wp ethicnet\nlegacy oldnet\n' > "$DOCKER_TOPOLOGY"
  mkdir -p "$EASY_DOMAINS_DIR/s"
  echo 'upstream a { server wp; }' > "$EASY_DOMAINS_DIR/s/a.conf"
  echo 'upstream c { server legacy; }' > "$EASY_DOMAINS_DIR/s/c.conf"
  run easy proxy recover --consolidate
  [ "$status" -eq 0 ]
  grep -q "network connect ethicnet legacy" "$DOCKER_LOG"
}
