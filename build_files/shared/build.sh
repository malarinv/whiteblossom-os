#!/bin/bash

# WhiteBlossom OS Shared Build Script
# Common setup shared across all variants (workstation, iot, k3s, handheld).
#
# This script handles:
# 1. Base package installation
# 2. System file application (shared layer)
# 3. Justfile registration
# 4. Package cache cleanup

set -ouex pipefail

echo "=========================================="
echo "WhiteBlossom OS Shared Build Process"
echo "=========================================="
echo ""

# ============================================================================
# STEP 1: Install Base Packages
# ============================================================================

echo "Installing base packages..."
if command -v dnf5 >/dev/null 2>&1; then
    dnf5 install -y tmux
else
    dnf install -y tmux
fi

# Enable virtiofs in initramfs for dev-boot support
mkdir -p /etc/dracut.conf.d
echo 'add_dracutmodules+=" virtiofs "' > /etc/dracut.conf.d/virtiofs.conf

# ============================================================================
# STEP 2: Apply Shared System Files
# ============================================================================

echo "Applying shared system files..."
for dir in "/ctx/system_files/shared"; do
    if [ -d "$dir" ] && find "$dir" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
        cp -rvT "$dir" / || true
    fi
done

# ============================================================================
# STEP 3: Justfile Registration
# ============================================================================

echo "Registering custom justfiles..."
for file in /usr/share/ublue-os/just/*.just; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        if ! grep -q "$filename" /usr/share/ublue-os/justfile 2>/dev/null; then
            echo "Importing $file into main justfile"
            echo "import \"$file\"" >> /usr/share/ublue-os/justfile || true
        fi
    fi
done

# ============================================================================
# STEP 4: Cleanup
# ============================================================================

echo "Running shared cleanup..."
if command -v dnf5 >/dev/null 2>&1; then
    dnf5 clean all
elif command -v dnf >/dev/null 2>&1; then
    dnf clean all
fi

echo ""
echo "✓ Shared build process complete"
echo ""
