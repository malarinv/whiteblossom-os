#!/usr/bin/env bats

# Test suite for mise tasks
# Verifies task definitions, SSH key injection, and error handling

setup() {
  # Load the mise.toml for parsing
  MISE_TOML="mise.toml"
}

@test "mise tasks lists all expected tasks" {
  run mise tasks
  [ "$status" -eq 0 ]
  [[ "$output" == *"build:cloud"* ]]
  [[ "$output" == *"disk:cloud"* ]]
  [[ "$output" == *"run:cloud"* ]]
  [[ "$output" == *"ssh:cloud"* ]]
}

@test "run:cloud task includes -fw_cfg flag" {
  grep -q "fw_cfg name=opt/io.systemd.credentials/ssh.authorized_keys.root" "$MISE_TOML"
}

@test "run:cloud task validates SSH key exists" {
  grep -q 'if \[ ! -f "\$HOME/.ssh/wb-dev.pub" \]' "$MISE_TOML"
}

@test "ssh:cloud task includes -i flag for key file" {
  grep -q '\-i \$HOME/.ssh/wb-dev ' "$MISE_TOML"
}

@test "run:cloud task validates disk exists" {
  grep -q 'if \[ ! -f output/qcow2/disk.qcow2 \]' "$MISE_TOML"
}

@test "build:cloud task runs just build" {
  grep -q 'just build cloud' "$MISE_TOML"
}

@test "disk:cloud task runs just build-qcow2" {
  grep -q 'just build-qcow2 cloud' "$MISE_TOML"
}

@test "dev-boot:cloud task exists" {
  run mise tasks
  [ "$status" -eq 0 ]
  [[ "$output" == *"dev-boot:cloud"* ]]
}

@test "dev-boot:iot task exists" {
  run mise tasks
  [ "$status" -eq 0 ]
  [[ "$output" == *"dev-boot:iot"* ]]
}

@test "_dev-boot rejects workstation variant" {
  grep -q 'dev-boot only supports cloud and iot' Justfile
}

@test "dev-boot:cloud task runs just _dev-boot" {
  grep -q 'just _dev-boot cloud' "$MISE_TOML"
}

@test "dev-boot:iot task runs just _dev-boot" {
  grep -q 'just _dev-boot iot' "$MISE_TOML"
}
