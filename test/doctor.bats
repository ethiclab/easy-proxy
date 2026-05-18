#!/usr/bin/env bats
# Tests for `easy proxy doctor` — the read-only pre-flight diagnostic.

load test_helper

setup() { easy_setup; }

@test "easy proxy help lists the doctor command" {
  run easy proxy help
  [ "$status" -eq 0 ]
  [[ "$output" == *"easy proxy doctor"* ]]
}

@test "easy proxy doctor reports no vhost files on a clean setup" {
  mock_docker_stopped
  run easy proxy doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"no vhost files"* ]]
}

@test "easy proxy doctor flags a static upstream block" {
  mock_docker_stopped
  mkdir -p "$EASY_DOMAINS_DIR/legacy.example.com"
  cat > "$EASY_DOMAINS_DIR/legacy.example.com/site.conf" <<'CONF'
upstream backend { server some_container; }
server { listen 80; location / { proxy_pass http://backend; } }
CONF
  run easy proxy doctor
  [[ "$output" == *"site.conf"* ]]
  [[ "$output" == *"upstream"* ]]
  [[ "$output" == *"1 warning"* ]]
}

@test "easy proxy doctor flags a deprecated listen ... http2 directive" {
  mock_docker_stopped
  mkdir -p "$EASY_DOMAINS_DIR/old.example.com"
  echo 'server { listen 443 ssl http2; }' > "$EASY_DOMAINS_DIR/old.example.com/site.conf"
  run easy proxy doctor
  [[ "$output" == *"http2"* ]]
}

@test "easy proxy doctor reports zero warnings for a template-style vhost" {
  mock_docker_stopped
  mkdir -p "$EASY_DOMAINS_DIR/good.example.com"
  cat > "$EASY_DOMAINS_DIR/good.example.com/site.conf" <<'CONF'
server { listen 80; location / { set $u http://app:8080; proxy_pass $u; } }
CONF
  run easy proxy doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 warning(s)"* ]]
}

@test "easy proxy doctor runs the nginx config test when the proxy is running" {
  mock_docker_running
  run easy proxy doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "easy proxy doctor exits non-zero when the nginx config test fails" {
  mock_docker_nginx_invalid
  run easy proxy doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL"* ]]
}
