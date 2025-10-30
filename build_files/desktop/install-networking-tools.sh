#!/usr/bin/bash
# Install Privacy-Focused Networking Tools
# This script removes Tailscale and installs Headscale + ZeroTier
# Provides self-hosted mesh VPN alternatives for privacy-conscious users

set -eoux pipefail

echo "Configuring privacy-focused networking tools..."

# Remove Tailscale (present in Bazzite base)
echo "Removing Tailscale in favor of self-hosted alternatives..."
dnf5 remove -y tailscale || echo "Tailscale not installed, skipping removal"

# Disable Tailscale service if it exists
systemctl disable tailscaled.service || true
systemctl stop tailscaled.service || true

# Add Headscale COPR repository
echo "Adding Headscale COPR repository..."
dnf5 copr enable -y jonathanspw/headscale

# Install Headscale
echo "Installing Headscale (self-hosted Tailscale control server)..."
dnf5 install -y headscale

# Create Headscale configuration directory
mkdir -p /etc/headscale

# Add example Headscale configuration
cat > /etc/headscale/config.yaml << 'EOF'
# Headscale Configuration Example
# Edit this file to configure your self-hosted Tailscale control server
# Documentation: https://github.com/juanfont/headscale

server_url: http://127.0.0.1:8080
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090

# Disable gRPC socket by default (can enable if needed)
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false

# Privacy-focused: Use private DNS
private_key_path: /var/lib/headscale/private.key
noise:
  private_key_path: /var/lib/headscale/noise_private.key

# IP prefix for the Headscale network
ip_prefixes:
  - fd7a:115c:a1e0::/48
  - 100.64.0.0/10

# Database configuration (SQLite by default)
db_type: sqlite3
db_path: /var/lib/headscale/db.sqlite

# DERP server configuration (for NAT traversal)
derp:
  server:
    enabled: false
  urls: []
  paths: []
  auto_update_enabled: true
  update_frequency: 24h

# Ephemeral nodes
ephemeral_node_inactivity_timeout: 30m

# DNS configuration
dns_config:
  override_local_dns: true
  nameservers:
    - 1.1.1.1
  domains: []
  magic_dns: true
  base_domain: example.com

# Logging
log_level: info

# Disable by default, users will enable when ready to use
EOF

# Set proper permissions on Headscale config
chmod 644 /etc/headscale/config.yaml

# Create Headscale data directory
mkdir -p /var/lib/headscale

# Disable Headscale service by default (user will enable when ready)
systemctl disable headscale.service || true

echo "Headscale installed and configured. Service is disabled by default."
echo "To use Headscale, users should:"
echo "  1. Edit /etc/headscale/config.yaml with their settings"
echo "  2. Run: sudo systemctl enable --now headscale.service"
echo "  3. Configure Tailscale clients to use their Headscale server"

# Disable Headscale COPR to avoid it being enabled in final image
dnf5 copr disable -y jonathanspw/headscale

# Install ZeroTier-One from RPMFusion Non-Free
# Reference: https://rpmfind.net/linux/rpm2html/search.php?query=zerotier-one
echo "Installing ZeroTier-One from RPMFusion Non-Free..."
dnf5 install -y --enablerepo=rpmfusion-nonfree zerotier-one

# Disable ZeroTier service by default (user will enable when ready)
systemctl disable zerotier-one.service || true

echo "ZeroTier-One installed. Service is disabled by default."
echo "To use ZeroTier, users should:"
echo "  1. Run: sudo systemctl enable --now zerotier-one.service"
echo "  2. Join a network: sudo zerotier-cli join <network-id>"

# Add documentation file
mkdir -p /usr/share/doc/whiteblossom-os
cat > /usr/share/doc/whiteblossom-os/mesh-vpn-guide.md << 'EOF'
# WhiteBlossom OS Mesh VPN Guide

WhiteBlossom OS provides two privacy-focused mesh VPN solutions:

## Headscale (Self-Hosted Tailscale Alternative)

Headscale is an open-source, self-hosted implementation of the Tailscale control server.
It provides the same mesh VPN functionality as Tailscale but with complete control over
your coordination server and data.

### Benefits:
- Full control over coordination server
- No dependency on commercial Tailscale servers
- Compatible with Tailscale clients
- Privacy-focused: your network data stays with you

### Setup:
1. Edit `/etc/headscale/config.yaml` with your settings
2. Enable service: `sudo systemctl enable --now headscale.service`
3. Configure Tailscale clients to point to your Headscale server
4. Documentation: https://github.com/juanfont/headscale

## ZeroTier

ZeroTier is a decentralized mesh VPN with optional self-hosted network controllers.
Installed from RPMFusion Non-Free repository.

### Benefits:
- Decentralized architecture
- Can self-host network controller for privacy
- Different VPN paradigm than Tailscale/Headscale
- Good for hybrid cloud/on-premise scenarios

### Setup:
1. Enable service: `sudo systemctl enable --now zerotier-one.service`
2. Join network: `sudo zerotier-cli join <network-id>`
3. Optionally self-host controller: https://docs.zerotier.com/self-hosting/network-controllers

## Why Not Tailscale?

WhiteBlossom OS prioritizes privacy and self-hosting. Tailscale's commercial
coordination servers see metadata about your network topology. Headscale provides
the same functionality with complete self-hosting.

## Choosing Between Headscale and ZeroTier

- **Choose Headscale if**: You're familiar with Tailscale, want drop-in replacement
- **Choose ZeroTier if**: You prefer different architecture, need hybrid cloud
- **Use both**: They can coexist peacefully if you need both paradigms
EOF

echo "Networking tools configuration complete!"
echo "Documentation available at: /usr/share/doc/whiteblossom-os/mesh-vpn-guide.md"

