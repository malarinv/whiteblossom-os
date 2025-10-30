# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files

# Base Image: Bazzite GNOME with NVIDIA Open Drivers
# Provides: Gaming optimizations, GNOME desktop, NVIDIA open-source drivers
# We'll layer KDE Plasma and DX developer tools on top
FROM ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable

## Image Purpose
# WhiteBlossom OS: Dual-desktop Linux OS with GNOME + KDE Plasma
# - Primary base provides gaming optimizations and NVIDIA open drivers
# - DX developer tools (IDEs, containers, runtimes) will be layered on top
# - KDE Plasma will be added for multi-desktop support
# - Supports simultaneous multi-user sessions with different desktop environments

### MODIFICATIONS

# Run main build script to install all packages (DX tools, KDE Plasma, etc.)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh

# Copy system configuration files
# Order matters: shared -> gnome -> kde (later files override earlier ones)
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    mkdir -p /usr/share/doc/whiteblossom-os && \
    if [ -d /ctx/system_files/shared ]; then \
        cp -rT /ctx/system_files/shared / || true; \
    fi && \
    if [ -d /ctx/system_files/gnome ]; then \
        cp -rT /ctx/system_files/gnome / || true; \
    fi && \
    if [ -d /ctx/system_files/kde ]; then \
        cp -rT /ctx/system_files/kde / || true; \
    fi

# Finalize OSTree commit
RUN ostree container commit

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
