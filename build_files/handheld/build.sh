#!/bin/bash

# WhiteBlossom OS Handheld Build Script
# Gaming handheld build with Gamescope and Steam Deck-like configuration.
# Shared setup is handled by shared/build.sh — run that first.
#
# TODO: Fill in package lists and configuration for handheld gaming devices.

set -ouex pipefail

echo "=========================================="
echo "WhiteBlossom OS Handheld Build"
echo "Target: Gaming handheld (Gamescope/Steam)"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "/ctx/build_files/handheld" ]; then
    SCRIPT_DIR="/ctx/build_files/handheld"
fi

# ============================================================================
# STEP 1: Install Gamescope and Gaming Packages
# ============================================================================

echo "Installing handheld gaming packages..."

if [ -f "${SCRIPT_DIR}/install-handheld.sh" ]; then
    bash "${SCRIPT_DIR}/install-handheld.sh"
else
    echo "WARNING: install-handheld.sh not found. Using placeholder packages."
    # Handheld-specific packages
    dnf5 install -y \
        gamescope \
        steam \
        mangohud || true
fi

echo ""
echo "✓ Handheld packages installed"
echo ""

# ============================================================================
# STEP 2: Configure Gamescope
# ============================================================================

echo "Configuring Gamescope and input management..."

if [ -f "${SCRIPT_DIR}/configure-gamescope.sh" ]; then
    bash "${SCRIPT_DIR}/configure-gamescope.sh"
else
    echo "WARNING: configure-gamescope.sh not found. Using defaults."
    systemctl set-default graphical.target || true
    # Gamescope session would be configured here
fi

echo ""
echo "✓ Gamescope configuration complete"
echo ""

# ============================================================================
# Apply Variant System Files
# ============================================================================

echo "Applying handheld system files..."
if [ -d "/ctx/system_files/handheld" ] && find /ctx/system_files/handheld -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    cp -rvT /ctx/system_files/handheld / || true
fi

# ============================================================================
# BUILD SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo "Handheld Build Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. The Containerfile will commit these changes to OSTree"
echo "  2. Run: podman build --target handheld -t whiteblossom-handheld:latest ."
echo ""
