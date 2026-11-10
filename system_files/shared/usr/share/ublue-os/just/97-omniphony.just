# vim: set ft=make :
# Omniphony binaural playback stack: check, migrate, launch Jellyfin shim,
# configure Stremio hand-off.
# Binaries are baked into the image (build_files/*/install-omniphony-stack.sh);
# per-user config comes from /etc/skel via system_files/feature-scopes/omniphony.
# Health check for the binaural playback stack: player binary, bridges, config,

# and a rendered-sine smoke test asserting binaural AO negotiation (2ch).
[group("media")]
omniphony-check:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh 2>/dev/null || true

    fail() { echo "FAIL: $*" >&2; exit 1; }

    [ -x /usr/bin/mpv-omniphony ] || fail "/usr/bin/mpv-omniphony not found (is the image built with install-omniphony-stack.sh?)"
    [ -x /usr/lib/omniphony/player/bin/mpv ] || fail "/usr/lib/omniphony/player/bin/mpv not found"
    [ -d /usr/lib/omniphony/bridges ] || fail "/usr/lib/omniphony/bridges not found"

    echo "Player: $(/usr/bin/mpv-omniphony --version 2>&1 | head -1)"
    echo "Bridges:"
    ls -1 /usr/lib/omniphony/bridges/*.so || fail "no bridge libraries found"

    if [ -f "$HOME/.config/omniphony/config.yaml" ]; then
        echo "Config (~/.config/omniphony/config.yaml):"
        cat "$HOME/.config/omniphony/config.yaml"
    else
        echo "NOTE: no ~/.config/omniphony/config.yaml (run 'ujust omniphony-migrate' if you predate this image)"
    fi

    echo "Generating self-test wav..."
    WAV="$(mktemp /tmp/omniphony-selftest.XXXXXX.wav)"
    trap 'rm -f "$WAV"' EXIT
    python3 -c "import sys, wave, struct, math; w = wave.open(sys.argv[1], 'w'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(48000); w.writeframes(b''.join(struct.pack('<hh', int(8000 * math.sin(2 * math.pi * 440 * i / 48000)), 0) for i in range(48000))); w.close()" "$WAV"
    echo "Running binaural AO negotiation test..."
    if LC_ALL=C /usr/bin/mpv-omniphony --no-config --ao=null --vo=null --length=1 --ad=orender "$WAV" 2>&1 | grep -E '^AO: \[null\].*2ch' >/dev/null; then
        echo "OK: binaural renderer negotiated stereo output (AO 2ch)."
    else
        fail "AO negotiation did not report 2ch — binaural render path not active"
    fi

# Migrate per-user Omniphony/Jellyfin-shim config from /etc/skel (existing users
# created before this image feature never got the skel files). Never overwrites.

# NOTE: this list is literal; extend it when feature-scopes/omniphony's skel grows.
[group("media")]
omniphony-migrate:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh 2>/dev/null || true

    migrated=0
    for item in omniphony jellyfin-mpv-shim; do
        if [ -d "/etc/skel/.config/${item}" ] && [ ! -d "$HOME/.config/${item}" ]; then
            cp -r "/etc/skel/.config/${item}" "$HOME/.config/${item}"
            echo "Created ~/.config/${item} from skel."
            migrated=1
        else
            echo "~/.config/${item}: already present or no skel — left untouched."
        fi
    done
    [ "$migrated" = "1" ] && echo "Migration done." || echo "Nothing to migrate."

# Launch the Jellyfin MPV shim (external player = mpv-omniphony via skel conf).
[group("media")]
jellyfin-shim:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh 2>/dev/null || true
    SHIM=""
    for candidate in "$HOME/.local/bin/jellyfin-mpv-shim" /usr/local/bin/jellyfin-mpv-shim; do
        if [ -x "$candidate" ]; then SHIM="$candidate"; break; fi
    done
    [ -n "$SHIM" ] || { echo "jellyfin-mpv-shim not found in ~/.local/bin or /usr/local/bin." >&2; exit 1; }
    exec "$SHIM"

# Configure the Stremio hand-off: write the external-player preference into
# ~/.config/Stremio/settings.json pointing at the in-sandbox launcher /app/bin/mpv
# (net.whiteblossom.Stremio flatpak). Idempotent: merges keys, preserves the rest.
#
# KEY NAMES: the exact settings.json keys for Stremio's external-player selection
# are captured during validation (see whiteblossom-os plan Verification step 5).
# Until confirmed, PATCH is a best-effort guess — run 'ujust stremio-omniphony-verify'
# after applying and, if playback does not jump to MPV, set the player manually in

# Stremio's settings UI to the custom path /app/bin/mpv-omniphony.
[group("media")]
stremio-omniphony-setup:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh 2>/dev/null || true

    command -v jq >/dev/null 2>&1 || dnf5 install -y jq

    SETTINGS="$HOME/.config/Stremio/settings.json"
    mkdir -p "$HOME/.config/Stremio"
    PATCH="$(mktemp /tmp/stremio-omni-patch.XXXXXX.json)"
    trap 'rm -f "$PATCH"' EXIT
    printf '{\n  "customPlayerCommand": "/app/bin/mpv",\n  "useExternalPlayer": true\n}\n' > "$PATCH"
    if [ -f "$SETTINGS" ]; then
        tmp="$(mktemp /tmp/stremio-settings.XXXXXX.json)"
        jq -s '.[0] * .[1]' "$SETTINGS" "$PATCH" > "$tmp"
        mv "$tmp" "$SETTINGS"
    else
        cp "$PATCH" "$SETTINGS"
    fi
    echo "Patched $SETTINGS:"
    cat "$SETTINGS"
    echo ""
    echo "Verify with: ujust stremio-omniphony-verify"
    echo "If playback does not use MPV: open Stremio settings, choose the custom"
    echo "player path /app/bin/mpv-omniphony manually, and update this recipe's"
    echo "PATCH keys to match what Stremio wrote."

# Verify the net.whiteblossom.Stremio sandbox hands playback off to the baked host
# player through the flatpak-spawn portal (Flatpak reserves /usr, so filesystem
# grants can never expose /usr/lib/omniphony inside the sandbox).
[group("media")]
stremio-omniphony-verify:
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh 2>/dev/null || true
    fail() { echo "FAIL: $*" >&2; exit 1; }

    flatpak info net.whiteblossom.Stremio >/dev/null 2>&1 || fail "net.whiteblossom.Stremio is not installed"
    [ -x /usr/bin/mpv-omniphony ] || fail "/usr/bin/mpv-omniphony not found on host (image missing install-omniphony-stack.sh?)"
    echo "Checking in-sandbox launcher reaches the host player (orender build)..."
    out="$(flatpak run --command=/app/bin/mpv net.whiteblossom.Stremio --version 2>&1)"
    echo "$out" | head -3
    echo "$out" | grep -q "orender" || fail "host player did not report orender build (flatpak-spawn hand-off broken?)"
    echo "OK: Stremio sandbox spawns the host Omniphony player via flatpak-spawn."
