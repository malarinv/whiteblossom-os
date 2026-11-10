#!/usr/bin/bash
# Install the prebuilt net.whiteblossom.Stremio flatpak bundle.
#
# The bundle is built and validated in Forgejo CI on code-dev
# (repo vendor/stremio-linux-shell-omniphony) — this script only downloads
# and installs the pinned artifact; no flatpak-builder runs during image build.
#
# Bump STREMIO_VERSION when a new validated bundle is published on code-dev.

set -eoux pipefail

STREMIO_VERSION="0.1.0"
STREMIO_URL="https://code-dev.whiteblossom.net/wbadmin/stremio-linux-shell-omniphony/releases/download/flatpak-v${STREMIO_VERSION}/net.whiteblossom.Stremio.flatpak"
BUNDLE="/tmp/net.whiteblossom.Stremio.flatpak"

echo "Downloading net.whiteblossom.Stremio ${STREMIO_VERSION} from code-dev..."
curl -fsSL -o "${BUNDLE}" "${STREMIO_URL}"

# Base image ships flathub; guard for rebuilds on minimal bases.
flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo || true

echo "Installing net.whiteblossom.Stremio (system-wide)..."
if ! flatpak install --system --reinstall --noninteractive "${BUNDLE}"; then
    flatpak uninstall --system --noninteractive net.whiteblossom.Stremio || true
    flatpak install --system --noninteractive "${BUNDLE}"
fi

rm -f "${BUNDLE}"
echo "net.whiteblossom.Stremio installation complete!"
