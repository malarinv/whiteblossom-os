#!/usr/bin/bash
# Install Google Antigravity IDE
# This script installs the Antigravity IDE following the pattern for rpm-based systems

set -eoux pipefail

echo "Installing Antigravity IDE..."

# Add the Antigravity RPM repository
cat > /etc/yum.repos.d/antigravity.repo << 'EOL'
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=1
gpgkey=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm/gpgkey.gpg
EOL

# Update package cache
dnf5 makecache

# Install the antigravity package
dnf5 install -y antigravity

echo "Antigravity IDE installation complete!"