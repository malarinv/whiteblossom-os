# Change Proposal: Add Dual Desktop Support (KDE + GNOME)

## Why

WhiteBlossom OS currently uses Bluefin DX as its base, which provides a GNOME-focused developer experience. However, this system will be used by two users with distinct needs and workflows who may be logged in simultaneously:

**User 1 (GNOME)**: Security and privacy focused user who needs a clean, distraction-free environment with strong privacy controls.

**User 2 (KDE)**: Developer and gamer who prioritizes development tools, gaming performance, and customizability. Security conscious but less privacy-restrictive.

Rather than maintaining separate systems or choosing one desktop over another, we can leverage the Bazzite project's infrastructure to create a unified OS image that supports both KDE Plasma and GNOME desktop environments with appropriate tooling for each user's needs.

This change will:
- Support simultaneous multi-user sessions with different desktop environments
- Provide privacy-focused configurations for GNOME users without impacting KDE functionality
- Leverage Bazzite's gaming-optimized features and developer tools
- Enable security hardening system-wide while keeping privacy controls user-configurable
- Reduce maintenance burden by consolidating into a single image that serves both use cases
- Ensure each desktop environment can be optimized for its primary user's workflow

## What Changes

- **Base Image Migration**: Switch from `ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable` to `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable`
- **Add DX Developer Tools**: Layer Bazzite DX developer tools (since base doesn't include them)
- **Add KDE Packages**: Install KDE Plasma desktop environment and related packages from bazzite-nvidia-open
- **Display Manager Configuration**: Configure GDM to present both GNOME and Plasma session options
- **Desktop-Specific Configurations**: Add configuration files for both desktop environments
- **Build Script Enhancement**: Create modular build scripts for DX tools and KDE installation
- **System Files Organization**: Add desktop-specific system files following bazzite's patterns

### Package Additions

**KDE Plasma Packages** (from bazzite-nvidia-open):
- `plasma-desktop` - Core KDE Plasma desktop
- `sddm` - Display manager for KDE
- `krdp` - KDE remote desktop protocol
- `steamdeck-kde-presets-desktop` - Gaming optimizations for KDE
- `kdeconnectd` - Device connectivity
- `kdeplasma-addons` - Additional plasmoids
- `rom-properties-kf6` - ROM file properties
- `fcitx5-mozc`, `fcitx5-chinese-addons`, `fcitx5-hangul` - Input methods
- `kcm-fcitx5` - Input method configuration
- `kio-extras` - Additional KIO workers
- `krunner-bazaar` - KRunner plugin manager
- `ptyxis` - Terminal emulator (shared with GNOME)

**GNOME Packages** (already present in bazzite-gnome-nvidia-open base):
- GNOME Shell and extensions (pre-installed)
- GDM display manager (pre-installed)
- GNOME-specific applications (pre-installed)

**DX Developer Tools** (from bazzite-dx - exact mirror):
- **Core Tools**: android-tools, bcc, bpftop, bpftrace, flatpak-builder, ccache, nicstat, numactl, podman-machine, podman-tui, python3-ramalama, qemu-kvm, restic, rclone, sysprof, tiptop, usbmuxd, zsh
- **VSCode**: Installed from Microsoft repository
- **Docker**: Full Docker CE suite (docker-ce, docker-ce-cli, docker-buildx-plugin, docker-compose-plugin, containerd.io)
- **ublue-setup-services**: Setup utilities from ublue-os COPR

Note: Bazzite-dx uses a minimal approach - additional dev tools (compilers, language runtimes, editors) are expected to be installed via distrobox/toolbox containers

**Privacy & Security Tools** (for flexible user configuration):
- Privacy-focused browser extensions and configurations (user-installable)
- System-wide security hardening (SELinux, firewall, etc.)
- Privacy tools available but not enforced (users can enable per-session)
- Network filtering/monitoring tools (optional, user-configurable)
- Encrypted communication tools
- Note: Privacy settings will be per-user configurable, not system-enforced

**Networking Tools** (privacy-focused alternatives):
- **Headscale** - Self-hosted Tailscale control server (replaces Tailscale)
  - Installed from [jonathanspw/headscale COPR](https://copr.fedorainfracloud.org/coprs/jonathanspw/headscale/)
  - Provides mesh VPN without relying on Tailscale's commercial servers
  - Full control over coordination server for privacy
- **ZeroTier-One** - Decentralized mesh VPN
  - Installed from [RPMFusion repositories](https://rpmfusion.org/Configuration) (already enabled in Bazzite)
  - Alternative VPN solution for flexible networking
  - Self-hosted network control option available
- **Tailscale removal** - Tailscale (present in Bazzite base) will be removed in favor of Headscale

### Package Management Strategy

**Removal Policy**: Only remove packages that cause actual conflicts, not merely redundant ones.

Packages to **remove** (with clear justification):
- **`tailscale`** - Remove and replace with Headscale
  - Reason: Privacy-focused alternative providing self-hosted control
  - Replacement: Headscale (open-source Tailscale control server)
  - Benefit: No dependency on Tailscale commercial servers

Packages that may need removal (only if they cause conflicts):
- `plasma-discover` - May conflict with GNOME Software if both try to manage packages
  - Will test first; only remove if incompatible
- `plasma-welcome` - May auto-launch on first KDE session
  - Will test first; only remove if creates poor UX
  
Packages to **keep** (previously considered for removal):
- `konsole` - Keep alongside Ptyxis; users may prefer it in KDE
- `kde-partitionmanager` - Keep alongside GNOME Disks; no conflict, users have choice
- Other KDE applications - Keep all unless proven incompatible

## Impact

### Affected Capabilities
- **Desktop Environment**: New multi-desktop capability
- **Display Manager**: Requires intelligent session management
- **Package Management**: Increased image size (~500-800MB additional)

### Affected Files
- `Containerfile` - Base image change to bazzite-gnome-nvidia-open, DX tools and KDE package installation
- `build_files/build.sh` - Enhanced to call DX and KDE installation scripts
- `disk_config/iso.toml` - ISO configuration update with new image reference
- New files to add:
  - `build_files/desktop/install-dx-tools.sh` - DX developer tools installation
  - `build_files/desktop/install-kde-packages.sh` - KDE-specific installation logic
  - `system_files/kde/` - KDE configuration files
  - `system_files/shared/` - Shared desktop configurations

### Breaking Changes
- **BREAKING**: Base image switch from Bluefin to Bazzite changes update path and ecosystem
  - Users will need to `bootc switch` to the new image explicitly
  - Bluefin-specific customizations and workflows will not carry over
  - System customizations may need review and re-application
- **BREAKING**: NVIDIA driver type changes from proprietary (if using Bluefin DX with proprietary) to nvidia-open
  - May have different performance characteristics
  - Some proprietary NVIDIA features may not be available in open driver
- **BREAKING**: Image size increase (estimated +1-1.5GB) may impact slow network connections
  - DX tools add ~500-700MB
  - KDE Plasma adds ~500-800MB
- Display manager remains GDM (same as before), but now shows both session types

### Migration Path
For existing users:
```bash
# Switch to new dual-desktop image
sudo bootc switch ghcr.io/malarinv/whiteblossom-os:latest
sudo systemctl reboot

# After reboot, select desktop at login screen
# GDM will show both "GNOME" and "Plasma" session options
```

### Benefits
- Users can switch desktop environments without reinstalling
- Access to Bazzite's gaming optimizations and hardware support
- Bazzite-DX developer tools retained
- Better hardware support (especially for handheld devices, Framework laptops)
- Gaming-focused optimizations (Gamescope, Steam integration, controller support)

### Risks
- Larger image size increases download time and disk usage
- Potential conflicts between GNOME and KDE packages
- Increased maintenance complexity with two desktop environments
- Some desktop-specific features may not work optimally in the other environment

### Testing Requirements
- Verify both desktop environments boot successfully
- Test switching between GNOME and KDE sessions
- Validate NVIDIA drivers work with both desktops
- Ensure developer tools (from DX) work in both environments
- Test VM image builds (QCOW2/ISO) with both desktops
- Verify existing customizations still work

### Implementation Notes

**DX Tools Package List Alignment**:
Initial implementation included ~50 additional packages (gcc, nodejs, rust, neovim, databases, etc.) that are NOT in bazzite-dx. After reviewing the actual bazzite-dx source, the package list was corrected to exactly mirror bazzite-dx's minimal approach:
- **Only 18 core packages from Fedora repos** (android-tools, bcc, bpftop, bpftrace, flatpak-builder, ccache, nicstat, numactl, podman-machine, podman-tui, python3-ramalama, qemu-kvm, restic, rclone, sysprof, tiptop, usbmuxd, zsh)
- **VSCode from Microsoft repo** (same as bazzite-dx)
- **Docker CE suite from Docker repo** (same as bazzite-dx)
- **ublue-setup-services from COPR** (same as bazzite-dx)

Bazzite-dx intentionally keeps the base image minimal - developers are expected to use distrobox/toolbox containers for language-specific toolchains and additional development tools. This reduces base image size and provides better isolation.

**Package Availability Notes**:
Some packages considered during initial implementation were not available in Fedora 43 repositories (eza, terraform, kubectl, universal-ctags). However, these were removed anyway during alignment with bazzite-dx's actual package list.

**Build Script Adjustments**:
- Modified `build_files/build.sh` to execute scripts with `bash` directly instead of using `chmod +x`, as the container mount context is read-only
- All package installations validated against Fedora 43 repository availability
- External repositories (VSCode, Docker) configured exactly as bazzite-dx does
- Fixed package name typo in KDE installation: `plasma-welcomekmix` → `plasma-welcome` + `kmix` (separate packages)
- Removed `khotkeys` - deprecated in Plasma 6 (Fedora 43), functionality now integrated into System Settings

