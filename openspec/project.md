# Project Context

## Purpose

WhiteBlossom OS is a custom bootc-based immutable operating system image built on Universal Blue's Bluefin DX with NVIDIA support. The project provides a personalized, declarative, and reproducible Linux desktop environment using container-native infrastructure.

**Goals:**
- Create a stable, immutable OS image with personal customizations
- Leverage Universal Blue's infrastructure for atomic updates and rollbacks
- Maintain reproducible builds via container technology
- Provide bootable ISOs and VM images for easy deployment
- Support declarative package management and system configuration

## Tech Stack

### Core Technologies
- **bootc** - Container-native boot system for atomic OS updates
- **Podman** - Container engine for building and testing images
- **Fedora Atomic** - Base operating system (via Universal Blue)
- **Universal Blue / Bluefin DX** - Base image providing developer tools and NVIDIA support
- **Bash** - Primary scripting language for build automation

### Build & Development Tools
- **Just** - Command runner for build automation (modern Make alternative)
- **bootc-image-builder (BIB)** - Creates bootable images (QCOW2, RAW, ISO) from container images
- **Devbox** - Reproducible development environment manager
- **cosign** - Container image signing for supply chain security
- **GitHub Actions** - CI/CD for automated builds and releases
- **shellcheck** - Bash script linting
- **shfmt** - Bash script formatting

### Infrastructure
- **GitHub Container Registry (GHCR)** - Container image hosting at `ghcr.io/malarinv/whiteblossom-os`
- **Artifact Hub** - Public listing and discovery platform
- **DNF5** - Package manager for installing RPMs
- **OSTree** - Filesystem management for atomic updates

## Project Conventions

### Code Style

**Bash Scripts:**
- Follow strict error handling: `set -eoux pipefail` (or `set -ouex pipefail` for build scripts)
- Use shellcheck for linting - all scripts must pass without errors
- Format with shfmt for consistent style
- Use descriptive variable names in snake_case
- Quote all variables: `"${variable}"` not `$variable`
- Prefer explicit paths over relative paths

**Containerfiles:**
- Use multi-stage builds when referencing external files
- Mount build files as bind mounts to avoid copying into final image
- Use cache mounts for `/var/cache`, `/var/log` to speed up builds
- Always run `ostree container commit` after modifications
- End with `bootc container lint` to verify image integrity
- Pull base images with `--pull=newer` to ensure updates

**File Organization:**
- Build scripts go in `build_files/` directory
- Disk/ISO configurations in `disk_config/` directory  
- All Just commands organized with `[group('name')]` annotations
- Use private recipes (prefix with `_`) for internal helpers

### Architecture Patterns

**Immutable Infrastructure:**
- Base OS is read-only and immutable
- System changes happen through container rebuilds, not runtime modifications
- Configuration layered via container build process
- Updates applied atomically with automatic rollback capability

**Container-Native Design:**
- The OS itself is a container image
- Built using standard container tools (Podman)
- Published to container registries (GHCR)
- Bootable images derived from container images via bootc-image-builder

**Declarative Configuration:**
- All system modifications defined in `build_files/build.sh`
- Package installations use DNF5 in build script
- System units enabled/disabled declaratively
- Disk layout defined in TOML configuration files

**Build Workflow:**
1. Start from Universal Blue base image
2. Mount build scripts without copying (scratch stage + bind mount)
3. Execute customizations via `build.sh`
4. Commit changes with `ostree container commit`
5. Validate with `bootc container lint`
6. Optionally convert to bootable images (QCOW2/RAW/ISO)

### Testing Strategy

**Container Image Testing:**
- `bootc container lint` validates image structure and integrity
- Manual testing via QCOW2 VMs before deploying to physical hardware
- Rollback capability built into bootc allows safe testing on bare metal

**VM Testing Workflow:**
- Build QCOW2 image: `just build-qcow2`
- Test in QEMU: `just run-vm-qcow2`
- Alternatively use systemd-vmspawn: `just spawn-vm`
- Verify all customizations work before pushing to registry

**Script Quality:**
- Run shellcheck on all bash scripts: `just lint`
- Format scripts consistently: `just format`
- Test build process locally before pushing to CI

### Git Workflow

**Branching Strategy:**
- `main` branch contains production-ready code
- All changes should be tested locally before pushing to main
- Use feature branches for experimental changes
- Tag releases with semantic versioning when appropriate

**Commit Conventions:**
- Write clear, descriptive commit messages
- Prefix commits with component when relevant: `build:`, `ci:`, `docs:`, etc.
- Keep commits atomic and focused
- Sign commits when possible for security

**Container Image Tags:**
- `latest` - Most recent stable build from main branch
- Include Git SHA in image labels when working tree is clean
- Use stable base images (e.g., `:stable` tag from Universal Blue)

**Security:**
- Container images must be signed with cosign
- Private key (`cosign.key`) never committed to repository
- Public key (`cosign.pub`) committed for verification
- GitHub secret `SIGNING_SECRET` contains private key for CI

## Domain Context

### Immutable Operating Systems
- The OS filesystem is read-only by default
- System updates are atomic - either fully succeed or fully roll back
- No partial update states possible
- Previous OS versions retained for rollback
- User data and containers remain mutable

### bootc Concepts
- **bootc** boots container images directly as operating systems
- Images must follow bootc conventions (systemd, ostree, etc.)
- `bootc switch` changes to a different OS image
- `bootc upgrade` updates to newer version of current image
- Images can be tested in VMs before deploying to hardware

### Universal Blue Ecosystem
- Community project providing enhanced Fedora Atomic images
- Bluefin DX variant includes developer tools and IDE configurations
- NVIDIA variants include proprietary drivers pre-installed
- Built on Fedora Silverblue/Kinoite foundation
- Provides sane defaults and quality-of-life improvements

### Container-Native OS Benefits
- Leverage existing container infrastructure and tooling
- Test OS changes in CI/CD pipelines
- Distribute OS updates via container registries
- Version control the entire operating system
- Reproduce environments exactly across machines

## Important Constraints

### Technical Constraints
- Must maintain compatibility with bootc requirements
- Base image must be from a bootc-compatible source
- RPM installations limited to available repositories (Fedora, RPMfusion, COPRs)
- Cannot modify `/usr` at runtime (immutable)
- System modifications require image rebuild and reboot
- Image size impacts update bandwidth (optimize layer caching)

### Build Environment Requirements
- Requires Podman (or Docker with adjustments)
- Root/sudo access needed for bootc-image-builder
- Sufficient disk space for layer caching and output images (~20GB+)
- KVM support required for VM testing
- Linux host required for full build pipeline

### Base Image Considerations
- Tied to Fedora Atomic release schedule
- Must track Universal Blue's Bluefin updates
- Breaking changes in upstream require adaptation
- NVIDIA driver version determined by base image

### Security Constraints
- Container signing mandatory for production use
- Private signing keys must remain secret
- Images should be scanned for vulnerabilities
- Minimize attack surface by limiting installed packages

## External Dependencies

### Critical Services
- **GitHub Container Registry (ghcr.io)** - Hosts container images
  - Used for: Image storage and distribution
  - URL: `ghcr.io/malarinv/whiteblossom-os`
  
- **Universal Blue Project** - Provides base images
  - Used for: Base OS foundation
  - Image: `ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable`
  - Docs: https://universal-blue.org/

- **Artifact Hub** - Public image listing
  - Used for: Project discovery and documentation
  - Config: `artifacthub-repo.yml`

### Build Dependencies
- **Bootc Project** - Container boot framework
  - Used for: Converting containers to bootable OS images
  - Docs: https://bootc-dev.github.io/bootc/

- **bootc-image-builder** - Image conversion tool
  - Used for: Creating QCOW2, RAW, and ISO images
  - Image: `quay.io/centos-bootc/bootc-image-builder:latest`
  - Docs: https://osbuild.org/docs/bootc/

- **Quay.io / Docker Hub** - Dependency images
  - Used for: Pulling build tools and test environments
  - Example: `docker.io/qemux/qemu` for VM testing

### Package Repositories
- **Fedora Repositories** - Base packages
  - Mirrors: Fedora official mirrors
  
- **RPMfusion** - Additional software
  - Used for: Multimedia codecs, NVIDIA drivers, etc.
  - URLs: Free and non-free repositories enabled by default in Universal Blue

- **COPR** - Community packages (optional)
  - Used for: Bleeding edge or specialized packages
  - Must be enabled/disabled explicitly in build scripts

### Development Tools
- **Devbox** - Development environment
  - Packages: `gh` (GitHub CLI), `cosign` (signing tool)
  - Schema: https://raw.githubusercontent.com/jetify-com/devbox/0.13.7/.schema/devbox.schema.json

- **Just** - Command runner
  - Used for: All build, test, and utility commands
  - Install: Available in Fedora repos or via cargo
