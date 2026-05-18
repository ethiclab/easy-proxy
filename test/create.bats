#!/usr/bin/env bats
# Tests for `easy proxy create` configuration knobs.

load test_helper

setup() { easy_setup; }

@test "easy proxy create passes EASY_PROXY_DOCKER_RUN_OPTS to docker run" {
  export EASY_PROXY_DOCKER_RUN_OPTS="-p 8089:8089"
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export DOCKER_PROXY_HEALTHY=1
  mock_docker_lifecycle
  run easy proxy create
  [ "$status" -eq 0 ]
  grep -q -- "-p 8089:8089" "$DOCKER_LOG"
}

@test "easy proxy create passes multiple EASY_PROXY_DOCKER_RUN_OPTS tokens" {
  export EASY_PROXY_DOCKER_RUN_OPTS="-p 8089:8089 --memory 512m"
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export DOCKER_PROXY_HEALTHY=1
  mock_docker_lifecycle
  run easy proxy create
  [ "$status" -eq 0 ]
  grep -q -- "-p 8089:8089" "$DOCKER_LOG"
  grep -q -- "--memory 512m" "$DOCKER_LOG"
}

@test "easy proxy create works with EASY_PROXY_DOCKER_RUN_OPTS unset" {
  export DOCKER_LOG="$BATS_TEST_TMPDIR/docker.log"
  export DOCKER_PROXY_HEALTHY=1
  mock_docker_lifecycle
  run easy proxy create
  [ "$status" -eq 0 ]
  grep -q "run -d" "$DOCKER_LOG"
}
