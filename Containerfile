# =============================================================================
# WhiteBlossom OS — Multi-Variant Containerfile
#
# Build a specific variant:
#   podman build --target <variant> -t whiteblossom-<variant>:latest .
#
# Available variants: workstation, iot, cloud, handheld
# =============================================================================

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files

# =============================================================================
# Variant: Workstation (default)
# Dual-desktop gaming/development (GNOME + KDE + NVIDIA + DX tools)
# Base: Bazzite GNOME with NVIDIA Open Drivers
# =============================================================================
FROM ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable AS workstation

## Image Purpose
# WhiteBlossom OS Workstation: Dual-desktop Linux OS
# - Gaming optimizations and NVIDIA open drivers from Bazzite
# - DX developer tools (IDEs, containers, runtimes)
# - KDE Plasma alongside GNOME for multi-desktop support
# - Privacy-focused networking (Headscale, ZeroTier)

# Run shared build (base packages, system files, justfile registration, cleanup)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/shared/build.sh

# Ensure /nix directory exists for Determinate Nix Installer at runtime
RUN mkdir -p /nix

# Run workstation build (DX tools, KDE, networking, system config)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/workstation/build.sh

# Finalize OSTree commit
RUN ostree container commit

# Verify final image
RUN bootc container lint


# =============================================================================
# Variant: IoT
# Minimal headless build for Raspberry Pi / Rock5B
# Base: Fedora Bootc (minimal, no desktop)
# =============================================================================
FROM quay.io/fedora/fedora-bootc:44 AS iot

## Image Purpose
# WhiteBlossom OS IoT: Headless embedded OS
# - Minimal package set for resource-constrained devices
# - SSH access, serial console, GPIO support
# - NetworkManager for wireless connectivity
# - Cockpit for remote management

# Run shared build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/shared/build.sh

# Run IoT build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/iot/build.sh

# Finalize OSTree commit
RUN ostree container commit

# Verify final image
RUN bootc container lint


# =============================================================================
# Variant: Cloud
# Kubernetes cluster node with k3s
# Base: Bazzite (provides container runtime stack)
# =============================================================================
FROM ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable AS cloud

## Image Purpose
# WhiteBlossom OS Cloud: Kubernetes cluster node
# - k3s lightweight Kubernetes distribution
# - Container runtime stack (containerd, runc)
# - Cluster networking and storage
# - Minimal desktop for occasional management

# Run shared build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/shared/build.sh

# Run cloud build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/cloud/build.sh

# Finalize OSTree commit
RUN ostree container commit

# Verify final image
RUN bootc container lint


# =============================================================================
# Variant: Handheld
# Gaming handheld with Gamescope session (Steam Deck-like)
# Base: Bazzite (provides gaming optimizations + NVIDIA)
# =============================================================================
FROM ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable AS handheld

## Image Purpose
# WhiteBlossom OS Handheld: Gaming handheld OS
# - Gamescope session for console-like experience
# - Steam integration and gaming optimizations
# - Input device mapping for handheld controllers
# - Power management for battery-powered devices

# Run shared build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/shared/build.sh

# Run handheld build
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/handheld/build.sh

# Finalize OSTree commit
RUN ostree container commit

# Verify final image
RUN bootc container lint
