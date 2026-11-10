# Feature Scopes

Modular, self-contained feature trees layered onto the image at build time.

## Contract

- Each directory under `feature-scopes/` is an **independent, self-contained** feature tree. No scope may reference another scope's files.
- Every path inside a scope is **absolute from `/`** (e.g. `etc/skel/...`, `usr/share/...`) so the build loop's `cp -rvT <scope> /` works unchanged.
- Variants opt in via a `.scopes` file in their own tree (`system_files/<variant>/.scopes`), one scope name per line. A missing `.scopes` file means no scopes are applied.
- Copy order at build time: scopes first, then the variant's own system files — variant-local files win a conflict.
- iot/cloud have no `.scopes` file and their `build.sh` has no scope loop; add both together if a feature must ship there.

## Current scopes

| Scope | Contents |
|-------|----------|
| `omniphony` | Per-user skel for the binaural playback stack: Omniphony engine config (`render.binaural.output_mode`, `render.bridge_paths`), jellyfin-mpv-shim external-player config + `mpv.conf` (`ad=orender`). Binaries are installed by `build_files/*/install-omniphony-stack.sh`, not here. |

## Adding a feature

Create `feature-scopes/<name>/` with absolute paths, add `<name>` to the opting variants' `.scopes` files, and wire any install script as a build step in the variant `build.sh`. Do not grow the variant trees.
