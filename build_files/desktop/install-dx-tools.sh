#!/usr/bin/bash
# Install Bazzite DX Developer Tools
# This script adds developer tools typically found in bazzite-dx variants
# Since we're starting from bazzite-gnome (gaming only), we need to add DX packages

set -eoux pipefail

echo "Installing DX Developer Tools..."

# Core development tools and compilers
dnf5 install -y \
    gcc \
    gcc-c++ \
    make \
    cmake \
    git \
    gh \
    just \
    mold

# Container and virtualization tools
dnf5 install -y \
    podman-compose \
    podman-docker \
    distrobox \
    virt-manager \
    libvirt \
    qemu-kvm

# Programming language runtimes and tools
dnf5 install -y \
    python3 \
    python3-pip \
    python3-devel \
    nodejs \
    npm \
    golang \
    rust \
    cargo

# Development utilities
dnf5 install -y \
    neovim \
    vim-enhanced \
    emacs-nox \
    htop \
    btop \
    bat \
    ripgrep \
    fd-find \
    fzf \
    zoxide \
    tldr

# Terminal multiplexers and shells
dnf5 install -y \
    tmux \
    zsh \
    fish

# Network and debugging tools
dnf5 install -y \
    wget \
    curl \
    netcat \
    nmap \
    wireshark \
    tcpdump \
    iperf3 \
    mtr

# Database clients
dnf5 install -y \
    postgresql \
    mariadb \
    redis \
    sqlite

# Cloud and infrastructure tools
dnf5 install -y \
    terraform \
    ansible \
    kubectl

# Editor integration tools
dnf5 install -y \
    ctags \
    universal-ctags \
    cscope

# System monitoring and profiling
dnf5 install -y \
    sysstat \
    perf \
    strace \
    ltrace

# Documentation tools
dnf5 install -y \
    pandoc \
    texlive-scheme-basic

# Enable libvirtd for virtualization
systemctl enable libvirtd

echo "DX Developer Tools installation complete!"

