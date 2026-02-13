## Context

The whiteblossom-os build system uses a Containerfile, Justfile, and shell hook scripts to build and configure a Bazzite-based Linux image. Three small bugs have been identified through code review -- all are one-line fixes with no architectural implications.

## Goals / Non-Goals

**Goals:**
- Fix the `IMAGE_VENDOR` ARG default in the Containerfile so it resolves correctly
- Correct the misleading error message in the Justfile `format` recipe
- Remove the `set -x` debug artifact from the vscode-extensions user setup hook

**Non-Goals:**
- Adding comprehensive error handling to setup hooks (future work)
- Refactoring the Justfile lint/format recipes
- Addressing the FIXME comment about VSCode GPG check in `20-install-apps.sh`

## Decisions

### Decision 1: Minimal, targeted fixes only

Each fix changes exactly one line. No additional improvements (like adding `set -euo pipefail` to the vscode hook) are bundled in, keeping the change reviewable and low-risk.

**Rationale:** These are correctness fixes. Mixing in enhancements would muddy the intent and increase review burden.

### Decision 2: Match existing patterns

- The Containerfile fix mirrors the working pattern on line 10: `ARG IMAGE_NAME="${IMAGE_NAME:-bazzite-dx}"`
- The Justfile fix mirrors the `lint` recipe's message pattern for `shellcheck`
- Removing `set -x` follows the convention of other hooks in the same directory that don't use trace mode

## Risks / Trade-offs

- [Negligible risk] All three fixes are isolated one-line changes with no behavioral dependencies on each other
- [Trade-off] We chose not to add `set -euo pipefail` to the vscode hook -- this keeps the change minimal but means extension install failures still go unnoticed (existing behavior, not a regression)
