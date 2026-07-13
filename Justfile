export image_name := env("IMAGE_NAME", "whiteblossom")
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $target_image - The tag you want to apply to the image (default: $image_name).
#   $tag - The tag for the image (default: $default_tag).
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $target_image $tag
#
# Example usage:
#   just build aurora lts
#
# This will build an image 'aurora:lts' with DX and GDX enabled.
#

# Build a specific variant (workstation, iot, cloud, handheld)
build variant="workstation" $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    BUILD_ARGS=()
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --no-cache \
        --target "${variant}" \
        --tag "${target_image}:${tag}" \
        .

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo rm -rf "output/${type}"
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Podman builds the image from the Containerfile and creates a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (deafult: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_rebuild-bib $target_image $tag $type $config $variant="workstation": (build variant target_image tag) && (_build-bib target_image tag type config)

# Build QCOW2 for a specific variant
[group('Build Virtal Machine Image')]
build-qcow2 variant="workstation" $target_image=("localhost/" + image_name) $tag=default_tag:
    @just _build-bib {{target_image}} {{tag}} "qcow2" "disk_config/{{variant}}.toml"

# Build RAW for a specific variant
[group('Build Virtal Machine Image')]
build-raw variant="workstation" $target_image=("localhost/" + image_name) $tag=default_tag:
    @just _build-bib {{target_image}} {{tag}} "raw" "disk_config/{{variant}}.toml"

# Build ISO for a specific variant
[group('Build Virtal Machine Image')]
build-iso variant="workstation" $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "iso" "disk_config/iso.toml")

# Rebuild QCOW2 for a specific variant
[group('Build Virtal Machine Image')]
rebuild-qcow2 variant="workstation" $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/{{variant}}.toml" variant)

# Rebuild RAW for a specific variant
[group('Build Virtal Machine Image')]
rebuild-raw variant="workstation" $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/{{variant}}.toml" variant)

# Rebuild ISO for a specific variant
[group('Build Virtal Machine Image')]
rebuild-iso variant="workstation" $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "iso" "disk_config/iso.toml" variant)

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}


# ============================================================================
# Dev Boot: Direct kernel boot from container image (skips BIB)
# Fast dev loop for cloud/IoT variants (~5 second boot)
# Requires: virtiofsd, qemu-system-x86_64, KVM
# Usage: just dev-boot cloud
# ============================================================================
[group('Dev Boot')]
_dev-boot $variant $target_image $tag:
    #!/usr/bin/env bash
    set -euo pipefail

    # Validate variant
    if [[ "$variant" != "cloud" && "$variant" != "iot" ]]; then
        echo "Error: dev-boot only supports cloud and iot variants"
        echo "Workstation/handheld require BIB (bootc-image-builder)"
        exit 1
    fi

    # Check prerequisites
    if ! command -v virtiofsd &>/dev/null; then
        echo "Error: virtiofsd not found. Install: dnf install virtiofsd"
        exit 1
    fi

    if ! [ -e /dev/kvm ]; then
        echo "Error: /dev/kvm not found. KVM acceleration required."
        exit 1
    fi

    # Check if image exists
    IMAGE_TAG="${target_image}:${tag}"
    if ! podman image exists "$IMAGE_TAG" 2>/dev/null; then
        echo "Image not found: $IMAGE_TAG"
        echo "Build first: just build ${variant}"
        exit 1
    fi

    # Create container from image
    CONTAINER_ID=$(podman create "$IMAGE_TAG" /bin/true)
    echo "Created container: ${CONTAINER_ID:0:12}"

    # Global variables for cleanup
    QEMU_PID=""
    SOCK_DIR=""
    MNT_DIR=""

    # Cleanup function
    cleanup() {
        echo ""
        echo "Shutting down..."
        # Kill virtiofsd if running
        if [ -n "$SOCK_DIR" ] && [ -f "${SOCK_DIR}/virtiofsd.pid" ]; then
            kill "$(cat "${SOCK_DIR}/virtiofsd.pid")" 2>/dev/null || true
        fi
        # Stop QEMU if running
        if [ -n "$QEMU_PID" ] && kill -0 "$QEMU_PID" 2>/dev/null; then
            kill "$QEMU_PID" 2>/dev/null || true
            wait "$QEMU_PID" 2>/dev/null || true
        fi
        # Unmount and remove container
        if [ -n "$CONTAINER_ID" ]; then
            podman unmount "$CONTAINER_ID" 2>/dev/null || true
            podman rm "$CONTAINER_ID" 2>/dev/null || true
        fi
        # Remove temp dirs
        [ -n "$MNT_DIR" ] && rm -rf "$MNT_DIR"
        [ -n "$SOCK_DIR" ] && rm -rf "$SOCK_DIR"
        echo "Cleanup complete."
    }
    trap cleanup EXIT

    # Mount container rootfs
    echo "Mounting container rootfs..."
    MNT_DIR=$(mktemp -d -t wb-dev-mnt-XXXXXX)
    ROOTFS_PATH=$(podman mount "$CONTAINER_ID")
    echo "Rootfs: $ROOTFS_PATH"

    # Find kernel and initramfs
    KERNEL_PATH=$(find "$ROOTFS_PATH/boot" -maxdepth 1 -name "vmlinuz-*" | head -n 1)
    INITRD_PATH=$(find "$ROOTFS_PATH/boot" -maxdepth 1 -name "initramfs-*" | head -n 1)

    if [ -z "$KERNEL_PATH" ] || [ -z "$INITRD_PATH" ]; then
        echo "Error: Could not find kernel/initramfs in container /boot"
        echo "Contents of /boot:"
        ls -la "$ROOTFS_PATH/boot/" 2>/dev/null || echo "  (empty or missing)"
        exit 1
    fi

    echo "Kernel: $(basename "$KERNEL_PATH")"
    echo "Initrd: $(basename "$INITRD_PATH")"

    # Spawn virtiofsd
    SOCK_DIR=$(mktemp -d -t wb-dev-sock-XXXXXX)
    VHOST_SOCK="${SOCK_DIR}/vhost-fs.sock"

    echo "Starting virtiofsd..."
    virtiofsd \
        --socket-path="$VHOST_SOCK" \
        --shared-dir="$ROOTFS_PATH" \
        --sandbox none \
        --cache none &
    echo $! > "${SOCK_DIR}/virtiofsd.pid"

    # Wait for socket
    while [ ! -S "$VHOST_SOCK" ]; do
        sleep 0.1
    done
    echo "virtiofsd ready."

    # Determine SSH port
    SSH_PORT=2222
    while ss -tunalp | grep -q ":${SSH_PORT}"; do
        SSH_PORT=$((SSH_PORT + 1))
    done

    # SSH key handling
    SSH_KEY_ARG=""
    if [ -f "$HOME/.ssh/wb-dev.pub" ]; then
        SSH_KEY_ARG="-fw_cfg name=opt/io.systemd.credentials/ssh.authorized_keys.root,file=$HOME/.ssh/wb-dev.pub"
        echo "SSH key: $HOME/.ssh/wb-dev.pub"
    else
        echo "Warning: No SSH key at ~/.ssh/wb-dev.pub"
        echo "  Create one: ssh-keygen -t ed25519 -f ~/.ssh/wb-dev -N ''"
    fi

    echo ""
    echo "Starting QEMU (dev-boot mode)..."
    echo "SSH: ssh -p ${SSH_PORT} -o StrictHostKeyChecking=no -i ~/.ssh/wb-dev root@localhost"
    echo "Press Ctrl-A X to exit QEMU"
    echo ""

    # Determine memory based on variant
    MEMORY="4096"
    SMP="2"
    if [ "$variant" = "iot" ]; then
        MEMORY="2048"
        SMP="1"
    fi

    # Boot QEMU
    qemu-system-x86_64 \
        -enable-kvm \
        -m "$MEMORY" \
        -smp "$SMP" \
        -cpu host \
        -nographic \
        -serial mon:stdio \
        -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
        -device virtio-net-pci,netdev=net0 \
        -kernel "$KERNEL_PATH" \
        -initrd "$INITRD_PATH" \
        -append "root=wb_dev_root rw rootfstype=virtiofs console=ttyS0 loglevel=7" \
        -chardev socket,id=char0,path="$VHOST_SOCK" \
        -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=wb_dev_root \
        -object memory-backend-file,id=mem,size=${MEMORY}M,mem-path=/dev/shm,share=on \
        -numa node,memdev=mem \
        $SSH_KEY_ARG &
    QEMU_PID=$!

    # Wait for QEMU to exit
    wait "$QEMU_PID" || true

# Dev boot convenience recipes
[group('Dev Boot')]
dev-boot-cloud: (_dev-boot "cloud" "localhost/whiteblossom-cloud" "latest")

[group('Dev Boot')]
dev-boot-iot: (_dev-boot "iot" "localhost/whiteblossom-iot" "latest")
# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
