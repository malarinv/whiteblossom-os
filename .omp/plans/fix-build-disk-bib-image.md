# Fix build-disk workflow: migrate off dead custom BIB image

## Problem

The `build-disk` workflow (`build-disk.yml`) fails on every run with:

```
Failed to pull image ghcr.io/lorbuschris/bootc-image-builder:20250608: exit code 125
Build process failed: exit code 125
```

**Root cause:** Line 30 sets `BIB_IMAGE` to a custom fork image that no longer exists or is inaccessible:

```yaml
BIB_IMAGE: "ghcr.io/lorbuschris/bootc-image-builder:20250608"
```

This overrides the action's built-in default (`quay.io/centos-bootc/bootc-image-builder:latest`). The comment references upstream PR #954 (now 404/merged), indicating this was a temporary workaround for a bug in the upstream container — which is now resolved.

## Context: bootc-image-builder deprecation

The osbuild project is deprecating the standalone `bootc-image-builder` in favor of a unified `image-builder` CLI. However:

- **Backward compatibility is guaranteed for the full life of RHEL 10.** The `bootc-image-builder` container and CLI continue to work.
- The `osbuild/bootc-image-builder-action` GitHub Action wraps the BIB container and will continue to work. The action is the simplest path — no need to change it.
- From RHEL 9.9/10.3, the BIB container ships a compatibility entry point wrapping `image-builder` internally, so existing `podman run ... bootc-image-builder` invocations keep working.

**No action-level migration is needed right now.** The deprecation only requires migrating to `image-builder` for RHEL 11, which is far off.

## Changes

### File: `.github/workflows/build-disk.yml`

1. **Remove the `BIB_IMAGE` environment variable** (line 30) and its comment. This lets the action use its default builder image (`quay.io/centos-bootc/bootc-image-builder:latest`).

2. **Remove the `builder-image` parameter** from the "Build disk images" step (line 84). Without it, the action uses its built-in default, which is cleaner than relying on an env var.

No other files need changes. The `disk_config/disk.toml` and `disk_config/iso.toml` configs, the Justfile BIB recipes, and the `build.yml` container workflow are all unaffected.

## Verification

1. Push the change as a PR targeting `main` — the `build-disk` workflow triggers on PRs that touch `build-disk.yml`, `disk_config/disk.toml`, or `disk_config/iso.toml`.
2. Confirm both matrix jobs (qcow2, anaconda-iso) pass.
3. Confirm the uploaded artifacts contain the expected files.
