# Desktop Environment Specification

## ADDED Requirements

### Requirement: Dual Desktop Environment Support

The system SHALL provide both GNOME and KDE Plasma desktop environments in a single OS image, allowing users to choose their preferred desktop at login.

#### Scenario: User selects GNOME session at login
- **WHEN** a user boots the system
- **AND** reaches the display manager login screen
- **THEN** they SHALL see "GNOME" as an available session option
- **AND** selecting GNOME SHALL start a full GNOME desktop environment
- **AND** all GNOME-specific features SHALL function correctly

#### Scenario: User selects KDE Plasma session at login
- **WHEN** a user boots the system
- **AND** reaches the display manager login screen
- **THEN** they SHALL see "Plasma" as an available session option
- **AND** selecting Plasma SHALL start a full KDE Plasma desktop environment
- **AND** all KDE-specific features SHALL function correctly

#### Scenario: User switches between desktop environments
- **WHEN** a user is logged into GNOME
- **AND** they log out
- **THEN** they SHALL be able to select Plasma for the next session
- **AND** their user settings for each desktop SHALL be preserved independently
- **AND** switching SHALL complete within 30 seconds

### Requirement: KDE Plasma Installation

The system SHALL include a complete KDE Plasma desktop environment with gaming optimizations.

#### Scenario: KDE packages are installed
- **WHEN** the container image is built
- **THEN** plasma-desktop MUST be installed
- **AND** sddm display manager MUST be installed
- **AND** gaming-specific packages (steamdeck-kde-presets-desktop) MUST be installed
- **AND** KDE applications (dolphin, kate, etc.) MUST be available

#### Scenario: KDE configuration files are present
- **WHEN** a user logs into KDE for the first time
- **THEN** taskbar SHALL be pre-configured with gaming applications
- **AND** application launcher SHALL have appropriate favorites
- **AND** desktop wallpaper SHALL be set to Bazzite convergence theme
- **AND** keyboard shortcuts SHALL include Ctrl+Alt+T for terminal

### Requirement: GNOME Desktop Retention

The system SHALL maintain full GNOME desktop functionality from the bazzite-dx-nvidia-gnome base image.

#### Scenario: GNOME environment is functional
- **WHEN** a user selects GNOME session
- **THEN** all GNOME Shell extensions SHALL load correctly
- **AND** GNOME-specific applications SHALL be available
- **AND** GDM settings SHALL be preserved
- **AND** developer tools from Bazzite DX SHALL function normally

#### Scenario: GNOME-specific optimizations remain
- **WHEN** running GNOME session
- **THEN** Bazzite GNOME presets SHALL be applied
- **AND** GNOME gaming optimizations SHALL be active
- **AND** GNOME extensions for gaming SHALL function

### Requirement: Display Manager Configuration

The system SHALL intelligently manage display managers for both desktop environments.

#### Scenario: Display manager shows both sessions
- **WHEN** system boots to login screen
- **THEN** both GNOME and Plasma sessions SHALL be visible in session selector
- **AND** session icons SHALL be clearly identifiable
- **AND** last used session SHALL be pre-selected by default

#### Scenario: SDDM configuration for KDE
- **WHEN** SDDM is used as display manager
- **THEN** SDDM theme SHALL match system aesthetics
- **AND** SDDM SHALL support Wayland sessions
- **AND** user avatars SHALL display correctly

#### Scenario: GDM configuration for GNOME
- **WHEN** GDM is used as display manager
- **THEN** GDM SHALL maintain Bazzite branding
- **AND** GDM SHALL support both GNOME and Plasma sessions
- **AND** accessibility features SHALL work correctly

### Requirement: Shared Application Support

The system SHALL provide applications that work well in both desktop environments.

#### Scenario: Cross-desktop terminal usage
- **WHEN** user is in either GNOME or KDE
- **AND** they press Ctrl+Alt+T
- **THEN** Ptyxis terminal SHALL launch
- **AND** terminal SHALL integrate with the current desktop's theme

#### Scenario: File manager integration
- **WHEN** user opens file manager in GNOME
- **THEN** Nautilus SHALL be used
- **WHEN** user opens file manager in KDE
- **THEN** Dolphin SHALL be used
- **AND** both SHALL handle file associations correctly

### Requirement: Developer Tools Compatibility

The system SHALL ensure Bazzite DX developer tools function in both desktop environments.

#### Scenario: Developer tools in GNOME
- **WHEN** user is in GNOME session
- **THEN** all DX developer tools SHALL be accessible
- **AND** IDE integrations SHALL work correctly
- **AND** container tools SHALL function normally

#### Scenario: Developer tools in KDE
- **WHEN** user is in KDE Plasma session
- **THEN** all DX developer tools SHALL be accessible
- **AND** IDE integrations SHALL work correctly
- **AND** container tools SHALL function normally

### Requirement: Gaming Features Parity

The system SHALL provide gaming features in both desktop environments.

#### Scenario: Steam integration in both desktops
- **WHEN** Steam is launched in either desktop
- **THEN** Bazzite Steam wrapper SHALL be used
- **AND** Gamescope SHALL be available
- **AND** controller support SHALL function
- **AND** Steam Big Picture Mode SHALL work

#### Scenario: Lutris in both desktops
- **WHEN** Lutris is launched in either desktop
- **THEN** game runners SHALL be properly configured
- **AND** wine/proton integration SHALL work
- **AND** game library SHALL be accessible

### Requirement: NVIDIA Driver Compatibility

The system SHALL ensure NVIDIA drivers work correctly with both desktop environments.

#### Scenario: NVIDIA in GNOME session
- **WHEN** user logs into GNOME with NVIDIA GPU
- **THEN** proprietary NVIDIA drivers SHALL be active
- **AND** Wayland SHALL use NVIDIA-specific configurations
- **AND** GPU acceleration SHALL work for all applications

#### Scenario: NVIDIA in KDE session
- **WHEN** user logs into KDE Plasma with NVIDIA GPU
- **THEN** proprietary NVIDIA drivers SHALL be active
- **AND** Wayland SHALL use NVIDIA-specific configurations
- **AND** Plasma effects SHALL utilize GPU acceleration

### Requirement: Configuration Isolation

The system SHALL keep desktop environment configurations isolated to prevent conflicts.

#### Scenario: KDE settings don't affect GNOME
- **WHEN** user modifies KDE settings
- **THEN** GNOME settings SHALL remain unchanged
- **AND** switching to GNOME SHALL show original GNOME configuration

#### Scenario: GNOME settings don't affect KDE
- **WHEN** user modifies GNOME settings
- **THEN** KDE settings SHALL remain unchanged
- **AND** switching to KDE SHALL show original KDE configuration

#### Scenario: User data is shared
- **WHEN** user saves files in either desktop
- **THEN** files SHALL be accessible from both desktops
- **AND** home directory permissions SHALL be consistent
- **AND** application data SHALL be shared where appropriate

### Requirement: System Resource Management

The system SHALL manage resources efficiently with both desktops installed.

#### Scenario: Image size is acceptable
- **WHEN** container image is built
- **THEN** total image size SHALL be less than 12 GB
- **AND** size increase from KDE additions SHALL be less than 1 GB

#### Scenario: Only active desktop consumes resources
- **WHEN** user logs into GNOME
- **THEN** KDE services SHALL NOT be running
- **AND** memory usage SHALL be comparable to GNOME-only system
- **WHEN** user logs into KDE
- **THEN** GNOME services SHALL NOT be running
- **AND** memory usage SHALL be comparable to KDE-only system

### Requirement: Multi-User Simultaneous Sessions

The system SHALL support multiple users logged in simultaneously with different desktop environments without performance degradation.

#### Scenario: Two users logged in at same time
- **WHEN** User 1 logs into GNOME session
- **AND** User 2 logs into KDE Plasma session
- **THEN** both sessions SHALL run concurrently
- **AND** neither session SHALL experience significant performance degradation
- **AND** each session SHALL remain responsive under normal workload

#### Scenario: Resource isolation between users
- **WHEN** multiple users are logged in
- **THEN** each user's session SHALL run in separate cgroup
- **AND** users SHALL NOT be able to access each other's files (standard Linux permissions)
- **AND** one user's heavy workload SHALL NOT completely freeze other sessions
- **AND** system SHALL remain stable under load

#### Scenario: Gaming with other user logged in
- **WHEN** User 2 plays a demanding game in KDE session
- **AND** User 1 is logged into GNOME performing lightweight tasks
- **THEN** game SHALL maintain acceptable performance
- **AND** User 1's session SHALL remain responsive for basic tasks
- **AND** system SHALL NOT become unresponsive

### Requirement: Privacy and Security Configuration

The system SHALL provide system-wide security hardening with user-configurable privacy controls.

#### Scenario: System-wide security is enforced
- **WHEN** system boots
- **THEN** SELinux SHALL be enabled and enforcing
- **AND** firewall SHALL be configured and active
- **AND** security updates SHALL be enabled
- **AND** all users SHALL benefit from security hardening

#### Scenario: Per-user privacy controls are available
- **WHEN** privacy-focused user logs into GNOME
- **THEN** privacy tools SHALL be available for installation
- **AND** browser privacy extensions SHALL be pre-installed but user-enabled
- **AND** VPN tools SHALL be available in package manager
- **AND** user SHALL be able to configure DNS-over-HTTPS

#### Scenario: Privacy settings don't affect other users
- **WHEN** User 1 enables strict privacy controls in their account
- **THEN** User 2's account SHALL NOT be affected
- **AND** User 2 SHALL maintain full functionality for gaming and development
- **AND** system-wide services SHALL NOT be restricted

#### Scenario: Developer and gaming functionality preserved
- **WHEN** developer user needs full access to development tools
- **THEN** no system-wide privacy restrictions SHALL block development workflows
- **AND** gaming services SHALL function normally
- **AND** network access for games and development SHALL work correctly

### Requirement: Privacy-Focused Mesh VPN

The system SHALL provide self-hosted mesh VPN solutions instead of commercial alternatives.

#### Scenario: Tailscale is removed
- **WHEN** image is built
- **THEN** Tailscale package SHALL be removed from base image
- **AND** Tailscale systemd service SHALL NOT be present
- **AND** Tailscale repository SHALL be removed

#### Scenario: Headscale is installed
- **WHEN** image is built
- **THEN** Headscale package SHALL be installed from jonathanspw/headscale COPR
- **AND** Headscale systemd service SHALL be available but disabled by default
- **AND** Headscale configuration file SHALL exist at `/etc/headscale/config.yaml`
- **AND** Headscale SHALL be compatible with Tailscale clients

#### Scenario: ZeroTier is available
- **WHEN** image is built
- **THEN** ZeroTier-One package SHALL be installed from RPMFusion repositories
- **AND** ZeroTier service SHALL be available but disabled by default
- **AND** users SHALL be able to enable and configure ZeroTier

#### Scenario: User configures mesh VPN
- **WHEN** privacy-focused user wants to set up mesh VPN
- **THEN** they SHALL be able to enable Headscale service
- **AND** they SHALL have full control over coordination server
- **AND** no data SHALL be sent to commercial Tailscale servers
- **WHEN** user prefers ZeroTier
- **THEN** they SHALL be able to use ZeroTier instead
- **AND** both VPN solutions SHALL be able to coexist if needed

### Requirement: Hardware Requirements Documentation

The system SHALL clearly document hardware requirements for multi-user scenarios.

#### Scenario: Minimum requirements are met
- **WHEN** system has 16GB RAM and modern multi-core CPU
- **THEN** two users SHALL be able to log in simultaneously
- **AND** system SHALL remain functional under light to moderate load
- **AND** basic gaming and development SHALL work

#### Scenario: Recommended requirements provide optimal experience
- **WHEN** system has 32GB RAM and 6+ core CPU
- **THEN** two users SHALL have smooth, responsive sessions
- **AND** demanding games and development workloads SHALL run well
- **AND** neither user SHALL notice significant slowdown from the other

### Requirement: Base Image Compatibility

The system SHALL maintain compatibility with Bazzite ecosystem updates.

#### Scenario: Updates from Bazzite upstream
- **WHEN** Bazzite releases an update to bazzite-gnome-nvidia-open
- **THEN** WhiteBlossom OS SHALL be able to rebuild with the new base
- **AND** all customizations SHALL remain functional
- **AND** update SHALL complete without manual intervention

#### Scenario: Bootc upgrade path
- **WHEN** system checks for updates via bootc
- **THEN** new WhiteBlossom OS images SHALL be detected
- **AND** upgrade SHALL preserve user data
- **AND** rollback to previous version SHALL be available

