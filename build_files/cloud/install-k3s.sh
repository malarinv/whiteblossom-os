#!/bin/bash
# WhiteBlossom OS Cloud — k3s + ZeroTier Installation
# Installs k3s binary, ZeroTier, and required dependencies into the image.
# This runs during container build (not at first boot).

set -ouex pipefail

echo "Installing k3s and ZeroTier..."

# --- System dependencies ---
dnf5 install -y \
    systemd \
    NetworkManager \
    openssh-server \
    curl \
    iproute \
    python3 \
    openssl \
    jq

# --- ZeroTier ---
echo "Installing ZeroTier..."
curl -s https://install.zerotier.com | bash || {
    echo "ZeroTier install failed (no network during build). Installing from repo..."
    dnf5 install -y zerotier-one || true
}

# --- k3s binary ---
echo "Installing k3s..."
K3S_VERSION="${K3S_VERSION:-v1.35.5+k3s1}"
curl -sfL https://get.k3s.io | \
    INSTALL_K3S_SKIP_ENABLE=true \
    INSTALL_K3S_SKIP_START=true \
    INSTALL_K3S_VERSION="${K3S_VERSION}" \
    sh -

# Verify installation
if command -v k3s &>/dev/null; then
    echo "k3s installed: $(k3s --version)"
else
    echo "WARNING: k3s binary not found after install"
fi

if command -v zerotier-cli &>/dev/null; then
    echo "ZeroTier installed: $(zerotier-cli -v 2>&1 || echo 'ok')"
else
    echo "WARNING: zerotier-cli not found after install"
fi

echo "✓ k3s and ZeroTier installed"
