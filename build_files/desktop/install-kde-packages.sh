#!/usr/bin/bash
# Install KDE Plasma Desktop Environment
# This script adds KDE Plasma packages from bazzite-nvidia-open to our GNOME base
# Follows the package list from Bazzite's KDE variant

set -eoux pipefail

echo "Installing KDE Plasma Desktop Environment..."

# Core KDE Plasma packages
dnf5 install -y \
    plasma-desktop \
    plasma-workspace \
    plasma-workspace-wayland \
    plasma-pa \
    plasma-nm \
    plasma-systemmonitor \
    plasma-thunderbolt \
    plasma-vault \
    plasma-welcomekmix \
    sddm \
    sddm-breeze \
    sddm-kcm \
    kscreen \
    kwin-wayland \
    kwin-x11 \
    kwrited

# KDE Applications and Utilities
dnf5 install -y \
    dolphin \
    dolphin-plugins \
    kate \
    kcalc \
    konsole \
    ark \
    gwenview \
    okular \
    spectacle \
    kfind \
    filelight \
    ksystemlog

# KDE System Settings and Configuration
dnf5 install -y \
    systemsettings \
    plasma-drkonqi \
    kinfocenter \
    kde-cli-tools \
    kde-gtk-config \
    khotkeys \
    kmenuedit \
    kpipewire \
    kglobalacceld \
    kglobalaccel

# KDE Frameworks and Libraries (if not already present)
dnf5 install -y \
    kf6-kconfig \
    kf6-kcoreaddons \
    kf6-ki18n \
    kf6-kio \
    kf6-kservice \
    kf6-kwindowsystem

# Gaming-specific KDE packages (from bazzite)
dnf5 install -y \
    steamdeck-kde-presets-desktop \
    krdp \
    kdeconnectd \
    kdeplasma-addons

# Additional KDE utilities
dnf5 install -y \
    kde-partitionmanager \
    rom-properties-kf6 \
    kio-extras \
    kio-gdrive \
    kio-admin

# Input methods and internationalization
dnf5 install -y \
    fcitx5 \
    fcitx5-mozc \
    fcitx5-chinese-addons \
    fcitx5-hangul \
    kcm-fcitx5

# Additional Plasma addons
dnf5 install -y \
    plasma-browser-integration \
    kdegraphics-thumbnailers

# Network and connectivity
dnf5 install -y \
    bluedevil \
    powerdevil

# Terminal emulator (Ptyxis is already in base, keep Konsole as option)
# Both terminals will be available, users can choose

# KRunner plugins and extensions
dnf5 install -y \
    krunner

# Print support
dnf5 install -y \
    print-manager

# Package to test and potentially remove if they cause conflicts
# These will be tested first, only removed if issues occur
# - plasma-discover (may conflict with GNOME Software)
# - plasma-welcome (may auto-launch annoyingly)

echo "Testing for package conflicts..."

# Test-install packages that might conflict
# Install them but be ready to remove if they cause issues
dnf5 install -y \
    plasma-discover || echo "plasma-discover installation failed or was skipped"

# Note: plasma-welcome may auto-launch on first KDE session
# If this becomes annoying, we can remove it in a future iteration

# Configure SDDM (but keep it disabled by default, GDM is primary)
systemctl disable sddm.service || true

# Ensure GDM shows both GNOME and Plasma sessions
# Session files are automatically detected from /usr/share/xsessions/ and /usr/share/wayland-sessions/

echo "KDE Plasma installation complete!"
echo "Both GNOME and KDE Plasma desktop environments are now available."
echo "Users can select their preferred desktop at the login screen."

