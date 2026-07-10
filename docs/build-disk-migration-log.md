# build-disk Migration Log

This document captures the issues encountered and fixes applied to the `build-disk` workflow in July 2026, and the architectural decisions behind the current ISO build approach.

## Timeline

### Phase 1: Dead BIB image

The `build-disk` workflow was failing with:

```
Failed to pull image ghcr.io/lorbuschris/bootc-image-builder:20250608: exit code 125
```

**Root cause:** Line 30 of `build-disk.yml` set `BIB_IMAGE` to a custom fork image that no longer exists. This was a temporary workaround for upstream PR #954 (now resolved).

**Fix:** Removed the `BIB_IMAGE` env var and `builder-image` parameter, letting the action use its default (`quay.io/centos-bootc/bootc-image-builder:latest`).

### Phase 2: Missing `--rootfs` flag

After the image pull succeeded, the build failed with:

```
error: cannot build manifest: no default root filesystem type specified in container,
please use "--rootfs" to set manually
```

**Root cause:** The bazzite base image uses btrfs, but the BIB container no longer auto-detects the rootfs type. The Justfile already passes `--rootfs=btrfs` for local builds.

**Fix:** Added `rootfs: btrfs` to the BIB action step in the workflow.

### Phase 3: GPG key bug in `anaconda-iso` type

After the rootfs fix, the qcow2 build succeeded but the anaconda-iso build failed with:

```
error: cannot build manifest: cannot depsolve: DNF error occurred:
RepoError: Failed to retrieve GPG key for repo 'terra-mesa':
Could not read a file:// file for file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra44-mesa
```

**Root cause:** The `terra-mesa` repo in the bazzite base image uses `gpgkey=file:///etc/pki/rpm-gpg/RPG-GPG-KEY-terra44-mesa`. The BIB depsolver cannot resolve `file://` GPG key paths in the ISO build context. This is an upstream bug in osbuild (issue #1188, open since Jan 2026).

**Fix:** Migrated from `bootc-image-builder` (BIB) to `image-builder-cli`, using the `bootc-generic-iso` type instead of `anaconda-iso`. This required:

1. A separate `Containerfile.iso` that layers Anaconda + build tools on top of the main image
2. Direct `image-builder-cli` invocation instead of the BIB action
3. Config files under `iso_config/` for GRUB, kickstart, and systemd

### Phase 4: Iterative fixes during ISO migration

Several issues surfaced during implementation:

| Issue | Error | Fix |
|-------|-------|-----|
| Symlinks already exist | `ln -s /lib/systemd/system/anaconda.target ...` fails | Use `ln -sf` to force-overwrite |
| Wrong CLI flag | `error: unknown flag: --output` | `image-builder-cli` uses `--output-dir`, not `--output` |
| Disk exhaustion | Both jobs ran out of space on the same runner | Make ISO job depend on qcow2 (`needs: build-qcow2`) |

### Phase 5: Installation hangs at image download

After the CI builds succeeded, manual testing revealed the ISO boots to Anaconda but the installation stalls when trying to pull the container image from a registry. This is because **`bootc-generic-iso` does NOT embed the image** — it's a generic installer that requires network access.

## Architecture Decisions

### Why `image-builder-cli` instead of `bootc-image-builder`?

The osbuild project is migrating from the standalone `bootc-image-builder` to the unified `image-builder` CLI. The `bootc-image-builder-action` GitHub Action wraps BIB, which is now a compatibility layer over the unified tool.

The GPG key bug (issue #1188) is in BIB's depsolver code. The `image-builder-cli` has `--force-repo` support to override repo configurations, and the `bootc-generic-iso` type handles the build differently.

Key differences:

| | `bootc-image-builder` (BIB) | `image-builder-cli` |
|---|---|---|
| GitHub Action | `osbuild/bootc-image-builder-action` | None (run container directly) |
| Self-contained ISO type | `anaconda-iso` (embeds image) | `bootc-generic-iso` (requires network) |
| GPG key handling | Broken for `file://` paths | Supports `--force-repo` override |
| `--output` flag | Yes | No, use `--output-dir` |

### Why a separate `Containerfile.iso`?

The main image (`Containerfile`) builds a clean desktop OS. Adding Anaconda and build tools to it would:

- Increase image size significantly
- Pollute the running system with installer-specific packages
- Require rebuilding the main image for every ISO config change

Instead, `Containerfile.iso` uses `FROM` to extend the published main image and adds only what's needed for ISO building. This is built on-the-fly during the CI job.

### Why sequential jobs?

GitHub-hosted runners have ~14GB free disk space. The qcow2 build (BIB container pull + image build) and the ISO build (image-builder-cli pull + Anaconda install + squashfs creation) each consume ~8-10GB. Running them in parallel exhausts disk space. Making ISO depend on qcow2 (`needs: build-qcow2`) ensures they don't compete for disk.

### Why `bootc-generic-iso` instead of `anaconda-iso`?

We don't have a choice — `bootc-generic-iso` is the only bootc ISO type available in `image-builder-cli`. The `anaconda-iso` type is only in `bootc-image-builder` (BIB), which is broken by the GPG key bug.

**This is a known limitation.** `bootc-generic-iso` does NOT embed the container image into the ISO. Users must have network access to complete installation. The installation will hang trying to download the image if no network is available.

The intended goal is a self-contained ISO using `anaconda-iso`, which embeds the full OS into the squashfs volume.

## Known Limitation: ISO Requires Network

The current ISO uses `bootc-generic-iso` which **does not embed the container image**. The installation process:

1. ISO boots to Anaconda
2. Anaconda presents the installation UI
3. When user proceeds, Anaconda tries to pull the container image from the registry
4. **If no network is available, installation hangs indefinitely**

This is not the desired behavior for a distributable ISO. Users should be able to install offline.

## Recommendations

The goal is a self-contained ISO using `anaconda-iso` which embeds the full OS into the squashfs volume.

### Fix options (pick one)

1. **Use `image-builder-cli` with `anaconda-iso` type and `--force-repo`** — The `image-builder-cli` has `--force-repo` to override repo configurations (e.g., disable GPG checking for `terra-mesa`). Test whether it accepts `anaconda-iso` as a type despite docs saying it's unsupported. BIB is a compatibility wrapper around the unified tool, so this might work.

2. **Use BIB with `--force-repo-dir` if it exists** — Check if newer BIB container tags include the `--force-repo-dir` flag from the unified tool. If so, pass it via `additional-args` to disable GPG checking for the problematic repo.

3. **Fix the GPG key upstream in bazzite** — Change `gpgkey=file:///etc/pki/rpm-gpg/...` to an HTTPS URL in the `terra-mesa` repo config. This is an upstream bazzite/ublue issue.

4. **Wait for upstream BIB fix** — The osbuild/bootc-image-builder#1188 issue is open since Jan 2026. No timeline.

**Option 1 is the most promising immediate path.** The `image-builder-cli` container likely supports `anaconda-iso` internally (since BIB is a compatibility wrapper around it), and `--force-repo` can override the GPG key configuration.

## Key Files Added

| File | Purpose |
|------|---------|
| `Containerfile.iso` | ISO overlay: Anaconda, build tools, systemd configs |
| `iso_config/iso.yaml` | GRUB boot entry and kernel parameters |
| `iso_config/interactive-defaults.ks` | Anaconda kickstart with `bootc install` source |
| `iso_config/anaconda-shell.conf` | logind config for Anaconda shell session |

## Workflow Structure

```
build-disk.yml
├── build-qcow2 (job)
│   └── osbuild/bootc-image-builder-action
│       └── rootfs: btrfs, type: qcow2
│
└── build-iso (job, needs: build-qcow2)
    ├── Pull base image from GHCR
    ├── Build ISO overlay (Containerfile.iso)
    └── Run image-builder-cli
        └── type: bootc-generic-iso
```

## Upstream Issues

- **osbuild/bootc-image-builder#1188**: GPG key `file://` path resolution bug in BIB depsolver. Open since Jan 2026. The `image-builder-cli` migration works around the build failure but introduces the network requirement limitation.
- **osbuild/image-builder**: The unified tool is the future. `bootc-image-builder` is a compatibility wrapper.
- **bazzite/ublue**: The `terra-mesa` repo uses `gpgkey=file://` paths. An upstream fix to use HTTPS URLs would resolve the root cause, but is outside our control.

## Troubleshooting

### "No space left on device" during CI

Both qcow2 and ISO builds are large. If running on GitHub-hosted runners, ensure jobs are sequential (`needs:`) rather than parallel.

### ISO overlay build fails with symlink errors

The bazzite base image already has `default.target` and `autovt@.service` symlinks. Use `ln -sf` to overwrite them, not `ln -s`.

### image-builder-cli "unknown flag: --output"

`image-builder-cli` uses `--output-dir`, not `--output`. The `output` directory must exist before the container runs.

### Installation hangs trying to download image

The ISO was built with `bootc-generic-iso` which requires network access. Switch to `anaconda-iso` type (see Recommendations above).
