# Design: Dual Desktop Environment Support

## Context

WhiteBlossom OS currently builds on Universal Blue's Bluefin DX, which provides a GNOME-centric developer experience. The goal is to add KDE Plasma support while retaining full GNOME functionality, creating a dual-desktop system that leverages Bazzite's gaming optimizations and hardware support.

This design leverages existing work from the Bazzite project, which already supports both KDE (Kinoite-based) and GNOME (Silverblue-based) variants. Rather than maintaining separate images, we consolidate both desktops into a single image.

**Multi-User Scenario:**
This system will be used by two users who may be logged in simultaneously:

1. **User 1 (GNOME)**: Privacy and security focused
   - Needs minimal attack surface
   - Requires strong privacy controls (tracking blockers, secure browsing)
   - Prefers clean, distraction-free interface
   - Uses system primarily for sensitive work

2. **User 2 (KDE)**: Developer and gamer
   - Needs full developer toolchain
   - Requires gaming performance and optimizations
   - Values customizability and advanced features
   - Security conscious but less privacy-restrictive
   - May run resource-intensive applications

**Key Stakeholders:**
- Privacy-focused user requiring secure GNOME environment
- Developer/gamer requiring feature-rich KDE environment with DX tools
- Both users needing secure system foundation
- System administrator wanting single maintainable image

**Constraints:**
- Must maintain compatibility with Bazzite upstream updates
- Image size must remain reasonable (< 12 GB compressed)
- Both desktops must feel native, not compromised
- NVIDIA driver support must work flawlessly in both
- Developer tools from DX base must work in both environments
- **Multi-user performance**: Both users may be logged in simultaneously
- **Resource isolation**: Sessions should not interfere with each other
- **Security**: System-wide hardening without compromising functionality
- **Privacy**: User-configurable, not system-enforced (respects different needs)

## Goals / Non-Goals

### Goals
- Provide both GNOME and KDE Plasma in a single bootable image
- Support simultaneous multi-user sessions without performance degradation
- Enable privacy-focused configuration for GNOME users (user-controlled)
- Provide full developer tooling and gaming optimizations for KDE users
- Implement system-wide security hardening that works for both users
- Leverage Bazzite's gaming optimizations and DX developer tools
- Ensure seamless switching between desktops via login screen
- Keep user configurations and privacy settings isolated per-account
- Optimize resource usage for concurrent sessions
- Follow Bazzite's proven patterns for desktop integration

### Non-Goals
- Creating a hybrid desktop environment (no GNOME apps in KDE menus by default, etc.)
- Enforcing system-wide privacy restrictions that limit functionality
- Supporting other desktop environments (XFCE, Cinnamon, etc.) at this time
- Maintaining separate GNOME-only and KDE-only image variants
- Deep customization of either desktop's default experience
- Optimizing for minimal image size (prioritize functionality and performance over size)
- Managing user conflicts or access controls (handled by standard Linux multi-user)
- Implementing parental controls or user activity monitoring

## Decisions

### Decision 1: Base Image Selection

**Choice:** Use `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable` as base image and layer DX tools on top

**Rationale:**
- Provides nvidia-open drivers (user requirement)
- GNOME-based, so adding KDE is the straightforward path
- Includes all Bazzite gaming optimizations and hardware support
- Bazzite actively maintains nvidia-open variants
- GNOME variant is more minimal than KDE, making it easier to add KDE packages on top

**Image Lineage Understanding:**
From Bazzite's build matrix, these images exist:
- `bazzite-nvidia-open` - KDE + nvidia-open drivers
- `bazzite-gnome-nvidia-open` - GNOME + nvidia-open drivers ← **Our choice**
- `bazzite-nvidia` - KDE + nvidia proprietary (LTS)
- `bazzite-gnome-nvidia` - GNOME + nvidia proprietary (LTS)
- `bazzite-dx-nvidia` - KDE + DX tools + nvidia proprietary (from bazzite-deck-nvidia)
- `bazzite-dx-nvidia-gnome` - GNOME + DX tools + nvidia proprietary (from bazzite-deck-nvidia-gnome)

**Important:** Bazzite-DX variants are built from bazzite-deck (handheld) variants, and currently **do not have nvidia-open versions**. The bazzite-deck images only come with proprietary nvidia drivers or no nvidia at all.

Therefore, to get GNOME + DX + nvidia-open + KDE, we must:
1. Start from `bazzite-gnome-nvidia-open` (has nvidia-open drivers we need)
2. Add DX developer tools from bazzite-dx (we'll layer these packages)
3. Add KDE Plasma packages from bazzite-nvidia-open

**Alternatives Considered:**
1. Start from `bazzite-dx-nvidia-gnome` and try to switch drivers to nvidia-open
   - Rejected: Switching NVIDIA driver types in a derived image is complex and fragile
   - Driver installation is tightly integrated with kernel builds
   - Risk of driver conflicts and boot failures
   
2. Start from `bazzite-nvidia-open` (KDE) and add GNOME + DX
   - Rejected: KDE base image is larger, adding GNOME creates bigger final image
   - User prefers starting with GNOME base
   
3. Continue with Bluefin DX and add Bazzite features + KDE + switch to nvidia-open
   - Rejected: Too many simultaneous changes
   - Would miss out on Bazzite's cohesive gaming ecosystem
   - Driver switching complexity

4. Build directly on Fedora base without Universal Blue
   - Rejected: Loses all UBlue infrastructure benefits
   - Would require reimplementing bootc patterns, gaming optimizations, etc.

### Decision 2: Package Installation Strategy

**Choice:** Create dedicated build script (`install-kde-packages.sh`) that mirrors Bazzite's KDE package selection

**Rationale:**
- Keeps KDE installation logic isolated and maintainable
- Follows Bazzite's proven package list for KDE
- Allows testing KDE installation independently
- Makes it easy to update when Bazzite changes their KDE package list

**Implementation:**
```bash
# build_files/desktop/install-kde-packages.sh
#!/usr/bin/bash
set -eoux pipefail

dnf5 -y install \
    plasma-desktop \
    plasma-workspace \
    sddm \
    krdp \
    steamdeck-kde-presets-desktop \
    kdeconnectd \
    kdeplasma-addons \
    # ... (additional packages)
    
dnf5 -y remove \
    plasma-discover \
    konsole \
    plasma-welcome \
    # ... (conflicting packages)
```

**Alternatives Considered:**
1. Install packages directly in Containerfile RUN commands
   - Rejected: Less maintainable, harder to debug
   
2. Use Bazzite's build scripts directly via git submodules
   - Rejected: Creates tight coupling, harder to customize

### Decision 3: Display Manager Handling

**Choice:** Install both GDM and SDDM, with systemd-managed selection

**Rationale:**
- Both display managers coexist peacefully when only one is enabled at a time
- GDM provides better GNOME integration (lock screen, user switching)
- SDDM provides better KDE integration (themes, plasma integration)
- Users can choose their preferred DM if desired

**Implementation:**
```bash
# Both installed, user's last session determines which is more appropriate
# Default: Use GDM (from GNOME base) but configure it to show both sessions
systemctl disable sddm.service  # Don't auto-enable SDDM
# GDM from base image remains enabled
```

**Session Detection Logic:**
- GDM automatically detects and shows both GNOME and Plasma sessions
- User selects session from session switcher dropdown
- Display manager persists user's choice for next login

**Alternatives Considered:**
1. Use only GDM for both desktops
   - Chosen: Simplest approach, GDM works well with both
   
2. Use only SDDM for both desktops
   - Rejected: GNOME Shell integration with SDDM is less polished
   
3. Dynamically switch DM based on last session
   - Rejected: Adds complexity, requires custom service

### Decision 4: Desktop Configuration Isolation

**Choice:** Use standard XDG config directories with desktop-specific subdirectories

**Rationale:**
- KDE stores config in `~/.config/` with kde-prefixed files
- GNOME stores config in dconf database and `~/.config/` with gnome-prefixed files
- Both desktops naturally avoid conflicts with proper setup
- System-level configs in `/usr/share/` can be desktop-specific

**Implementation:**
```
system_files/
├── kde/
│   ├── etc/
│   │   └── xdg/
│   │       └── kdeglobals     # KDE global settings
│   ├── usr/share/
│   │   └── plasma/            # Plasma configs
└── gnome/
    ├── etc/
    │   └── dconf/             # GNOME dconf overrides
    └── usr/share/
        └── glib-2.0/          # GNOME schemas
```

**Alternatives Considered:**
1. Merge all configurations into single shared directory
   - Rejected: Creates conflicts, harder to maintain
   
2. Use separate user accounts for each desktop
   - Rejected: Poor user experience, data isolation unwanted

### Decision 5: Terminal Emulator Strategy

**Choice:** Provide both Ptyxis and Konsole, let users choose

**Rationale:**
- Ptyxis is modern, GPU-accelerated, works well in both desktops
- Konsole is feature-rich, preferred by many KDE users
- No actual conflict between the two
- Small size increase (~5-10MB) is negligible
- User choice is more valuable than minimal size savings

**Implementation:**
- Keep both Ptyxis and Konsole installed
- Set Ptyxis as default for cross-desktop consistency
- Configure Ctrl+Alt+T shortcut to launch Ptyxis in both desktops
- KDE users can change default to Konsole if preferred
- Both terminals available in application menus

**Alternatives Considered:**
1. Remove Konsole, use only Ptyxis
   - Rejected: Removes user choice unnecessarily
   - No compelling reason to remove functioning software
   
2. Use Alacritty or Kitty
   - Rejected: Less integrated with both desktops

### Decision 6: Application Management Strategy

**Choice:** Test for conflicts first; only remove packages if they actually cause problems

**Rationale:**
- Many seemingly duplicate applications coexist peacefully
- User choice is valuable
- Preemptive removal based on assumptions can backfire
- Bazzite itself includes many duplicate apps across variants
- Image size increase is manageable

**Test-Then-Remove Approach:**
1. Install both GNOME and KDE with their full application sets
2. Test for actual conflicts (crashes, file conflicts, service conflicts)
3. Only remove packages that demonstrably cause problems
4. Document why each removal was necessary

**Packages to Keep (unless proven incompatible):**
- `konsole` - Keep alongside Ptyxis
- `kde-partitionmanager` - Keep alongside GNOME Disks
- `dolphin` - KDE file manager (alongside Nautilus)
- `kate` - KDE text editor (alongside gedit/Text Editor)

**Packages to Test and Potentially Remove:**
- `plasma-discover` - May conflict with GNOME Software for package management
  - Will test first; only remove if causes issues
- `plasma-welcome` - May auto-launch annoyingly on first KDE session
  - Will test first; only remove if creates poor UX

### Decision 7: Build Process Architecture

**Choice:** Layer DX tools and KDE packages on top of bazzite-gnome-nvidia-open in Containerfile

**Rationale:**
- Start with minimal gaming GNOME + nvidia-open base
- Add DX developer tools (since base doesn't have them)
- Add KDE Plasma on top
- Clear separation of concerns in build process
- Easy to troubleshoot each layer

**Implementation:**
```dockerfile
FROM ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable

# Copy build context
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files

# Install DX developer tools
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    /ctx/build_files/desktop/install-dx-tools.sh

# Install KDE packages
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    /ctx/build_files/desktop/install-kde-packages.sh

# Copy desktop-specific system files
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    cp -r /ctx/system_files/shared/* / && \
    cp -r /ctx/system_files/kde/* /

# Finalize
RUN ostree container commit && bootc container lint
```

**Build Order:**
1. Base: bazzite-gnome-nvidia-open (gaming + GNOME + nvidia-open drivers)
2. Layer 1: DX developer tools
3. Layer 2: KDE Plasma desktop
4. Layer 3: Configuration files
5. Finalize: ostree commit + validation

**Alternatives Considered:**
1. Start from bazzite-dx-nvidia-gnome and switch drivers
   - Rejected: Driver switching is fragile and complex
   
2. Multi-stage build starting from bare Fedora
   - Rejected: Duplicates Bazzite's work unnecessarily
   
3. Install DX + GNOME + KDE in parallel from neutral base
   - Rejected: More complex, larger image, misses Bazzite gaming optimizations

### Decision 8: Privacy and Security Configuration Strategy

**Choice:** System-wide security hardening + per-user privacy controls

**Rationale:**
- Two users have different privacy requirements but both need security
- Security should be enforced at system level (benefits everyone)
- Privacy controls should be user-configurable (respects different needs)
- Gaming and development shouldn't be hindered by overly restrictive privacy
- Privacy-focused user can enable strict controls in their account

**Implementation:**

**System-Wide Security (enforced):**
- SELinux enabled and enforcing
- Firewall configured with sensible defaults
- Automatic security updates enabled
- Disk encryption (LUKS) recommended during installation
- Secure boot support
- Regular vulnerability scanning

**Per-User Privacy Controls (optional):**
- Browser privacy extensions (pre-installed, user enables)
- Tracker blockers available in package manager
- VPN tools available for installation
- DNS-over-HTTPS configurable per-user
- Location services opt-in
- Telemetry disabled by default (Fedora respects user privacy)

**Desktop-Specific Considerations:**
- GNOME: Privacy panel in Settings for easy configuration
- KDE: System Settings → Privacy for granular controls
- Both desktops support user-level Firefox/Chromium profile isolation
- Each user maintains separate browser profiles and cookies

**Alternatives Considered:**
1. Enforce strict privacy system-wide
   - Rejected: Would break development tools, gaming services
   - One user's needs would compromise the other's workflow
   
2. No privacy tools, users install themselves
   - Rejected: Privacy user needs reasonable defaults available
   - Should provide tools, just not enforce them
   
3. Separate user accounts with different system images
   - Rejected: Defeats purpose of multi-user single system
   - Maintenance nightmare, doesn't support simultaneous login

### Decision 9: Multi-User Resource Management

**Choice:** Rely on Linux kernel's standard multi-user resource management with systemd optimizations

**Rationale:**
- Linux already handles multi-user scenarios well
- systemd provides resource control via cgroups
- Both Wayland compositors (GNOME/KDE) support multiple sessions
- No need for custom resource limiting unless problems arise
- Modern systems have enough RAM (recommend 16GB+ for dual sessions)

**Implementation:**
- Trust systemd's default resource allocation
- Monitor for issues in testing phase
- Document RAM recommendations (16GB minimum, 32GB recommended)
- Each user's session runs in separate cgroup
- OOM killer will protect system if memory exhausted
- Consider adding system.slice resource limits if needed

**System Requirements:**
- Minimum: 16GB RAM (both users logged in)
- Recommended: 32GB RAM (comfortable simultaneous gaming + development)
- CPU: Modern multi-core (6+ cores recommended)
- GPU: NVIDIA with nvidia-open driver support
- Disk: 100GB+ for OS, games, development projects

### Decision 10: Mesh VPN Solution

**Choice:** Replace Tailscale with Headscale + add ZeroTier as alternative

**Rationale:**
- Privacy-focused user benefits from self-hosted VPN control
- Headscale is open-source Tailscale control server
- No dependency on Tailscale's commercial servers
- Full control over coordination server and data
- ZeroTier provides alternative with different architecture
- Both can be user-enabled as needed

**Implementation:**

**Tailscale Removal:**
- Remove `tailscale` package (present in Bazzite base)
- Disable `tailscaled.service` if enabled
- Remove Tailscale repository configuration

**Headscale Installation:**
- Add [jonathanspw/headscale COPR repository](https://copr.fedorainfracloud.org/coprs/jonathanspw/headscale/)
- Install headscale package (includes systemd service, config file)
- Place example config at `/etc/headscale/config.yaml`
- Service disabled by default (user enables when ready)
- Fully compatible with Tailscale clients

**ZeroTier Installation:**
- Install `zerotier-one` package from RPMFusion repositories
- RPMFusion already enabled in Bazzite base (both free and nonfree repos)
- Service disabled by default
- Provides alternative mesh VPN architecture
- Can self-host ZeroTier network controller

**Documentation:**
- Explain Headscale vs Tailscale differences
- Document self-hosted setup process
- Provide ZeroTier configuration guide
- Note that both VPNs can coexist if needed
- Reference [RPMFusion configuration](https://rpmfusion.org/Configuration) for additional details

**Alternatives Considered:**
1. Keep Tailscale alongside Headscale
   - Rejected: Conflicting services, confusing to users
   - Tailscale clients work with Headscale server
   
2. Only install Headscale without ZeroTier
   - Rejected: Users benefit from options
   - Different use cases (Headscale = Tailscale-compatible, ZeroTier = different ecosystem)
   
3. Remove all VPN solutions, users install themselves
   - Rejected: VPN is important for privacy-focused user
   - Should provide privacy-respecting defaults

## Risks / Trade-offs

### Risk 1: Image Size Growth
- **Impact:** Image grows from ~8GB to ~9-10GB
- **Mitigation:** 
  - Remove duplicate packages (konsole, duplicate games, etc.)
  - Share common libraries between desktops
  - Use aggressive cleanup in build scripts
  - Leverage container layer caching for faster downloads

### Risk 2: Package Conflicts
- **Impact:** KDE and GNOME packages may conflict (file overlaps, library versions)
- **Mitigation:**
  - Test thoroughly in VM before release
  - Monitor Bazzite's approach to similar issues
  - Keep list of removed conflicting packages
  - Use DNF's conflict resolution (`--allowerasing` if needed)

### Risk 3: Configuration Conflicts
- **Impact:** Settings from one desktop may affect the other
- **Mitigation:**
  - Test configuration isolation thoroughly
  - Use desktop-specific config directories
  - Document any known interactions
  - Provide "reset to defaults" commands for each desktop

### Risk 4: Update Complexity
- **Impact:** Bazzite base updates may break KDE additions
- **Mitigation:**
  - Monitor Bazzite changelog for breaking changes
  - Test updates in VM before pushing to users
  - Maintain good relationship with Bazzite community
  - Document any Bazzite-specific dependencies

### Risk 5: Maintenance Burden
- **Impact:** Two desktops = 2x testing surface
- **Mitigation:**
  - Leverage Bazzite's testing for most issues
  - Focus testing on interaction between desktops
  - Automate testing where possible (boot tests, package conflicts)
  - Consider dropping one desktop if maintenance becomes unsustainable

### Risk 6: Multi-User Performance Degradation
- **Impact:** Two users logged in simultaneously may experience slowdowns
- **Mitigation:**
  - Document hardware requirements clearly (16GB RAM minimum, 32GB recommended)
  - Monitor resource usage during testing
  - Both Wayland compositors are efficient
  - Modern CPUs handle multi-user well
  - Consider adding resource limits if issues arise

### Risk 7: Session Interference
- **Impact:** One user's heavy workload (gaming, compilation) affects other user
- **Mitigation:**
  - Systemd cgroups provide some isolation
  - Document expected behavior (gaming may affect responsiveness)
  - Consider CPU governor settings for better scheduling
  - Users can adjust nice values for demanding processes

### Risk 8: Privacy Leakage Between Users
- **Impact:** Privacy-focused user concerned about other user's activities affecting their privacy
- **Mitigation:**
  - Standard Linux multi-user security prevents direct access
  - Each user has separate browser profiles and cookies
  - Network-level privacy (VPN, DNS) can be configured per-user
  - System logs are restricted to root access
  - Document that shared system means some metadata visibility to admin

### Trade-off 1: Simplicity vs. Flexibility
- **Choice:** Prioritize working dual desktop over minimal size
- **Reasoning:** Storage is cheap, user choice is valuable
- **Impact:** Larger downloads, more disk usage

### Trade-off 2: Upstream Purity vs. Customization
- **Choice:** Follow Bazzite patterns closely
- **Reasoning:** Easier to track upstream, less maintenance burden
- **Impact:** Less room for unique customizations

### Trade-off 3: GDM vs. SDDM as Primary DM
- **Choice:** Use GDM from GNOME base
- **Reasoning:** Simpler, works well with both desktops
- **Impact:** SDDM themes won't be visible (but can be enabled by user)

## Migration Plan

### For New Users
1. Download WhiteBlossom OS ISO
2. Boot and install normally
3. At login, choose between GNOME and Plasma sessions
4. No special configuration needed

### For Existing WhiteBlossom OS Users
1. Announce breaking change prominently
2. Provide migration guide in README
3. Users run: `sudo bootc switch ghcr.io/malarinv/whiteblossom-os:latest`
4. Reboot into new image
5. Choose desktop at login

**Migration Issues:**
- Custom Bluefin configurations may not transfer
- Users may need to re-apply some customizations
- Existing containers and flatpaks will persist

### Rollback Procedure
If issues occur after migration:
```bash
# View available images
sudo bootc status

# Rollback to previous boot entry
sudo bootc rollback

# Or switch back to Bluefin
sudo bootc switch ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable
```

### Testing Strategy
1. **Build Testing:** Verify image builds without errors
2. **Boot Testing:** Both desktops boot successfully
3. **Session Switch Testing:** Can switch between desktops without issues
4. **Driver Testing:** NVIDIA drivers work in both environments
5. **Application Testing:** Developer tools and games work in both
6. **Performance Testing:** Resource usage is reasonable
7. **Update Testing:** Updates from Bazzite upstream apply cleanly

## Open Questions

1. **Q:** Should we provide desktop-specific image variants in the future?
   - **A:** Not initially. Single image is simpler. Revisit if image size becomes prohibitive.

2. **Q:** How do we handle users who only want one desktop?
   - **A:** They can simply never use the other. No runtime overhead from unused desktop.

3. **Q:** Should we customize either desktop's defaults?
   - **A:** Minimal customization. Follow Bazzite's defaults for consistency.

4. **Q:** What if Bazzite drops DX variant support?
   - **A:** We can layer DX tools ourselves or switch to different base. Not urgent concern.

5. **Q:** Should we document which desktop is "primary"?
   - **A:** No. Both are equal first-class citizens. User choice determines primary.

