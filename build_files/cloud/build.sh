#!/bin/bash

# WhiteBlossom OS Cloud Build Script
# Cluster node build with k3s, ZeroTier, and registration client.
# Shared setup is handled by shared/build.sh — run that first.

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
# STEP 1: Install k3s, ZeroTier, and Dependencies
# ============================================================================

echo "Installing k3s, ZeroTier, and dependencies..."
bash "${SCRIPT_DIR}/install-k3s.sh"

echo ""
echo "✓ Packages installed"
echo ""

# ============================================================================
# STEP 2: Configure Cluster Systemd Units
# ============================================================================

echo "Configuring cluster systemd units..."
bash "${SCRIPT_DIR}/configure-cluster.sh"

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
