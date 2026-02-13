## Why

The build system has three small but real issues: a typo in the Containerfile that silently breaks the `IMAGE_VENDOR` ARG default, a copy-paste error in the Justfile that shows the wrong tool name in an error message, and a debug trace (`set -x`) left in a user-facing setup hook. Each is a one-line fix with no risk, but together they improve correctness and user experience.

## What Changes

- Fix missing `$` in `bazzite-dx/Containerfile` ARG default so `IMAGE_VENDOR` falls back to `ublue-os` correctly
- Correct the error message in `Justfile`'s `format` recipe from "shellcheck" to "shfmt"
- Remove `set -x` from the vscode-extensions user setup hook to eliminate noisy debug output during login

## Capabilities

### New Capabilities
- `build-correctness`: Fixes to build scripts and Containerfile defaults that ensure the image builds with correct metadata and tooling runs cleanly

### Modified Capabilities
<!-- No existing specs to modify -->

## Impact

- `bazzite-dx/Containerfile`: Fix ARG default syntax
- `Justfile`: Fix error message text
- `bazzite-dx/system_files/usr/share/ublue-os/user-setup.hooks.d/11-vscode-extensions.sh`: Remove debug trace
