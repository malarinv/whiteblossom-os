#!/bin/bash

# WhiteBlossom OS IoT Build Script
# Minimal headless build for Raspberry Pi / Rock5B.
# Shared setup is handled by shared/build.sh — run that first.
#
# TODO: Fill in package lists and configuration for IoT use case.

set -ouex pipefail

echo "=========================================="
echo "WhiteBlossom OS IoT Build"
echo "Target: Headless embedded (RPi / Rock5B)"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "/ctx/build_files/iot" ]; then
    SCRIPT_DIR="/ctx/build_files/iot"
fi

# ============================================================================
# STEP 1: Install Minimal Packages
# ============================================================================

echo "Installing minimal IoT packages..."

if [ -f "${SCRIPT_DIR}/install-iot.sh" ]; then
    bash "${SCRIPT_DIR}/install-iot.sh"
else
    echo "WARNING: install-iot.sh not found. Using placeholder packages."
    # Minimal headless packages
    dnf5 install -y \
        systemd \
        NetworkManager \
        openssh-server \
        cockpit || true
fi

echo ""
echo "✓ IoT packages installed"
echo ""

# ============================================================================
# STEP 2: Configure Headless System
# ============================================================================

echo "Configuring headless system..."

if [ -f "${SCRIPT_DIR}/configure-headless.sh" ]; then
    bash "${SCRIPT_DIR}/configure-headless.sh"
else
    echo "WARNING: configure-headless.sh not found. Using defaults."
    # Disable graphical target, enable serial console
    systemctl set-default multi-user.target || true
    systemctl enable sshd.service || true
    systemctl enable NetworkManager.service || true
fi

echo ""
echo "✓ Headless configuration complete"
echo ""

# ============================================================================
# Apply Variant System Files
# ============================================================================

echo "Applying IoT system files..."
if [ -d "/ctx/system_files/iot" ] && find /ctx/system_files/iot -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    cp -rvT /ctx/system_files/iot / || true
fi

# ============================================================================
# BUILD SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo "IoT Build Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. The Containerfile will commit these changes to OSTree"
echo "  2. Run: podman build --target iot -t whiteblossom-iot:latest ."
echo ""
