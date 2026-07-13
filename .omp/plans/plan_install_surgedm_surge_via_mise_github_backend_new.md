# Plan: Install SurgeDM/Surge via mise `github` backend

## Goal

Add SurgeDM/Surge to the project's dev environment via mise, then use it to download a 6.3 GB GitHub Actions artifact.
## Key Findings

1. **Surge is NOT in the mise shorthand registry** (`mise registry surge` → not found). The `surge` shorthand maps to the npm `surge` static hosting CLI, not SurgeDM.

2. **Surge IS in the aqua registry** (`aqua:SurgeDM/Surge`), but the **`github` backend is simpler** — no aqua dependency, mise auto-detects OS/arch, and Surge publishes clean per-platform assets.

3. **SurgeDM/Surge release assets** follow the pattern `Surge_<version>_<os>_<arch>.tar.gz` with a single `surge` binary inside. Mise's autodetection handles this.

4. **The target artifact**: Run `28965187920` on `malarinv/whiteblossom-os`, artifact ID `8179120935`, 6.3 GB, expires 2026-10-06.

5. **Mise is configured globally** at `~/.config/mise/config.toml` with existing tools using the `github:` prefix (see `github:can1357/oh-my-pi`).
6. **No project-level `.mise.toml` exists yet** — we'll create one at the repo root.

## Approach

### Step 1: Create `mise.toml` at project root

Create a new file `mise.toml` in the repo root with the Surge tool:

```toml
[tools]
"github:SurgeDM/Surge@latest" = "latest"
```

This maps to mise's `github` backend which will autodetect the correct platform asset from GitHub releases. The global config already uses the `github:` prefix (see `github:can1357/oh-my-pi`).

**File:** `mise.toml` (new)

### Step 2: Run `mise install` to pull Surge

```bash
mise install
```

This will download the latest Surge release from GitHub and place it on PATH.

### Step 3: Download the artifact

```bash
surge "https://api.github.com/repos/malarinv/whiteblossom-os/actions/artifacts/8179120935/zip" \
  --exit-when-done
```

If GitHub requires auth for the download endpoint (it sometimes does for artifacts even on public repos):

```bash
surge "https://api.github.com/repos/malarinv/whiteblossom-os/actions/artifacts/8179120935/zip" \
  --header "Authorization: Bearer $(gh auth token)" \
  --exit-when-done
```

## Why `github` backend over `aqua`

- No extra backend dependency (aqua is Tier 1 but still an extra layer)
- Surge's release assets are simple single-binary tarballs — exactly what `github` autodetection is built for
- Fewer moving parts in the config

## Verification

1. `mise ls | grep surge` — confirm surge is installed
2. `surge --version` — confirm version
3. `surge <artifact-url> --exit-when-done` — confirm download works
