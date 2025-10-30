#!/usr/bin/bash
# Install Bazzite DX Developer Tools
# This script mirrors the package list from bazzite-dx
# Reference: https://github.com/ublue-os/bazzite-dx/blob/main/build_files/20-install-apps.sh

set -eoux pipefail

echo "Installing Bazzite DX Developer Tools..."

# Core DX packages from bazzite-dx (Fedora repos only)
dnf5 install -y \
    android-tools \
    bcc \
    bpftop \
    bpftrace \
    flatpak-builder \
    ccache \
    nicstat \
    numactl \
    podman-machine \
    podman-tui \
    python3-ramalama \
    qemu-kvm \
    restic \
    rclone \
    sysprof \
    tiptop \
    usbmuxd \
    zsh

# Install ublue-setup-services from COPR (same as bazzite-dx)
dnf5 install --enable-repo="copr:copr.fedorainfracloud.org:ublue-os:packages" -y \
    ublue-setup-services

# Install VSCode from Microsoft repo (same as bazzite-dx)
dnf5 config-manager addrepo --set=baseurl="https://packages.microsoft.com/yumrepos/vscode" --id="vscode"
dnf5 config-manager setopt vscode.enabled=0
dnf5 config-manager setopt vscode.gpgcheck=0
dnf5 install --nogpgcheck --enable-repo="vscode" -y \
    code

# Install Docker from Docker repo (same as bazzite-dx)
docker_pkgs=(
    containerd.io
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
)
dnf5 config-manager addrepo --from-repofile="https://download.docker.com/linux/fedora/docker-ce.repo"
dnf5 config-manager setopt docker-ce-stable.enabled=0
dnf5 install -y --enable-repo="docker-ce-stable" "${docker_pkgs[@]}" || {
    # Fallback to test repo for newer Fedora versions
    if (($(lsb_release -sr) >= 42)); then
        echo "::info::Missing docker packages, falling back to test repos..."
        dnf5 install -y --enablerepo="docker-ce-test" "${docker_pkgs[@]}"
    fi
}

# Load iptable_nat module for docker-in-docker (same as bazzite-dx)
mkdir -p /etc/modules-load.d && cat >>/etc/modules-load.d/ip_tables.conf <<EOF
iptable_nat
EOF

echo "Bazzite DX Developer Tools installation complete!"
echo "Note: Additional dev tools can be installed via distrobox/toolbox as needed"

