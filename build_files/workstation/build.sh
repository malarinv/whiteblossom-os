#!/bin/bash

# WhiteBlossom OS Workstation Build Script
# Installs desktop, developer tools, gaming, and networking packages.
# Shared setup (base packages, system files, justfile registration, cleanup)
# is handled by shared/build.sh — run that first.
#
# Build Order:
# 1. DX Developer Tools (IDEs, containers, runtimes)
# 2. KDE Plasma Desktop (alongside GNOME)
# 3. Privacy-Focused Networking Tools
# 4. Antigravity IDE
# 5. System Configuration (security, services, display)

set -ouex pipefail

echo "=========================================="
echo "WhiteBlossom OS Workstation Build"
echo "Base: Bazzite GNOME nvidia-open"
echo "Target: Dual Desktop (GNOME + KDE)"
echo "=========================================="
echo ""

# Resolve script directory (works both locally and under /ctx mount)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "/ctx/build_files/workstation" ]; then
    SCRIPT_DIR="/ctx/build_files/workstation"
fi

# ============================================================================
# STEP 1: Install DX Developer Tools
# ============================================================================

echo "Step 1/5: Installing DX Developer Tools..."
echo "=========================================="

if [ -f "${SCRIPT_DIR}/install-dx-tools.sh" ]; then
    bash "${SCRIPT_DIR}/install-dx-tools.sh"
else
    echo "ERROR: install-dx-tools.sh not found at ${SCRIPT_DIR}"
    exit 1
fi

echo ""
echo "✓ DX Developer Tools installation complete"
echo ""

# ============================================================================
# STEP 1.5: Install Dev Boot Dependencies
# ============================================================================

echo "Installing dev-boot dependencies..."
# virtiofsd: host-side daemon for fast VM boot via direct kernel (dev-boot)
# Installed via dnf during container build, committed to OSTree
if command -v dnf5 >/dev/null 2>&1; then
    dnf5 install -y virtiofsd || echo "WARNING: virtiofsd install failed"
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y virtiofsd || echo "WARNING: virtiofsd install failed"
fi

echo ""
echo "✓ Dev boot dependencies installed"
echo ""

# ============================================================================
# STEP 2: Install KDE Plasma Desktop
# ============================================================================

echo "Step 2/5: Installing KDE Plasma Desktop Environment..."
echo "======================================================"

if [ -f "${SCRIPT_DIR}/install-kde-packages.sh" ]; then
    bash "${SCRIPT_DIR}/install-kde-packages.sh"
else
    echo "ERROR: install-kde-packages.sh not found at ${SCRIPT_DIR}"
    exit 1
fi

echo ""
echo "✓ KDE Plasma Desktop installation complete"
echo ""

# ============================================================================
# STEP 3: Install Privacy-Focused Networking Tools
# ============================================================================

echo "Step 3/5: Installing Networking Tools..."
echo "========================================"

if [ -f "${SCRIPT_DIR}/install-networking-tools.sh" ]; then
    bash "${SCRIPT_DIR}/install-networking-tools.sh"
else
    echo "WARNING: install-networking-tools.sh not found. Skipping."
fi

echo ""
echo "✓ Networking Tools installation (if present) complete"
echo ""

# ============================================================================
# STEP 4: Install Antigravity IDE
# ============================================================================

echo "Step 4/5: Installing Antigravity IDE..."
echo "======================================="

if [ -f "${SCRIPT_DIR}/install-antigravity-ide.sh" ]; then
    bash "${SCRIPT_DIR}/install-antigravity-ide.sh"
else
    echo "WARNING: install-antigravity-ide.sh not found. Skipping."
fi

echo ""
echo "✓ Antigravity IDE installation (if present) complete"
echo ""

# ============================================================================
# STEP 5: Configure System Services and Security
# ============================================================================

echo "Step 5/5: Configuring system services and security..."
echo "====================================================="

if [ -f "${SCRIPT_DIR}/configure-system.sh" ]; then
    bash "${SCRIPT_DIR}/configure-system.sh"
else
    echo "WARNING: configure-system.sh not found. Skipping."
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
# Apply Variant System Files
# ============================================================================

echo "Applying workstation system files..."
if [ -d "/ctx/system_files/workstation" ] && find /ctx/system_files/workstation -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
    cp -rvT /ctx/system_files/workstation / || true
fi

# ============================================================================
# BUILD SUMMARY
# ============================================================================

echo ""
echo "=========================================="
echo "Workstation Build Complete!"
echo "=========================================="
echo ""
echo "Installed Components:"
echo "  ✓ DX Developer Tools (IDEs, containers, runtimes)"
echo "  ✓ KDE Plasma Desktop Environment"
echo "  ✓ Multi-desktop session support"
echo "  ✓ Security hardening (SELinux, firewall)"
echo "  ✓ Privacy-focused networking (Headscale, ZeroTier)"
echo "  ✓ Antigravity IDE (AI-powered development environment)"
echo ""
echo "Next steps:"
echo "  1. The Containerfile will commit these changes to OSTree"
echo "  2. Run: podman build --target workstation -t whiteblossom-workstation:latest ."
echo "  3. Run: just build-qcow2"
echo "  4. Test in VM: just run-vm-qcow2"
echo "  5. At login, select GNOME or Plasma session"
echo ""
