#!/usr/bin/bash
# Install Google Antigravity IDE
# This script installs the Antigravity IDE following the pattern for rpm-based systems

set -eoux pipefail

echo "Installing Antigravity IDE..."

# Download and import the GPG key for the Antigravity repository
curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
  gpg --dearmor -o /etc/pki/rpm-gpg/RPM-GPG-KEY-antigravity

# Add the Antigravity RPM repository
cat > /etc/yum.repos.d/antigravity.repo << 'EOL'
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-antigravity
EOL

# Update package cache
dnf5 makecache

# Install the antigravity package
dnf5 install -y antigravity

echo "Antigravity IDE installation complete!"