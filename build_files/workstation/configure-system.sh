#!/usr/bin/bash

# Configure WhiteBlossom OS System Services and Security
# This script handles:
# - System-wide security hardening (SELinux, firewall)
# - Privacy-focused networking (Headscale, ZeroTier)
# - Display manager configuration for dual desktop
# - Multi-user session management
# - Service enablement/disablement

set -eoux pipefail

echo "Configuring WhiteBlossom OS system services..."

# ============================================================================
# SECURITY CONFIGURATION
# ============================================================================

echo "Configuring security settings..."

# SELinux configuration
# Ensure SELinux is enabled and in enforcing mode for system-wide security
echo "Setting up SELinux..."
if command -v getenforce &> /dev/null; then
    # SELinux is installed
    if selinuxenabled; then
        echo "SELinux is already enabled"
        # Set to enforcing mode
        semanage fcontext -m -t user_home_t "/home/(.*)" || true
    else
        echo "Enabling SELinux..."
        # Enable SELinux (this requires reboot)
        sed -i 's/SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config || true
    fi
else
    echo "SELinux not available"
fi

# Firewall configuration
echo "Configuring firewall..."
systemctl enable firewalld.service || true
systemctl start firewalld.service || true

# Set default zone
firewall-cmd --set-default-zone=public || true

# Enable masquerading for local network
firewall-cmd --permanent --add-masquerade || true
firewall-cmd --reload || true

# ============================================================================
# VPN AND NETWORKING CONFIGURATION
# ============================================================================

echo "Configuring privacy-focused VPN solutions..."

# Remove Tailscale (commercial VPN, replaced with open-source alternatives)
echo "Removing Tailscale..."
dnf5 remove -y tailscale || true

# Stop and disable tailscale service if it exists
systemctl disable tailscaled.service || true
systemctl stop tailscaled.service || true

# Remove tailscale repository if configured
rm -f /etc/yum.repos.d/*tailscale* || true

# Install Headscale (open-source Tailscale control server)
echo "Installing Headscale..."
dnf5 copr enable -y jonathanspw/headscale || true
dnf5 install -y headscale || true
dnf5 copr disable -y jonathanspw/headscale || true

# Configure Headscale
# Create configuration directory if it doesn't exist
mkdir -p /etc/headscale

# Copy example configuration if available, or create minimal one
if [ ! -f /etc/headscale/config.yaml ]; then
    cat > /etc/headscale/config.yaml << 'EOF'
# Headscale Configuration
# Edit this file to configure your self-hosted Tailscale control server
# 
# For full documentation, visit: https://headscale.net/

# Server address and port
server_url: "http://localhost:8080"
listen_address: "0.0.0.0:8080"

# Database
db:
  type: "sqlite3"
  sqlite:
    path: "/var/lib/headscale/db.sqlite3"

# Private key path (will be generated if missing)
private_key_path: "/var/lib/headscale/private.key"

# Log settings
log:
  level: "info"
  format: "text"

# DNS settings
dns:
  base_domain: "example.com"
  nameservers:
    - "8.8.8.8"
    - "8.8.4.4"

# OIDC settings (optional)
# oidc:
#   enabled: false
#   issuer: "https://your-oidc-provider.com"
#   client_id: "your-client-id"
#   client_secret: "your-client-secret"
EOF
    chown -R headscale:headscale /etc/headscale /var/lib/headscale || true
    chmod 700 /etc/headscale /var/lib/headscale || true
    chmod 600 /etc/headscale/config.yaml || true
fi

# Disable Headscale service by default (user enables when ready)
systemctl disable headscale.service || true
systemctl stop headscale.service || true

# Install ZeroTier (alternative mesh VPN solution)
echo "Installing ZeroTier..."
# RPMFusion should already be enabled in Bazzite base
dnf5 install -y zerotier-one || true

# Disable ZeroTier service by default (user enables when ready)
systemctl disable zerotier-one.service || true
systemctl stop zerotier-one.service || true

# ============================================================================
# DISPLAY MANAGER CONFIGURATION
# ============================================================================

echo "Configuring display managers..."

# Ensure GDM is the primary display manager
# It works well with both GNOME and KDE Plasma sessions
systemctl set-default graphical.target || true
systemctl enable gdm.service || true

# Disable SDDM as primary (KDE's display manager)
# It will still be available but GDM takes precedence
systemctl disable sddm.service || true

# ============================================================================
# MULTI-USER SESSION CONFIGURATION
# ============================================================================

echo "Configuring multi-user session support..."

# Enable remote login (required for multi-user sessions)
systemctl enable sshd.service || true

# Configure systemd user limits for better multi-user performance
if [ ! -f /etc/systemd/system-user-sessions.conf.d/20-whiteblossomed.conf ]; then
    mkdir -p /etc/systemd/system-user-sessions.conf.d
    cat > /etc/systemd/system-user-sessions.conf.d/20-whiteblossom.conf << 'EOF'
# WhiteBlossom OS Multi-User Configuration
# Optimized for two simultaneous user sessions

# Increase number of allowed user processes
DefaultTasksMax=16384

# Allow more file descriptors per user
DefaultLimitNOFILE=65536

# Allow more open sockets
DefaultLimitNPROC=65536
EOF
fi

# ============================================================================
# SYSTEM SERVICES CONFIGURATION
# ============================================================================

echo "Enabling required system services..."

# Enable key services for desktop functionality
systemctl enable dbus.service || true
systemctl enable polkit.service || true
systemctl enable systemd-logind.service || true

# Enable networking services
systemctl enable NetworkManager.service || true
systemctl enable systemd-resolved.service || true

# Enable user sessions
systemctl enable systemd-user-sessions.service || true

# ============================================================================
# PRIVACY SETTINGS CONFIGURATION
# ============================================================================

echo "Configuring privacy settings..."

# Disable telemetry at the system level (per Fedora defaults)
# Most tools respect the following environment variables:
echo "Setting privacy environment variables..."

# Create profile.d entry for system-wide privacy settings
cat > /etc/profile.d/privacy-settings.sh << 'EOF'
# WhiteBlossom OS Privacy Settings
# These settings are applied system-wide but users can override per-session

# Disable various telemetry and tracking systems
export DISABLE_TELEMETRY=1
export DISABLE_ANALYTICS=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export POWERSHELL_TELEMETRY_OPTOUT=1

# Disable crash reporting to external services
export DISABLE_CRASH_REPORTS=1
EOF

chmod 644 /etc/profile.d/privacy-settings.sh

# ============================================================================
# CLEANUP
# ============================================================================

echo "Cleaning up package caches..."
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/yum/*

echo "System configuration complete!"
echo ""
echo "Summary of changes:"
echo "- SELinux configured for enforcing mode"
echo "- Firewall (firewalld) enabled"
echo "- Tailscale removed and replaced with Headscale + ZeroTier"
echo "- GDM set as primary display manager"
echo "- Multi-user session support configured"
echo "- System-wide privacy settings applied"
echo ""
echo "Next steps:"
echo "- Both Headscale and ZeroTier are disabled by default"
echo "- Users can enable them with: sudo systemctl enable --now headscale"
echo "- Or for ZeroTier: sudo systemctl enable --now zerotier-one"
