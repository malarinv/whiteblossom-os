# Build System Specification

## ADDED Requirements

### Requirement: Bazzite Base Image Integration

The build system SHALL use Bazzite DX GNOME NVIDIA as the foundation image for WhiteBlossom OS.

#### Scenario: Containerfile specifies correct base image
- **WHEN** the Containerfile is parsed
- **THEN** the FROM statement SHALL reference `ghcr.io/ublue-os/bazzite-dx-nvidia-gnome:stable`
- **AND** the image SHALL pull successfully from GitHub Container Registry
- **AND** all Bazzite DX features SHALL be inherited

#### Scenario: Base image updates are tracked
- **WHEN** Bazzite releases a new stable version
- **THEN** WhiteBlossom OS SHALL be able to rebuild with the updated base
- **AND** CI/CD pipeline SHALL detect base image changes
- **AND** build process SHALL complete successfully with new base

### Requirement: Desktop Package Installation Scripts

The build system SHALL provide modular scripts for installing desktop environment packages.

#### Scenario: KDE installation script exists
- **WHEN** build process executes
- **THEN** `build_files/desktop/install-kde-packages.sh` SHALL be available
- **AND** script SHALL install all required KDE packages
- **AND** script SHALL remove conflicting packages
- **AND** script SHALL complete without errors

#### Scenario: Desktop scripts execute in correct order
- **WHEN** main build script runs
- **THEN** base system files SHALL be copied first
- **AND** KDE package installation SHALL run after base setup
- **AND** desktop configurations SHALL be applied last
- **AND** each step SHALL log output for debugging

### Requirement: System Files Organization

The build system SHALL organize system files by desktop environment.

#### Scenario: Desktop-specific directories exist
- **WHEN** repository is cloned
- **THEN** `system_files/kde/` directory SHALL exist
- **AND** `system_files/gnome/` directory SHALL exist
- **AND** `system_files/shared/` directory SHALL exist for common configs

#### Scenario: System files are copied correctly
- **WHEN** container build executes system file copying
- **THEN** shared files SHALL be copied to system first
- **AND** GNOME files SHALL be copied next (if any overrides)
- **AND** KDE files SHALL be copied last
- **AND** file permissions SHALL be preserved

### Requirement: Build Script Modularity

The build system SHALL support modular, maintainable build scripts following Bazzite patterns.

#### Scenario: Build scripts follow naming convention
- **WHEN** examining build_files directory
- **THEN** scripts SHALL use numeric prefixes (00-, 20-, 40-, etc.)
- **AND** scripts SHALL have descriptive names after prefix
- **AND** scripts SHALL execute in numeric order
- **AND** script execution SHALL be logged clearly

#### Scenario: Build scripts use proper error handling
- **WHEN** any build script executes
- **THEN** script SHALL use `set -eoux pipefail` for strict error handling
- **AND** script SHALL fail immediately on any error
- **AND** script SHALL log each command as it executes
- **AND** build failure SHALL provide clear error context

### Requirement: Container Layer Optimization

The build system SHALL optimize container layers for efficient storage and transfer.

#### Scenario: Cache mounts are used effectively
- **WHEN** Containerfile RUN commands execute
- **THEN** DNF cache SHALL be mounted at `/var/cache`
- **AND** logs SHALL be mounted at `/var/log`
- **AND** temporary files SHALL use tmpfs mounts
- **AND** mounts SHALL reduce layer size

#### Scenario: Cleanup runs after package operations
- **WHEN** packages are installed via DNF
- **THEN** cleanup script SHALL remove temporary files
- **AND** DNF cache SHALL be managed appropriately
- **AND** log files SHALL be truncated
- **AND** layer size SHALL be minimized

### Requirement: Build Validation

The build system SHALL validate the resulting container image meets bootc requirements.

#### Scenario: bootc container lint passes
- **WHEN** container build completes
- **THEN** `bootc container lint` command SHALL execute
- **AND** all lint checks SHALL pass
- **AND** image SHALL be bootable
- **AND** OSTree commit SHALL be valid

#### Scenario: Image metadata is correct
- **WHEN** image is built
- **THEN** image labels SHALL include version information
- **AND** image labels SHALL include git SHA (if tree clean)
- **AND** image labels SHALL include build date
- **AND** metadata SHALL be queryable via Podman/Docker

### Requirement: Multi-Stage Build Process

The build system SHALL use multi-stage builds for clean separation of build context.

#### Scenario: Build context is isolated
- **WHEN** Containerfile uses multi-stage build
- **THEN** scratch stage SHALL contain only necessary files
- **AND** build_files SHALL be mounted not copied
- **AND** system_files SHALL be in build context
- **AND** final image SHALL not contain build artifacts

#### Scenario: Build stages are clearly defined
- **WHEN** examining Containerfile
- **THEN** context stage (FROM scratch) SHALL be first
- **AND** main build stage SHALL reference bazzite base
- **AND** each stage SHALL have clear purpose
- **AND** stage transitions SHALL be documented

### Requirement: ISO Configuration

The build system SHALL generate bootable ISOs with correct configuration.

#### Scenario: ISO TOML references correct image
- **WHEN** `disk_config/iso.toml` is read
- **THEN** bootc switch command SHALL point to `ghcr.io/malarinv/whiteblossom-os:latest`
- **AND** Anaconda modules SHALL be configured correctly
- **AND** storage module SHALL be enabled
- **AND** unnecessary modules SHALL be disabled

#### Scenario: ISO build process succeeds
- **WHEN** `just build-iso` command is executed
- **THEN** bootc-image-builder SHALL create ISO successfully
- **AND** ISO SHALL be bootable in VMs
- **AND** ISO SHALL install system correctly
- **AND** installed system SHALL match container image

### Requirement: Local Development Workflow

The build system SHALL support efficient local development and testing.

#### Scenario: Local build is fast
- **WHEN** developer runs `just build`
- **THEN** Podman SHALL use layer caching
- **AND** unchanged layers SHALL not rebuild
- **AND** build SHALL complete in reasonable time (< 30 min)
- **AND** build progress SHALL be visible

#### Scenario: VM testing is straightforward
- **WHEN** developer wants to test changes
- **THEN** `just build-qcow2` SHALL create test image
- **AND** `just run-vm-qcow2` SHALL boot image in QEMU
- **AND** developer SHALL see boot process
- **AND** desktop selection SHALL be testable

### Requirement: CI/CD Integration

The build system SHALL integrate with GitHub Actions for automated builds.

#### Scenario: GitHub workflow builds successfully
- **WHEN** code is pushed to main branch
- **THEN** GitHub Actions workflow SHALL trigger
- **AND** container image SHALL build in CI
- **AND** image SHALL be pushed to GHCR
- **AND** image SHALL be signed with cosign

#### Scenario: Build failures are visible
- **WHEN** build error occurs in CI
- **THEN** workflow SHALL fail with clear error message
- **AND** logs SHALL be available in GitHub Actions
- **AND** specific failing step SHALL be identifiable
- **AND** developer SHALL be able to reproduce locally

### Requirement: Reproducible Builds

The build system SHALL produce reproducible builds given the same source code and base image.

#### Scenario: Builds are deterministic
- **WHEN** same commit is built twice
- **THEN** resulting images SHALL be functionally identical
- **AND** package versions SHALL match (for locked packages)
- **AND** configuration files SHALL be identical
- **AND** layer hashes MAY differ (due to timestamps) but content SHALL match

#### Scenario: Build environment is documented
- **WHEN** examining repository
- **THEN** all build dependencies SHALL be documented
- **AND** Devbox configuration SHALL specify tool versions
- **AND** Containerfile SHALL specify base image version
- **AND** build process SHALL be repeatable by others

### Requirement: Ostree Commit Management

The build system SHALL properly commit changes to OSTree for atomic updates.

#### Scenario: OSTree commit is created
- **WHEN** modifications are complete in container build
- **THEN** `ostree container commit` SHALL execute
- **AND** commit SHALL include all filesystem changes
- **AND** commit metadata SHALL be valid
- **AND** commit SHALL be bootable via bootc

#### Scenario: Initramfs is rebuilt
- **WHEN** kernel or drivers are modified
- **THEN** initramfs rebuild script SHALL execute
- **AND** new initramfs SHALL include necessary modules
- **AND** initramfs SHALL support both desktops
- **AND** boot process SHALL use new initramfs

### Requirement: Documentation Integration

The build system SHALL include inline documentation for maintainability.

#### Scenario: Containerfile has clear comments
- **WHEN** reading Containerfile
- **THEN** each major section SHALL have explanatory comments
- **AND** package groups SHALL be documented
- **AND** non-obvious decisions SHALL be explained
- **AND** Bazzite-specific patterns SHALL be noted

#### Scenario: Build scripts have headers
- **WHEN** reading build scripts
- **THEN** each script SHALL have description comment
- **AND** script purpose SHALL be clear
- **AND** required environment variables SHALL be documented
- **AND** error conditions SHALL be noted

