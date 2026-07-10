#!/bin/bash
# WhiteBlossom OS Cloud — Cluster Configuration
# Creates systemd units for first-boot cluster join.
# Each unit is idempotent and handles one concern.

set -ouex pipefail

echo "Configuring cluster units..."

# --- Multi-user target (no desktop) ---
systemctl set-default multi-user.target
systemctl enable sshd.service
systemctl enable NetworkManager.service
systemctl enable zerotier-one.service

# --- wb-register.service ---
# Runs registration client on first boot to obtain cluster secrets.
cat > /etc/systemd/system/wb-register.service <<'EOF'
[Unit]
Description=WhiteBlossom Node Registration
After=network-online.target zerotier-one.service
Wants=network-online.target
ConditionPathExists=!/etc/whiteblossom/.registered

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/wb-register
StandardOutput=journal
StandardError=journal
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF

# --- k3s-config.service ---
# Writes /etc/rancher/k3s/config.yaml from registration response.
# Runs after wb-register, before k3s-agent.
cat > /etc/systemd/system/k3s-config.service <<'EOF'
[Unit]
Description=Write k3s Agent Config
After=wb-register.service
Requires=wb-register.service
ConditionPathExists=/etc/whiteblossom/.registered
ConditionPathExists=!/etc/rancher/k3s/config.yaml

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/k3s-config-write
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# --- k3s-agent.service override ---
# Ensure k3s agent starts after config is written.
# k3s install creates its own service; we add a drop-in for ordering.
mkdir -p /etc/systemd/system/k3s-agent.service.d
cat > /etc/systemd/system/k3s-agent.service.d/override.conf <<'EOF'
[Unit]
After=k3s-config.service
Requires=k3s-config.service
ConditionPathExists=/etc/rancher/k3s/config.yaml
EOF

# --- Enable first-boot units ---
systemctl enable wb-register.service
systemctl enable k3s-config.service

echo "✓ Cluster configuration complete"
