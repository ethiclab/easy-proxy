#!/usr/bin/env bats
# Tests for easyhome/skeleton.js — the zero-dependency nginx template renderer.

load test_helper

setup() {
  easy_setup
  SKELETON="$EASY_CLI_DIR/easyhome/skeleton.js"
  TEMPLATE="$BATS_TEST_TMPDIR/sample.conf"
  cat > "$TEMPLATE" <<'EOF'
server_name $server_name;
domain ${domain};
location $location_path { proxy_pass $location_target; }
set \$upstream backend;
EOF
}

@test "skeleton.js fails without a -t template argument" {
  run node "$SKELETON"
  [ "$status" -eq 1 ]
  [[ "$output" == *"-t <template-file> required"* ]]
}

@test "skeleton.js fails when the template file does not exist" {
  run node "$SKELETON" -t /no/such/template.conf
  [ "$status" -eq 1 ]
  [[ "$output" == *"template file not found"* ]]
}

@test "skeleton.js substitutes both \$var and \${var} placeholders" {
  run node "$SKELETON" -t "$TEMPLATE" \
    --server_name app.example.com --domain example.com \
    --location_target http://host:8010
  [ "$status" -eq 0 ]
  [[ "$output" == *"server_name app.example.com;"* ]]
  [[ "$output" == *"domain example.com;"* ]]
  [[ "$output" == *"proxy_pass http://host:8010;"* ]]
}

@test "skeleton.js unescapes a backslash-dollar to a literal dollar sign" {
  run node "$SKELETON" -t "$TEMPLATE" --server_name x --domain y --location_target z
  [ "$status" -eq 0 ]
  [[ "$output" == *'set $upstream backend;'* ]]
  [[ "$output" != *'\$upstream'* ]]
}

@test "skeleton.js defaults location_path to /" {
  run node "$SKELETON" -t "$TEMPLATE" --server_name x --domain y --location_target z
  [ "$status" -eq 0 ]
  [[ "$output" == *"location / {"* ]]
}
