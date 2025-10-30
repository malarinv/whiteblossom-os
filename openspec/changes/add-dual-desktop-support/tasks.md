# Implementation Tasks: Add Dual Desktop Support

## 1. Base Image Migration

- [x] 1.1 Update Containerfile to use `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable` as base image
- [x] 1.2 Verify base image uses nvidia-open drivers (not proprietary)
- [x] 1.3 Update `disk_config/iso.toml` with new image registry path
- [x] 1.4 Update README.md with new base image information
- [ ] 1.5 Test base image pulls successfully

## 2. Directory Structure Setup

- [ ] 2.1 Create `build_files/desktop/` directory for desktop-specific scripts
- [ ] 2.2 Create `system_files/kde/` directory for KDE configuration files
- [ ] 2.3 Create `system_files/gnome/` directory for GNOME-specific configurations
- [ ] 2.4 Create `system_files/shared/` directory for cross-desktop configurations

## 3. DX Developer Tools Installation

- [ ] 3.1 Inspect bazzite-dx Containerfile to identify DX-specific packages
- [ ] 3.2 Create `build_files/desktop/install-dx-tools.sh` script
- [ ] 3.3 Add development IDEs and tools from bazzite-dx
- [ ] 3.4 Add container development tooling
- [ ] 3.5 Add language runtimes and SDKs
- [ ] 3.6 Add any DX-specific system configurations
- [ ] 3.7 Test DX tools are accessible and functional
- [ ] 3.8 Document which DX packages were added

## 4. KDE Package Installation

- [ ] 4.1 Create `build_files/desktop/install-kde-packages.sh` script
- [ ] 4.2 Add KDE Plasma core packages installation (reference bazzite-nvidia-open)
- [ ] 4.3 Add KDE applications and utilities
- [ ] 4.4 Add input method packages (fcitx5)
- [ ] 4.5 Add KDE-specific gaming optimizations
- [ ] 4.6 Test for actual package conflicts (don't preemptively remove)
- [ ] 4.7 Remove only truly conflicting packages (document reason)
- [ ] 4.8 Test package installation completes without errors

## 5. Display Manager Configuration

- [ ] 5.1 Ensure GDM is configured (already present from base)
- [ ] 5.2 Optionally install SDDM for users who prefer it with KDE
- [ ] 5.3 Ensure GDM shows both GNOME and Plasma session options
- [ ] 5.4 Test login screen session selector works correctly
- [ ] 5.5 Verify switching between desktops persists user choice

## 6. Desktop Environment Configurations

- [ ] 6.1 Copy KDE configuration files from bazzite repo
- [ ] 6.2 Set up KDE global shortcuts (including Ptyxis Ctrl+Alt+T)
- [ ] 6.3 Configure KDE taskbar with gaming-focused defaults
- [ ] 6.4 Configure KDE application menu with proper favorites
- [ ] 6.5 Set up desktop backgrounds for both environments
- [ ] 6.6 Configure dconf settings for KDE compatibility
- [ ] 6.7 Validate gschema overrides compile correctly

## 7. Build Script Updates

- [ ] 7.1 Update main `build_files/build.sh` to call DX tools installation
- [ ] 7.2 Update main `build_files/build.sh` to call KDE installation  
- [ ] 7.3 Ensure proper script execution order (base → DX → KDE)
- [ ] 7.4 Add error handling for package conflicts
- [ ] 7.5 Test build script runs successfully

## 8. System Services Configuration

- [ ] 8.1 Enable required systemd services for both desktops
- [ ] 8.2 Disable conflicting services (if any identified)
- [ ] 8.3 Configure session-specific autostart files
- [ ] 8.4 Test services start correctly on both desktops

## 9. Terminal Integration

- [ ] 9.1 Verify Ptyxis works in both GNOME and KDE (already in base)
- [ ] 9.2 Set up Ptyxis keyboard shortcuts for KDE (Ctrl+Alt+T)
- [ ] 9.3 Add Ptyxis to KDE global accelerators
- [ ] 9.4 Keep Konsole available for KDE users who prefer it
- [ ] 9.5 Test terminal launches correctly in both environments

## 10. Containerfile Optimization

- [ ] 10.1 Organize package installations by category
- [ ] 10.2 Use cache mounts for faster rebuilds
- [ ] 10.3 Minimize layer count where possible
- [ ] 10.4 Add comments explaining DX and KDE additions
- [ ] 10.5 Run `bootc container lint` validation

## 11. Privacy and Security Configuration

- [ ] 11.1 Verify SELinux is enabled and enforcing
- [ ] 11.2 Configure firewall with sensible defaults
- [ ] 11.3 Ensure security updates are enabled
- [ ] 11.4 Add privacy tools to package list (optional installs)
- [ ] 11.5 Include browser privacy extensions (pre-installed, user-enables)
- [ ] 11.6 Add VPN tools to available packages
- [ ] 11.7 Configure DNS-over-HTTPS as user-optional
- [ ] 11.8 Disable telemetry by default (Fedora standard)
- [ ] 11.9 Document privacy configuration options for GNOME users
- [ ] 11.10 Document security hardening features
- [ ] 11.11 Test user separation and privacy isolation

## 11a. Networking Tools Configuration

- [ ] 11a.1 Remove Tailscale package from base image
- [ ] 11a.2 Disable Tailscale systemd service (if was enabled)
- [ ] 11a.3 Verify RPMFusion repositories are enabled (should be from Bazzite base)
- [ ] 11a.4 Add jonathanspw/headscale COPR repository
- [ ] 11a.5 Install Headscale from COPR
- [ ] 11a.6 Configure Headscale systemd service (disabled by default, user-enables)
- [ ] 11a.7 Add Headscale example configuration at `/etc/headscale/config.yaml`
- [ ] 11a.8 Install ZeroTier-One from RPMFusion repositories
- [ ] 11a.9 Configure ZeroTier service (disabled by default, user-enables)
- [ ] 11a.10 Document Headscale setup and benefits vs Tailscale
- [ ] 11a.11 Document ZeroTier as alternative mesh VPN option
- [ ] 11a.12 Test Headscale service can start and function correctly
- [ ] 11a.13 Test ZeroTier service can start and function correctly
- [ ] 11a.14 Verify Tailscale is completely removed and doesn't conflict

## 12. Testing & Validation

- [ ] 12.1 Build container image locally with `just build`
- [ ] 12.2 Create QCOW2 test image with `just build-qcow2`
- [ ] 12.3 Test boot into GNOME session
- [ ] 12.4 Test boot into KDE Plasma session
- [ ] 12.5 Test switching between sessions
- [ ] 12.6 Test simultaneous multi-user login (critical!)
- [ ] 12.7 Test resource usage with both users logged in
- [ ] 12.8 Verify nvidia-open drivers work in both desktops
- [ ] 12.9 Verify DX developer tools function correctly in both environments
- [ ] 12.10 Test gaming features (Steam, Lutris) in both desktops
- [ ] 12.11 Test gaming performance with other user logged in
- [ ] 12.12 Verify Wayland works correctly in both environments
- [ ] 12.13 Test X11 fallback if needed
- [ ] 12.14 Verify NVIDIA-specific features work with open drivers
- [ ] 12.15 Test privacy controls in GNOME session
- [ ] 12.16 Verify users cannot access each other's data
- [ ] 12.17 Test system stability under load (both users active)

## 13. Documentation Updates

- [ ] 13.1 Update README.md with dual desktop and nvidia-open driver information
- [ ] 13.2 Add desktop switching instructions
- [ ] 13.3 Document multi-user scenario and requirements
- [ ] 13.4 Document hardware requirements (16GB RAM min, 32GB recommended)
- [ ] 13.5 Add privacy configuration guide for GNOME users
- [ ] 13.6 Document security features enabled by default
- [ ] 13.7 Note nvidia-open vs proprietary driver differences
- [ ] 13.8 Add screenshots of both desktop environments
- [ ] 13.9 Update project.md with new capabilities and multi-user context
- [ ] 13.10 Document known limitations or caveats

## 14. CI/CD Updates

- [ ] 14.1 Verify GitHub Actions workflow builds successfully with new base
- [ ] 14.2 Update build workflow labels/tags if needed
- [ ] 14.3 Test ISO generation with new configuration
- [ ] 14.4 Verify container signing works

## 15. Migration Guide Creation

- [ ] 15.1 Write migration guide for existing users
- [ ] 15.2 Document `bootc switch` command with new image path
- [ ] 15.3 Explain Bluefin → Bazzite transition
- [ ] 15.4 Explain proprietary → nvidia-open driver switch (if applicable)
- [ ] 15.5 List potential issues and solutions
- [ ] 15.6 Add rollback instructions

## Notes

- Prioritize tasks 1-5 as they form the core functionality
- Tasks 6-10 are essential for proper integration
- Section 11 (Privacy/Security) is critical for the two-user scenario
- Section 12 (Testing) must include multi-user simultaneous login tests
- Tasks 13-15 ensure quality, usability, and proper documentation
- Test thoroughly in VM with two simultaneous user sessions before deploying to physical hardware
- Each desktop should feel native and not compromised by the other's presence
- System must handle both users logged in simultaneously without performance degradation
- Privacy controls should be available but not enforced system-wide
- Recommend testing with realistic workloads: gaming + development + privacy tools active

