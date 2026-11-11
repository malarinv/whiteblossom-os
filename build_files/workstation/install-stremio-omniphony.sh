#!/usr/bin/bash
# Install the prebuilt com.stremio.Stremio.Devel flatpak bundle.
#
# The bundle is built and validated in Forgejo CI on code-dev
# (repo vendor/stremio-linux-shell-omniphony) — this script only downloads
# and installs the pinned artifact; no flatpak-builder runs during image build.
#
# Bump STREMIO_VERSION when a new validated bundle is published on code-dev.

set -eoux pipefail

STREMIO_VERSION="0.1.1"
STREMIO_URL="${STREMIO_URL:-https://code-dev.whiteblossom.net/wbadmin/stremio-linux-shell-omniphony/releases/download/flatpak-v${STREMIO_VERSION}/com.stremio.Stremio.Devel-x86_64.flatpak}"
BUNDLE="/tmp/com.stremio.Stremio.Devel-x86_64.flatpak"

echo "Downloading com.stremio.Stremio.Devel ${STREMIO_VERSION} from code-dev..."
if [ -n "${STREMIO_LOCAL_BUNDLE:-}" ] && [ -f "${STREMIO_LOCAL_BUNDLE}" ]; then
    # Offline/test builds: use a pre-fetched bundle (set STREMIO_LOCAL_BUNDLE in the
    # Containerfile build env to a COPY'd file).
    cp "${STREMIO_LOCAL_BUNDLE}" "${BUNDLE}"
else
    curl -fsSL -o "${BUNDLE}" "${STREMIO_URL}"
fi

# Base image ships flathub; guard for rebuilds on minimal bases.
flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo || true

echo "Installing com.stremio.Stremio.Devel (system-wide)..."
if ! flatpak install --system --reinstall --noninteractive "${BUNDLE}"; then
    flatpak uninstall --system --noninteractive com.stremio.Stremio.Devel || true
    flatpak install --system --noninteractive "${BUNDLE}"
fi

rm -f "${BUNDLE}"
echo "com.stremio.Stremio.Devel installation complete!"
