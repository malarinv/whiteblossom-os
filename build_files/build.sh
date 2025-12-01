#!/bin/bash

# WhiteBlossom OS Build Script
# This script orchestrates the installation of custom packages and configurations
# to transform the Bazzite base image into a dual-desktop developer environment.
#
# Build Order:
# 1. DX Developer Tools (IDEs, containers, runtimes)
# 2. KDE Plasma Desktop (alongside GNOME)
# 3. System Configuration (security, services, networking)

set -ouex pipefail

echo "=========================================="
echo "WhiteBlossom OS Build Process"
echo "Base: Bazzite GNOME nvidia-open"
echo "Target: Dual Desktop (GNOME + KDE)"
echo "=========================================="
echo ""

# Install base packages (if needed)
echo "Installing base packages..."
if command -v dnf5 >/dev/null 2>&1; then
    dnf5 install -y tmux
else
    dnf install -y tmux
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="${SCRIPT_DIR}/desktop"

# ============================================================================
# STEP 1: Install DX Developer Tools
# ============================================================================

echo "Step 1/3: Installing DX Developer Tools..."
echo "=========================================="

if [ -f "${DESKTOP_DIR}/install-dx-tools.sh" ]; then
    bash "${DESKTOP_DIR}/install-dx-tools.sh"
elif [ -f /ctx/build_files/desktop/install-dx-tools.sh ]; then
    bash /ctx/build_files/desktop/install-dx-tools.sh
else
    echo "ERROR: install-dx-tools.sh not found in either local or /ctx path"
    exit 1
fi

echo ""
echo "✓ DX Developer Tools installation complete"
echo ""

# ============================================================================
# STEP 2: Install KDE Plasma Desktop
# ============================================================================

echo "Step 2/3: Installing KDE Plasma Desktop Environment..."
echo "======================================================"

if [ -f "${DESKTOP_DIR}/install-kde-packages.sh" ]; then
    bash "${DESKTOP_DIR}/install-kde-packages.sh"
elif [ -f /ctx/build_files/desktop/install-kde-packages.sh ]; then
    bash /ctx/build_files/desktop/install-kde-packages.sh
else
    echo "ERROR: install-kde-packages.sh not found in either local or /ctx path"
    exit 1
fi

echo ""
echo "✓ KDE Plasma Desktop installation complete"
echo ""

# ============================================================================
# STEP 3: Install Privacy-Focused Networking Tools
# ============================================================================

echo "Step 3/3: Installing Networking Tools..."
echo "========================================"

if [ -f "${DESKTOP_DIR}/install-networking-tools.sh" ]; then
    bash "${DESKTOP_DIR}/install-networking-tools.sh"
elif [ -f /ctx/build_files/desktop/install-networking-tools.sh ]; then
    bash /ctx/build_files/desktop/install-networking-tools.sh
else
    echo "WARNING: install-networking-tools.sh not found. Skipping networking tools installation."
fi

echo ""
echo "✓ Networking Tools installation (if present) complete"
echo ""

# ============================================================================
# STEP 4: Install Antigravity IDE
# ============================================================================

echo "Step 4/4: Installing Antigravity IDE..."
echo "======================================="

if [ -f "${DESKTOP_DIR}/install-antigravity-ide.sh" ]; then
    bash "${DESKTOP_DIR}/install-antigravity-ide.sh"
elif [ -f /ctx/build_files/desktop/install-antigravity-ide.sh ]; then
    bash /ctx/build_files/desktop/install-antigravity-ide.sh
else
    echo "WARNING: install-antigravity-ide.sh not found. Skipping Antigravity IDE installation."
fi

echo ""
echo "✓ Antigravity IDE installation (if present) complete"
echo ""

# ============================================================================
# STEP 5: Configure System Services and Security
# ============================================================================

echo "Configuring system services and security..."
echo "==========================================="

if [ -f "${DESKTOP_DIR}/configure-system.sh" ]; then
    bash "${DESKTOP_DIR}/configure-system.sh"
elif [ -f /ctx/build_files/desktop/configure-system.sh ]; then
    bash /ctx/build_files/desktop/configure-system.sh
else
    echo "WARNING: configure-system.sh not found. Skipping system configuration."
fi

# Enable system services
if command -v systemctl >/dev/null 2>&1; then
    systemctl enable podman.socket || true
    systemctl enable libvirtd || true
fi

echo ""
echo "✓ System configuration complete"
echo ""

# ============================================================================
# ADDITIONAL CONFIGURATIONS (if any system_files exist)
# ============================================================================

echo "Applying system files if present..."

for dir in "/ctx/system_files/shared" "/ctx/system_files/kde" "/ctx/system_files/gnome"; do
    if [ -d "$dir" ]; then
        # Extract the leaf directory name for log messages
        LEAF=$(basename "$dir")
        echo "Applying files for $LEAF..."
        cp -rv "$dir"/* / 2>/dev/null || true
    fi
done

# ============================================================================
# CLEANUP
# ============================================================================

echo "Running cleanup..."
echo "=================="
if command -v dnf5 >/dev/null 2>&1; then
    dnf5 clean all
elif command -v dnf >/dev/null 2>&1; then
    dnf clean all
fi

# ============================================================================
# BUILD SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo "Build Process Complete!"
echo "=========================================="
echo ""
echo "Installed Components:"
echo "  ✓ Bazzite Base Image (GNOME + nvidia-open drivers)"
echo "  ✓ DX Developer Tools (IDEs, containers, runtimes)"
echo "  ✓ KDE Plasma Desktop Environment"
echo "  ✓ Multi-desktop session support"
echo "  ✓ Security hardening (SELinux, firewall)"
echo "  ✓ Privacy-focused networking (Headscale, ZeroTier)"
echo "  ✓ Antigravity IDE (AI-powered development environment)"
echo ""
echo "Next steps:"
echo "  1. The Containerfile will commit these changes to OSTree"
echo "  2. Run: just build-qcow2"
echo "  3. Test in VM: just run-vm-qcow2"
echo "  4. At login, select GNOME or Plasma session"
echo ""
