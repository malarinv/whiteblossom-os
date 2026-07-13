#!/usr/bin/bash
# Install Dev Boot Dependencies
# virtiofsd: host-side daemon for fast VM boot via direct kernel (dev-boot)
# This allows booting cloud/IoT container images directly in QEMU without BIB.

set -eoux pipefail

echo "Installing dev-boot dependencies..."

if command -v dnf5 >/dev/null 2>&1; then
    dnf5 install -y virtiofsd || echo "WARNING: virtiofsd install failed"
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y virtiofsd || echo "WARNING: virtiofsd install failed"
fi

echo "Dev boot dependencies installed!"
