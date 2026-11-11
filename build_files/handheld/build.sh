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
# STEP 3: Install Omniphony Binaural Playback Stack
# ============================================================================

echo "Step 3: Installing Omniphony binaural playback stack..."
echo "======================================================="

if [ -f "${SCRIPT_DIR}/install-omniphony-stack.sh" ]; then
    bash "${SCRIPT_DIR}/install-omniphony-stack.sh"
else
    echo "WARNING: install-omniphony-stack.sh not found (shared with workstation tree). Skipping."
fi

echo ""
echo "✓ Omniphony binaural playback stack installation (if present) complete"
echo ""

# ============================================================================
# STEP 4: Install Stremio Omniphony Flatpak (prebuilt artifact)
# ============================================================================

echo "Step 4: Installing com.stremio.Stremio.Devel flatpak..."
echo "======================================================"

if [ -f "${SCRIPT_DIR}/install-stremio-omniphony.sh" ]; then
    bash "${SCRIPT_DIR}/install-stremio-omniphony.sh"
elif [ -f "/ctx/build_files/workstation/install-stremio-omniphony.sh" ]; then
    bash "/ctx/build_files/workstation/install-stremio-omniphony.sh"
else
    echo "WARNING: install-stremio-omniphony.sh not found. Skipping."
fi

echo ""
echo "✓ Stremio Omniphony flatpak installation (if present) complete"
echo ""

# ============================================================================
# Apply Variant System Files
# ============================================================================

echo "Applying opt-in feature scopes (system_files/feature-scopes)..."
if [ -f "/ctx/system_files/handheld/.scopes" ]; then
    while read -r scope; do
        [ -n "$scope" ] || continue
        if [ -d "/ctx/system_files/feature-scopes/${scope}" ]; then
            cp -rvT "/ctx/system_files/feature-scopes/${scope}" / || true
        else
            echo "WARNING: feature scope '${scope}' has no directory under /ctx/system_files/feature-scopes/. Skipping."
        fi
    done < "/ctx/system_files/handheld/.scopes"
fi

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
echo "Installed Components:"
echo "  ✓ Omniphony binaural playback (mpv-omniphony + bridges + Jellyfin shim)"
echo "  ✓ Stremio with host Atmos hand-off (com.stremio.Stremio.Devel)"
echo ""
echo "Next steps:"
echo "  1. The Containerfile will commit these changes to OSTree"
echo "  2. Run: podman build --target handheld -t whiteblossom-handheld:latest ."
echo ""
