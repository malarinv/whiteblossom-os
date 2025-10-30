# WhiteBlossom OS

## Purpose

WhiteBlossom OS is a custom Universal Blue image based on [Bazzite](https://bazzite.gg/) that provides a dual desktop experience with both GNOME and KDE Plasma in a single OS image. It's designed for a multi-user environment where different users have different desktop and workflow preferences.

### Key Features

- **Dual Desktop Environments**: Both GNOME Shell and KDE Plasma 6 available at login
- **Gaming Optimizations**: Full Bazzite gaming stack (Gamescope, Steam integration, controller support)
- **Developer Tools**: Complete DX developer toolchain included
- **NVIDIA Support**: nvidia-open drivers for optimal GPU performance
- **Privacy-Focused Networking**: Self-hosted mesh VPN options (Headscale, ZeroTier)
- **Multi-User Ready**: Supports simultaneous sessions with different desktops

## Base Image

**Current Base**: `ghcr.io/ublue-os/bazzite-gnome-nvidia-open:stable`

WhiteBlossom OS builds on Bazzite's GNOME variant with nvidia-open drivers, then adds:
- DX developer tools and runtimes
- KDE Plasma desktop environment
- Privacy-focused networking tools
- Multi-user optimizations

**Previous Base**: `ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable` (deprecated)

## System Requirements

### Minimum Requirements
- **RAM**: 16GB (for dual user sessions)
- **CPU**: Modern multi-core processor (4+ cores)
- **GPU**: NVIDIA GPU with nvidia-open driver support
- **Disk**: 100GB+ (OS, games, and development projects)

### Recommended Requirements
- **RAM**: 32GB (comfortable dual-session experience)
- **CPU**: 6+ cores for simultaneous gaming and development
- **GPU**: Modern NVIDIA GPU (RTX series recommended)
- **Disk**: 256GB+ NVMe SSD

## Desktop Environments

WhiteBlossom OS includes both GNOME and KDE Plasma desktops:

### GNOME (Default)
- Clean, distraction-free interface
- Excellent for privacy-focused users
- Strong Wayland support
- GNOME 47+ with Bazzite gaming extensions

### KDE Plasma
- Highly customizable interface
- Rich feature set for power users
- Gaming optimizations from Bazzite KDE variant
- KDE Plasma 6 with Wayland support

### Switching Desktops

At the login screen (GDM), click the gear icon (⚙️) to select between:
- **GNOME** - GNOME Shell (Wayland)
- **Plasma** - KDE Plasma (Wayland)

Your choice persists across reboots. You can switch anytime by logging out and selecting a different session.

## Multi-User Configuration

WhiteBlossom OS supports multiple users logged in simultaneously with different desktops:

- **User 1** can be in GNOME session
- **User 2** can be in KDE Plasma session
- Both sessions run concurrently without interference
- Standard Linux file permissions keep data isolated
- Each user maintains independent desktop configurations

**Note**: Heavy workloads (gaming, compilation) in one session may impact responsiveness in the other. 32GB RAM recommended for intensive concurrent use.

## Privacy & Networking

### Self-Hosted Mesh VPN

WhiteBlossom OS replaces Tailscale with privacy-focused alternatives:

#### Headscale
- Self-hosted Tailscale control server
- Full control over coordination and data
- Compatible with Tailscale clients
- Configuration: `/etc/headscale/config.yaml`

```bash
# Enable Headscale
sudo systemctl enable --now headscale.service
```

#### ZeroTier
- Decentralized mesh VPN
- Alternative to Headscale/Tailscale
- Can self-host network controller

```bash
# Enable ZeroTier
sudo systemctl enable --now zerotier-one.service
sudo zerotier-cli join <network-id>
```

See `/usr/share/doc/whiteblossom-os/mesh-vpn-guide.md` for detailed setup.

### Privacy Features

- **SELinux**: Enforcing mode (system-wide security)
- **Firewall**: Configured with sensible defaults
- **Privacy Tools**: Available but user-optional
- **Per-User Control**: Privacy settings configurable per account
- **No Telemetry**: Fedora/Bazzite defaults (privacy-respecting)

## Prerequisites

Working knowledge in the following topics:

- Containers
  - https://www.youtube.com/watch?v=SnSH8Ht3MIc
  - https://www.mankier.com/5/Containerfile
- bootc
  - https://bootc-dev.github.io/bootc/
- Fedora Silverblue (and other Fedora Atomic variants)
  - https://docs.fedoraproject.org/en-US/fedora-silverblue/
- Github Workflows
  - https://docs.github.com/en/actions/using-workflows

# Installation

## New Installation

1. Download the latest ISO from releases or build your own
2. Boot from ISO and install normally
3. After installation, at the login screen, select your preferred desktop:
   - Click the gear icon (⚙️) next to "Sign In"
   - Choose "GNOME" or "Plasma"
4. Log in and enjoy!

## Migration from Bluefin

**⚠️ BREAKING CHANGE**: WhiteBlossom OS has migrated from Bluefin DX to Bazzite GNOME base.

### Migration Steps

```bash
# Switch to WhiteBlossom OS
sudo bootc switch --transport registry ghcr.io/malarinv/whiteblossom-os:latest

# Reboot to apply
sudo systemctl reboot
```

After reboot:
1. You'll see both GNOME and Plasma options at login
2. Select your preferred desktop environment
3. Your user data, flatpaks, and containers are preserved

### What Changes

- **Base system**: Bluefin → Bazzite
- **NVIDIA drivers**: May switch to nvidia-open (check with `nvidia-smi`)
- **Desktop options**: Now have both GNOME and KDE Plasma
- **Networking**: Tailscale removed, Headscale/ZeroTier available
- **Developer tools**: Full DX suite included

### Rollback

If issues occur:

```bash
# View available images
sudo bootc status

# Rollback to previous deployment
sudo bootc rollback

# Or switch back to Bluefin
sudo bootc switch ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable
```

## Verifying Installation

```bash
# Check current deployment
rpm-ostree status

# Verify nvidia drivers
nvidia-smi

# Check desktop environments
ls /usr/share/xsessions/
ls /usr/share/wayland-sessions/
```

# Development

## Building Custom Images

WhiteBlossom OS is built on the Universal Blue image-template pattern.

## Containerfile

This file defines the operations used to customize the selected image. It:
- Starts from Bazzite GNOME nvidia-open base
- Adds DX developer tools
- Installs KDE Plasma desktop environment
- Configures privacy-focused networking (Headscale, ZeroTier)
- Applies system configurations for both desktops

## Building an ISO

This template provides an out of the box workflow for getting an ISO image for your custom OCI image which can be used to directly install onto your machines.

This template provides a way to upload the ISO that is generated from the workflow to a S3 bucket or it will be available as an artifact from the job. To upload to S3 we use a tool called [rclone](https://rclone.org/) which is able to use [many S3 providers](https://rclone.org/s3/). For more details on how to configure this see the details [below](#build-isoyml).

### Justfile Documentation

This `Justfile` contains various commands and configurations for building and managing container images and virtual machine images using Podman and other utilities.

#### Environment Variables

- `repo_organization`: The GitHub repository owner (default: "yourname").
- `image_name`: The name of the image (default: "yourimage").
- `centos_version`: The CentOS version (default: "stream10").
- `fedora_version`: The Fedora version (default: "41").
- `default_tag`: The default tag for the image (default: "latest").
- `bib_image`: The Bootc Image Builder (BIB) image (default: "quay.io/centos-bootc/bootc-image-builder:latest").

#### Aliases

- `build-vm`: Alias for `build-qcow2`.
- `rebuild-vm`: Alias for `rebuild-qcow2`.
- `run-vm`: Alias for `run-vm-qcow2`.


#### Commands

###### `check`

Checks the syntax of all `.just` files and the `Justfile`.

###### `fix`

Fixes the syntax of all `.just` files and the `Justfile`.

###### `clean`

Cleans the repository by removing build artifacts.

##### Build Commands

###### `build`

Builds a container image using Podman.

```bash
just build $target_image $tag $dx $hwe $gdx
```

Arguments:
- `$target_image`: The tag you want to apply to the image (default: aurora).
- `$tag`: The tag for the image (default: lts).
- `$dx`: Enable DX (default: "0").
- `$hwe`: Enable HWE (default: "0").
- `$gdx`: Enable GDX (default: "0").

##### Building Virtual Machines and ISOs

###### `build-qcow2`

Builds a QCOW2 virtual machine image.

```bash
just build-qcow2 $target_image $tag
```

###### `build-raw`

Builds a RAW virtual machine image.

```bash
just build-raw $target_image $tag
```

###### `build-iso`

Builds an ISO virtual machine image.

```bash
just build-iso $target_image $tag
```

###### `rebuild-qcow2`

Rebuilds a QCOW2 virtual machine image.

```bash
just rebuild-qcow2 $target_image $tag
```

###### `rebuild-raw`

Rebuilds a RAW virtual machine image.

```bash
just rebuild-raw $target_image $tag
```

###### `rebuild-iso`

Rebuilds an ISO virtual machine image.

```bash
just rebuild-iso $target_image $tag
```

##### Run Virtual Machines

###### `run-vm-qcow2`

Runs a virtual machine from a QCOW2 image.

```bash
just run-vm-qcow2 $target_image $tag
```

###### `run-vm-raw`

Runs a virtual machine from a RAW image.

```bash
just run-vm-raw $target_image $tag
```

###### `run-vm-iso`

Runs a virtual machine from an ISO.

```bash
just run-vm-iso $target_image $tag
```

###### `spawn-vm`

Runs a virtual machine using systemd-vmspawn.

```bash
just spawn-vm rebuild="0" type="qcow2" ram="6G"
```

##### Lint and Format

###### `lint`

Runs shell check on all Bash scripts.

###### `format`

Runs shfmt on all Bash scripts.

## Workflows

### build.yml

This workflow creates your custom OCI image and publishes it to the Github Container Registry (GHCR). By default, the image name will match the Github repository name.

### build-iso.yml

This workflow creates an ISO from your OCI image by utilizing the [bootc-image-builder](https://osbuild.org/docs/bootc/) to generate an ISO. In order to use this workflow you must complete the following steps:

- Modify `iso.toml` to point to your custom image before generating an ISO.
- If you changed your image name from the default in `build.yml` then in the `build-iso.yml` file edit the `IMAGE_REGISTRY` and `DEFAULT_TAG` environment variables with the correct values. If you did not make changes, skip this step.
- Finally, if you want to upload your ISOs to S3 then you will need to add your S3 configuration to the repository's Action secrets. This can be found by going to your repository settings, under `Secrets and Variables` -> `Actions`. You will need to add the following
  - `S3_PROVIDER` - Must match one of the values from the [supported list](https://rclone.org/s3/)
  - `S3_BUCKET_NAME` - Your unique bucket name
  - `S3_ACCESS_KEY_ID` - It is recommended that you make a separate key just for this workflow
  - `S3_SECRET_ACCESS_KEY` - See above.
  - `S3_REGION` - The region your bucket lives in. If you do not know then set this value to `auto`.
  - `S3_ENDPOINT` - This value will be specific to the bucket as well.

Once the workflow is done, you'll find it either in your S3 bucket or as part of the summary under `Artifacts` after the workflow is completed.

#### Container Signing

Container signing is important for end-user security and is enabled on all Universal Blue images. It is recommended you set this up, and by default the image builds *will fail* if you don't.

This provides users a method of verifying the image.

1. Install the [cosign CLI tool](https://edu.chainguard.dev/open-source/sigstore/cosign/how-to-install-cosign/#installing-cosign-with-the-cosign-binary)

2. Run inside your repo folder:

    ```bash
    cosign generate-key-pair
    ```

    
    - Do NOT put in a password when it asks you to, just press enter. The signing key will be used in GitHub Actions and will not work if it is encrypted.

> [!WARNING]
> Be careful to *never* accidentally commit `cosign.key` into your git repo.

3. Add the private key to GitHub

    - This can also be done manually. Go to your repository settings, under `Secrets and Variables` -> `Actions`
    ![image](https://user-images.githubusercontent.com/1264109/216735595-0ecf1b66-b9ee-439e-87d7-c8cc43c2110a.png)
    Add a new secret and name it `SIGNING_SECRET`, then paste the contents of `cosign.key` into the secret and save it. Make sure it's the .key file and not the .pub file. Once done, it should look like this:
    ![image](https://user-images.githubusercontent.com/1264109/216735690-2d19271f-cee2-45ac-a039-23e6a4c16b34.png)

    - (CLI instructions) If you have the `github-cli` installed, run:

    ```bash
    gh secret set SIGNING_SECRET < cosign.key
    ```

4. Commit the `cosign.pub` file to the root of your git repository.

# Community

- [**bootc discussion forums**](https://github.com/bootc-dev/bootc/discussions) - Nothing in this template is ublue specific, the upstream bootc project has a discussions forum where custom image builders can hang out and ask questions.

## Artifacthub

This template comes with the necessary tooling to index your image on [artifacthub.io](https://artifacthub.io), use the `artifacthub-repo.yml` file at the root to verify yourself as the publisher. This is important to you for a few reasons:

- The value of artifacthub is it's one place for people to index their custom images, and since we depend on each other to learn, it helps grow the community. 
- You get to see your pet project listed with the other cool projects in Cloud Native.
- Since the site puts your README front and center, it's a good way to learn how to write a good README, learn some marketing, finding your audience, etc. 

[Discussion thread](https://universal-blue.discourse.group/t/listing-your-custom-image-on-artifacthub/6446)

## Community Examples

- [m2os](https://github.com/m2giles/m2os)
- [bos](https://github.com/bsherman/bos)
- [homer](https://github.com/bketelsen/homer/)
