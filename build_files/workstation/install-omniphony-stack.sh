#!/usr/bin/bash
# Install the Omniphony binaural playback stack:
#   - mpv-omniphony player (extracted from the release AppImage, no FUSE at runtime)
#   - harletty-bridge decoder bridge libraries
#   - jellyfin-mpv-shim (Jellyfin client that drives the external player)
#
# Config (binaural output mode + bridge discovery) is provisioned per-user via
# /etc/skel in system_files/feature-scopes/omniphony/ — no /etc writes here.
#
# Contingency: if GitHub is unreachable from the build host, pre-download the
# three assets into system_files/feature-scopes/omniphony/vendor/ (git-ignored)
# and set OMNIPHONY_VENDOR_DIR to that directory to use file:// sources.

set -eoux pipefail

OMNIPHONY_VERSION="v0.7.0"
BRIDGE_VERSION="v0.9.0"
SHIM_VERSION="3.3.0"

OMNIPHONY_URL="https://github.com/mgth/Omniphony/releases/download/${OMNIPHONY_VERSION}/omniphony-${OMNIPHONY_VERSION}-linux-x86_64.tar.gz"
APPIMAGE_URL="https://github.com/mgth/Omniphony/releases/download/mpv-${OMNIPHONY_VERSION}/mpv-omniphony-${OMNIPHONY_VERSION}-linux-x86_64.AppImage"
BRIDGE_URL="https://github.com/harletty/harletty-bridge/releases/download/${BRIDGE_VERSION}/harletty-bridge-${BRIDGE_VERSION}-linux-x86_64.zip"

TMPDIR_OMNI="$(mktemp -d /tmp/omniphony-install.XXXXXX)"
trap 'rm -rf "${TMPDIR_OMNI}"' EXIT

fetch() {
    local url="$1" out="$2"
    if [ -n "${OMNIPHONY_VENDOR_DIR:-}" ] && [ -f "${OMNIPHONY_VENDOR_DIR}/$(basename "${out}")" ]; then
        cp "${OMNIPHONY_VENDOR_DIR}/$(basename "${out}")" "${out}"
    else
        curl -fsSL -o "${out}" "${url}"
    fi
}

echo "Downloading Omniphony stack (${OMNIPHONY_VERSION}, bridges ${BRIDGE_VERSION}, shim ${SHIM_VERSION})..."
fetch "${OMNIPHONY_URL}" "${TMPDIR_OMNI}/omniphony.tar.gz"
fetch "${APPIMAGE_URL}" "${TMPDIR_OMNI}/mpv-omniphony.AppImage"
fetch "${BRIDGE_URL}" "${TMPDIR_OMNI}/harletty-bridge.zip"

echo "Extracting player AppImage (no runtime FUSE dependency)..."
chmod +x "${TMPDIR_OMNI}/mpv-omniphony.AppImage"
(cd "${TMPDIR_OMNI}" && ./mpv-omniphony.AppImage --appimage-extract >/dev/null)

echo "Installing player to /usr/lib/omniphony/player/..."
mkdir -p /usr/lib/omniphony/player
cp -a "${TMPDIR_OMNI}/squashfs-root/usr/." /usr/lib/omniphony/player/

cat > /usr/bin/mpv-omniphony << 'EOF'
#!/usr/bin/bash
export LD_LIBRARY_PATH=/usr/lib/omniphony/player/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec /usr/lib/omniphony/player/bin/mpv "$@"
EOF
chmod 0755 /usr/bin/mpv-omniphony

echo "Installing harletty-bridge libraries to /usr/lib/omniphony/bridges/..."
mkdir -p /usr/lib/omniphony/bridges
unzip -o -j "${TMPDIR_OMNI}/harletty-bridge.zip" '*.so' -d /usr/lib/omniphony/bridges/
chmod 0755 /usr/lib/omniphony/bridges/*.so

echo "Installing jellyfin-mpv-shim ${SHIM_VERSION}..."
dnf5 install -y python3-pip
python3 -m pip install --prefix /usr/local "jellyfin-mpv-shim==${SHIM_VERSION}"

echo "Omniphony binaural playback stack installation complete!"
