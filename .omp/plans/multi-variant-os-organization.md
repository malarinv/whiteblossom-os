# Plan: Multi-Variant OS Build Organization

## Context

WhiteBlossom OS currently builds a single "workstation" variant (GNOME + KDE + DX tools + gaming) from one Containerfile. The user wants to support multiple variants for different use-cases:
- **Workstation** — dual-desktop gaming/development (current)
- **IoT** — Raspberry Pi / Rock5B headless images
- **Cloud** — cluster node images
- **Handheld** — Steam Deck-like gaming devices

Bazzite (upstream reference) uses a single Containerfile with multi-stage targets + CI matrix. This is the proven pattern.

## Approach: Single Containerfile + Multi-Stage Targets

### Containerfile Structure

```dockerfile
# === Context stage (shared across all variants) ===
FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files

# === Shared base layer ===
FROM ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable AS whiteblossom-base
RUN --mount=type=bind,from=ctx ... /ctx/build_files/shared/build.sh
RUN ostree container commit

# === Variant: Workstation ===
FROM whiteblossom-base AS workstation
COPY --from=ctx /build_files/workstation /ctx
RUN --mount=type=bind ... /ctx/build.sh
COPY --from=ctx /system_files/shared /system_files/shared
COPY --from=ctx /system_files/workstation /system_files/workstation
RUN ostree container commit

# === Variant: IoT (different base) ===
FROM quay.io/fedora/fedora-bootc:44 AS iot
COPY --from=ctx /build_files/shared /ctx
COPY --from=ctx /build_files/iot /ctx
RUN --mount=type=bind ... /ctx/build.sh
COPY --from=ctx /system_files/shared /system_files/shared
COPY --from=ctx /system_files/iot /system_files/iot
RUN ostree container commit

# === Variant: Cloud ===
FROM whiteblossom-base AS cloud
# ... similar pattern ...
```

### File Changes

#### 1. Containerfile — rewrite to multi-stage variant targets

- Add `whiteblossom-base` stage (shared initramfs, cleanup, common packages)
- Add `workstation` stage (current desktop/gaming/DX packages)
- Add `iot` stage (headless, minimal, ARM firmware, device-tree overlays)
- Add `cloud` stage (k3s, cluster networking, minimal desktop)
- Add `handheld` stage (gamescope, Steam Deck-like config)
- Each variant has its own `COPY system_files/<variant>/` and `build_files/<variant>/`

**Key files:**
- `Containerfile` — rewrite (currently 52 lines → ~200 lines)

#### 2. build_files/ — reorganize into shared + variant-specific

```
build_files/
├── shared/
│   ├── build.sh              # Common: initramfs, cleanup, image-info
│   ├── initramfs
│   ├── cleanup
│   └── image-info
├── workstation/
│   ├── build.sh              # Desktop orchestrator (calls existing scripts)
│   ├── install-desktop.sh    # KDE + GNOME (from current install-kde-packages.sh)
│   ├── install-gaming.sh     # Steam, Lutris, gaming optimizations
│   ├── install-dx-tools.sh   # Developer tools (from current)
│   └── configure-system.sh   # Security, networking, display (from current)
├── iot/
│   ├── build.sh              # IoT orchestrator
│   ├── install-iot.sh        # Minimal packages, headless tools
│   └── configure-headless.sh # Disable GUI, enable serial, GPIO
├── cloud/
│   ├── build.sh              # Cloud orchestrator
│   ├── install-k3s.sh        # k3s, container runtimes
│   └── configure-cluster.sh  # Cluster networking, storage
└── handheld/
    ├── build.sh              # Handheld orchestrator
    ├── install-handheld.sh   # Gamescope, Steam Deck tools
    └── configure-gamescope.sh # Input, display, power management
```

**Key files:**
- `build_files/build.sh` → move to `build_files/shared/build.sh` (or keep as orchestrator)
- `build_files/desktop/` → rename to `build_files/workstation/` + add gaming script
- New: `build_files/iot/`, `build_files/cloud/`, `build_files/handheld/`

#### 3. system_files/ — organize by variant

```
system_files/
├── shared/                    # All variants (current shared/)
│   └── usr/share/ublue-os/just/
│       └── 96-whiteblossom-devbox.just
├── workstation/               # Desktop-only (current gnome/ + kde/)
│   ├── etc/xdg/kdeglobals
│   ├── etc/xdg/kglobalshortcutsrc
│   └── ...
├── iot/                       # IoT-only (new)
│   └── etc/systemd/system/    # Headless services, serial console
├── cloud/                      # Cloud-only (new)
│   └── etc/rancher/k3s/       # K3s config
└── handheld/                  # Handheld-only (new)
    └── etc/xdg/               # Gamescope config
```

**Key files:**
- `system_files/shared/` — keep as-is
- `system_files/gnome/` + `system_files/kde/` → merge into `system_files/workstation/`
- New: `system_files/iot/`, `system_files/cloud/`, `system_files/handheld/`

#### 4. iso_config/ — per-variant GRUB params

```
iso_config/
├── shared/                    # Common Anaconda config
│   ├── interactive-defaults.ks
│   └── anaconda-shell.conf
├── workstation.yaml           # GRUB params for desktop (current iso.yaml)
├── iot.yaml                   # GRUB params for IoT (minimal, serial console)
├── cloud.yaml                  # GRUB params for cloud (headless)
└── handheld.yaml              # GRUB params for handheld (gamescope)
```

**Key files:**
- `iso_config/iso.yaml` → rename to `iso_config/workstation.yaml`
- New: `iso_config/iot.yaml`, `iso_config/cloud.yaml`, `iso_config/handheld.yaml`

#### 5. disk_config/ — per-variant disk configs

```
disk_config/
├── workstation.toml           # Current disk.toml
├── iot.toml                   # Raw disk for SD cards
├── cloud.toml                  # QCOW2 for VMs
└── handheld.toml              # Raw disk for handheld
```

**Key files:**
- `disk_config/disk.toml` → rename to `disk_config/workstation.toml`
- New: `disk_config/iot.toml`, `disk_config/cloud.toml`, `disk_config/handheld.toml`

#### 6. mise.toml — per-variant tasks

```toml
[tasks.run-workstation]
description = "Launch workstation ISO in QEMU"
run = "qemu-system-x86_64 -m 8192 -enable-kvm ... -cdrom dist/workstation.iso -boot d"

[tasks.run-iot]
description = "Launch IoT image in QEMU (ARM emulation)"
run = "qemu-system-aarch64 -m 4092 -M virt ... -drive file=dist/iot.raw,format=raw"

[tasks.run-cloud]
description = "Launch cloud node in QEMU"
run = "qemu-system-x86_64 -m 8192 -enable-kvm ... -drive file=dist/cloud.qcow2,format=qcow2"

[tasks.run-handheld]
description = "Launch handheld image in QEMU"
run = "qemu-system-x86_64 -m 8192 -enable-kvm ... -drive file=dist/handheld.qcow2,format=qcow2"
```

**Key files:**
- `mise.toml` — add variant-specific tasks

#### 7. Justfile — add variant-aware build targets

Add parameterized recipes:

```just
# Build specific variant
build variant="workstation" tag=default_tag:
    podman build --target {{variant}} --tag "whiteblossom-{{variant}}:{{tag}}" .

# Build disk for variant
build-disk variant="workstation" tag=default_tag:
    # Uses disk_config/{{variant}}.toml
```

**Key files:**
- `Justfile` — add variant-aware recipes (currently 320 lines)

#### 8. .github/workflows/build.yml — add variant matrix

```yaml
strategy:
  fail-fast: false
  matrix:
    variant: [workstation, iot, cloud, handheld]
    platform: [linux/amd64]
    include:
      - variant: iot
        platform: linux/arm64
        runner: ubuntu-latest-arm64
```

**Key files:**
- `.github/workflows/build.yml` — add matrix (currently single-image build)
- `.github/workflows/build-disk.yml` — add variant + type matrix

#### 9. docs/iso-build.md — update for multi-variant

Update documentation to cover variant selection and building.

**Key files:**
- `docs/iso-build.md` — update

## Verification

1. **Local build test**: `podman build --target workstation -t whiteblossom-workstation:latest .`
2. **Lint check**: Each target stage ends with `bootc container lint`
3. **CI matrix**: Verify GitHub Actions matrix builds all variants
4. **mise tasks**: Verify `mise run run-workstation` launches QEMU correctly
5. **Justfile**: Verify `just build workstation` works

## Implementation Order

1. Create `build_files/shared/` and move common scripts
2. Create `build_files/workstation/` from current `build_files/desktop/`
3. Create `build_files/iot/`, `build_files/cloud/`, `build_files/handheld/` with stub scripts
4. Rewrite `Containerfile` with multi-stage targets
5. Reorganize `system_files/` into variant directories
6. Update `iso_config/` with per-variant configs
7. Update `disk_config/` with per-variant configs
8. Update `mise.toml` with variant tasks
9. Update `Justfile` with variant-aware recipes
10. Update `.github/workflows/build.yml` with variant matrix
11. Update `.github/workflows/build-disk.yml` with variant + type matrix
12. Update `docs/iso-build.md`

## Out of Scope (for now)

- Actual IoT/Cloud/handheld package lists (will be stubs to fill in later)
- ARM cross-compilation strategy (will use native ARM runners)
- Greenboot health checks (can add later)
- Manifest stitching for multi-arch tags (can add later)
