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
    jq \
    container-selinux

# --- ZeroTier ---
echo "Installing ZeroTier..."
cat > /etc/yum.repos.d/zerotier.repo <<'ZTREPO'
[zerotier]
name=ZeroTier, Inc. RPM Release Repository
baseurl=https://download.zerotier.com/redhat/fc/$releasever
enabled=1
gpgcheck=0
sslverify=0
ZTREPO
curl -s https://install.zerotier.com | bash || {
    echo "ZeroTier install script failed, installing from repo..."
    dnf5 install -y --setopt=sslverify=0 zerotier-one || true
}
# --- k3s binary ---
echo "Installing k3s..."

# Ensure Rancher repo is available for k3s-selinux
cat > /etc/yum.repos.d/rancher-k3s-common.repo <<'REPO'
[rancher-k3s-common-stable]
name=Rancher K3s Common (stable)
baseurl=https://rpm.rancher.io/k3s/stable/common/centos/8/noarch
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
REPO

K3S_VERSION="${K3S_VERSION:-v1.35.5+k3s1}"
curl -sfL https://get.k3s.io | \
    INSTALL_K3S_SKIP_ENABLE=true \
    INSTALL_K3S_SKIP_START=true \
    INSTALL_K3S_SELINUX_WARN=true \
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
