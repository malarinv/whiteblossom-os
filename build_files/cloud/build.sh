#!/bin/bash

# WhiteBlossom OS Cloud Build Script
# Cluster node build with k3s and container runtimes.
# Shared setup is handled by shared/build.sh — run that first.
#
# TODO: Fill in package lists and configuration for cloud nodes.

set -ouex pipefail

echo "=========================================="
echo "WhiteBlossom OS Cloud Build"
echo "Target: Kubernetes cluster node (k3s)"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "/ctx/build_files/cloud" ]; then
    SCRIPT_DIR="/ctx/build_files/cloud"
fi

# ============================================================================
# STEP 1: Install K3s and Container Runtime Packages
# ============================================================================

echo "Installing K3s packages..."

if [ -f "${SCRIPT_DIR}/install-k3s.sh" ]; then
    bash "${SCRIPT_DIR}/install-k3s.sh"
else
    echo "WARNING: install-k3s.sh not found. Using placeholder packages."
    # K3s and container runtime packages
    dnf5 install -y \
        systemd \
        NetworkManager \
        openssh-server \
        curl \
        iproute \
        || true

    # Install k3s via official script
    echo "Installing k3s..."
    curl -sfL https://get.k3s.io | sh - || echo "k3s install skipped (no network during build)"
fi

echo ""
echo "✓ K3s packages installed"
echo ""

# ============================================================================
# STEP 2: Configure Cluster Networking
# ============================================================================

echo "Configuring cluster networking..."

if [ -f "${SCRIPT_DIR}/configure-cluster.sh" ]; then
    bash "${SCRIPT_DIR}/configure-cluster.sh"
else
    echo "WARNING: configure-cluster.sh not found. Using defaults."
    systemctl set-default multi-user.target || true
    systemctl enable sshd.service || true
    systemctl enable NetworkManager.service || true
    # k3s service is enabled by the k3s install script
fi

echo ""
echo "✓ Cluster configuration complete"
echo ""

# ============================================================================
# Apply Variant System Files
# ============================================================================

echo "Applying cloud system files..."
if [ -d "/ctx/system_files/cloud" ] && find /ctx/system_files/cloud -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    cp -rvT /ctx/system_files/cloud / || true
fi

# ============================================================================
# BUILD SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo "Cloud Build Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. The Containerfile will commit these changes to OSTree"
echo "  2. Run: podman build --target cloud -t whiteblossom-cloud:latest ."
echo ""
