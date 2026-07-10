# ISO Build Architecture

This document covers how WhiteBlossom OS ISOs are built, the design decisions behind the current approach, and troubleshooting for common issues.

## Overview

The ISO build pipeline produces a **self-contained Anaconda installer ISO** that embeds the full WhiteBlossom OS container image directly into the installation media. The installer does not require network access — the entire OS image is served from the ISO's squashfs volume at install time.

### Pipeline

```
┌──────────────────┐     ┌──────────────────────┐     ┌─────────────────────┐
│  build.yml       │     │  Containerfile.iso   │     │  build-disk.yml     │
│  (main image)    │────▶│  (Anaconda overlay)  │────▶│  (image-builder)    │
│  ghcr.io/...     │     │  +graphical deps     │     │  anaconda-iso       │
└──────────────────┘     └──────────────────────┘     └─────────────────────┘
```

1. **`build.yml`** builds the main WhiteBlossom OS container image and pushes to GHCR.
2. **`Containerfile.iso`** layers Anaconda and graphical installer dependencies on top of the main image.
3. **`build-disk.yml`** uses `osbuild/image-builder-cli` to produce a self-contained `anaconda-iso`.

### Key Files

| File | Purpose |
|------|---------|
| `Containerfile.iso` | ISO-specific overlay: Anaconda, graphical deps, build tools |
| `iso_config/iso.yaml` | GRUB boot entry and kernel parameters |
| `iso_config/interactive-defaults.ks` | Anaconda kickstart with `bootc install` source reference |
| `iso_config/anaconda-shell.conf` | logind config for Anaconda shell session |
| `.github/workflows/build-disk.yml` | CI pipeline for building QCOW2 and ISO artifacts |

## Self-Contained ISO

The ISO is built using the `anaconda-iso` image type (not `bootc-generic-iso`). This distinction is critical:

| Type | Behavior | Network Required |
|------|----------|-----------------|
| `bootc-generic-iso` | Generic installer; pulls container image from registry at install time | **Yes** |
| `anaconda-iso` | Embeds the full container filesystem into the ISO's squashfs volume | **No** |

With `anaconda-iso`, image-builder resolves the local container reference (`localhost/whiteblossom-iso:latest`) and translates all filesystem layers into an embedded squashfs payload. When Anaconda runs, it reads the image from local media instead of reaching out to a registry.

### Why `inst.text` Was Removed

Previously, `iso_config/iso.yaml` included `inst.text` in the GRUB kernel parameters. This flag explicitly forces Anaconda into text/CLI mode, bypassing the graphical installer entirely. The CLI mode presents two options:

- Continue in text mode (non-interactive)
- Use RDP-based remote GUI session

Neither is the intended experience. Removing `inst.text` allows Anaconda to detect the display environment and launch the graphical installer directly.

## Graphical Installer (Wayland + virtio-gl)

Modern Anaconda (Fedora 41+) has fully migrated from X11 to Wayland. The graphical installer runs inside a minimal Wayland compositor called **GNOME Kiosk** — a single-application compositor that displays Anaconda full-screen without loading a full desktop shell.

### Display Stack

```
┌─────────────────────────────────────────────┐
│  Anaconda GUI (GTK4 / libadwaita)           │
├─────────────────────────────────────────────┤
│  GNOME Kiosk (Wayland compositor)           │
├─────────────────────────────────────────────┤
│  Wayland + Xwayland                         │
├─────────────────────────────────────────────┤
│  Mesa (DRI + Vulkan/Venus drivers)          │
├─────────────────────────────────────────────┤
│  Kernel KMS (amdgpu, i915, virtio-gpu)      │
└─────────────────────────────────────────────┘
```

### Required Packages

These are installed in `Containerfile.iso` under "Graphical installer dependencies":

| Package | Role |
|---------|------|
| `anaconda-gui` | Graphical frontend (GTK4-based) |
| `gnome-kiosk` | Minimal Wayland compositor for single-app display |
| `mesa-dri-drivers` | DRI drivers for hardware-accelerated rendering |
| `mesa-vulkan-drivers` | Vulkan drivers for VirGL/Venus 3D acceleration |
| `wayland` | Core Wayland protocol libraries |
| `xorg-x11-server-Xwayland` | X11 compatibility layer for legacy components |

Without these packages, Anaconda cannot initialize the Wayland compositor and falls back to text mode.

### virtio-gl in QEMU

When running the ISO in QEMU/KVM, the virtual GPU must support Wayland rendering. The recommended QEMU configuration:

```
-device virtio-vga-gl,venus=true
-display gtk,gl=on
```

- **`virtio-vga-gl`** — Modern VirtIO GPU device with OpenGL/Vulkan support
- **`venus=true`** — Enables Vulkan Venus (VirGL) passthrough to host GPU
- **`-display gtk,gl=on`** — Host-side OpenGL rendering context

The guest Mesa drivers (`mesa-dri-drivers`, `mesa-vulkan-drivers`) communicate with the host GPU through the VirGL/Venus translation layer, providing hardware-accelerated rendering inside the VM.

### QEMU Invocation

The project uses `qemux/qemu` via Podman for VM testing (see `run-vm-iso` in Justfile). For direct QEMU invocation with virtio-gl:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 8G \
  -smp 4 \
  -cpu host \
  -device virtio-vga-gl,venus=true \
  -display gtk,gl=on \
  -cdrom output/bootiso/install.iso \
  -drive file=test-disk.qcow2,if=virtio,format=qcow2 \
  -tpm dev=tpm-tis,chardev=chrtpm \
  -chardev socket,id=chrtpm,path=/tmp/swtpm-sock \
  -swtpm0
```

## Anaconda Kickstart

The `interactive-defaults.ks` file configures Anaconda's default behavior:

```ks
bootc --source-imgref registry:ghcr.io/malarinv/whiteblossom-os:latest \
      --target-imgref ghcr.io/malarinv/whiteblossom-os:latest
```

### Why the source-imgref Points to a Registry

For self-contained ISOs built with `anaconda-iso`, the `--source-imgref` should reference the **registry tag**, not a local filesystem path. The image-builder embeds the image into the ISO and makes it available at the expected location — Anaconda resolves the reference to the embedded media automatically.

Do **not** hardcode paths like `/mnt/install/...` in `--source-imgref`.

## Troubleshooting

### Anaconda boots to text/CLI mode

1. **Check `iso_config/iso.yaml`** — Ensure `inst.text` is **not** in the kernel parameters. This flag forces text mode.
2. **Check graphical packages** — Verify `anaconda-gui`, `gnome-kiosk`, and `mesa-dri-drivers` are installed in the ISO overlay.
3. **Check QEMU device** — Ensure you're using `virtio-vga-gl` (not `virtio-vga` or `cirrus-vga`).

### "deploying image: layers already present 0" hang

This error means Anaconda initialized the storage framework but failed to fetch image bytes. Causes:

1. **Using `bootc-generic-iso`** — Switch to `anaconda-iso` in `build-disk.yml`. The generic type requires network access.
2. **No network and no embedded image** — Verify the ISO was built with `--bootc-ref` pointing to a locally available image with container storage mounted.

### Blank screen after boot

1. **Insufficient RAM** — The Wayland compositor requires at least 2 GB. The project allocates 8 GB.
2. **Missing KMS driver** — Ensure the QEMU GPU device supports Kernel Mode Setting. `virtio-vga-gl` does; older devices may not.
3. **Mesa driver mismatch** — Verify `mesa-dri-drivers` and `mesa-vulkan-drivers` are present in the ISO overlay.

### Graphical installer works but renders slowly

1. **Software rendering fallback** — If VirGL/Venus passthrough isn't working, Mesa falls back to software rendering. Check `LIBGL_ALWAYS_SOFTWARE=1` isn't set.
2. **Host GPU not exposed** — Verify `-device virtio-vga-gl,venus=true` and `-display gtk,gl=on` are both present in the QEMU command.

## Build Commands

```bash
# Build the ISO overlay image
sudo podman build \
  --build-arg BASE_IMAGE="ghcr.io/malarinv/whiteblossom-os:latest" \
  -t localhost/whiteblossom-iso:latest \
  -f Containerfile.iso .

# Build the self-contained ISO
sudo podman run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v ./output:/output \
  ghcr.io/osbuild/image-builder-cli:latest \
  build \
  --output-dir /output \
  --bootc-default-fs btrfs \
  --bootc-ref localhost/whiteblossom-iso:latest \
  anaconda-iso

# Run the ISO in a VM (via Justfile)
just run-vm-iso
```
