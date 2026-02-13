## ADDED Requirements

### Requirement: Containerfile ARG defaults use correct syntax

The `bazzite-dx/Containerfile` SHALL use proper Dockerfile variable substitution syntax for all ARG defaults. Specifically, `IMAGE_VENDOR` MUST default to `ublue-os` when not provided externally, using `${IMAGE_VENDOR:-ublue-os}` syntax with the `$` prefix.

#### Scenario: IMAGE_VENDOR defaults correctly when not provided

- **WHEN** the Containerfile is built without an external `IMAGE_VENDOR` build arg
- **THEN** `IMAGE_VENDOR` SHALL resolve to `ublue-os`
- **AND** the value SHALL NOT be the literal string `{IMAGE_VENDOR:-ublue-os}`

### Requirement: Justfile format recipe error message names correct tool

The `format` recipe in the Justfile SHALL display an error message referencing `shfmt` (the tool it checks for), not `shellcheck`.

#### Scenario: shfmt not installed

- **WHEN** a user runs the `format` recipe
- **AND** `shfmt` is not installed
- **THEN** the error message SHALL say "shfmt could not be found. Please install it."

### Requirement: User setup hooks run without debug trace

The vscode-extensions user setup hook SHALL NOT enable shell trace mode (`set -x`). Debug output MUST NOT be printed to the user's terminal during login.

#### Scenario: VSCode extensions install during user setup

- **WHEN** the `11-vscode-extensions.sh` hook runs during user login
- **THEN** the script SHALL NOT produce shell trace output on stderr
- **AND** extensions SHALL still be installed normally
