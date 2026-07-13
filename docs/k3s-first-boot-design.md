# Design: K3s First-Boot Cluster Join via Butane/Ignition

> **See also:** [K3s Node Identity and Registration](k3s-node-identity-and-registration.md) —
> the security architecture for how nodes prove their identity and receive secrets at runtime,
> without baking them into the image or disk build.

## Problem

The WhiteBlossom OS cloud variant needs to join an existing k3s cluster (provisioned by `klustrap/ansible/playbooks/kluster.yaml`) automatically on first boot, without running Ansible against it. The cluster uses ZeroTier for networking, kube-vip for control plane VIP, and embedded etcd for state.

## Cluster Context

From `klustrap/ansible/playbooks/vars/main.yaml`:

| Parameter | Value |
|-----------|-------|
| ZeroTier network | `8286ac0e47f95192` |
| Control plane VIP | `172.28.28.28` |
| VIP CIDR | `/16` |
| Cluster token | `K1082460e...::server:0f70be14...` |
| k3s version | `v1.35.5+k3s1` |
| Flannel backend | `host-gw` (on ZeroTier interface) |
| Datastore | Embedded etcd |
| Disabled addons | `servicelb`, `traefik` |

Agent nodes join via `--server https://172.28.28.28:6443 --token-file /var/lib/rancher/k3s/server/token` and use the ZeroTier interface for flannel.

## Design Goals

1. **Single immutable image** — One k3s OCI image, deployed to any node (no per-node secrets baked in)
2. **Zero-touch first boot** — Node joins cluster automatically, no SSH/Ansible required
3. **Runtime secret retrieval** — Cluster token and secrets fetched from registration service at first boot (see [Node Identity and Registration](k3s-node-identity-and-registration.md))
4. **Non-secret per-node config at disk build time** — Node name, labels, location injected when creating the QCOW2/raw image
5. **Reproducible** — Butane YAML is the source of truth for first-boot logic
6. **Compatible with existing cluster** — Must match the playbook's k3s configuration exactly

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Image Build (podman build)                   │
│                                                                 │
│  Containerfile cloud stage (fedora-bootc:44):                   │
│  ├─ shared/build.sh          (tmux, system files, cleanup)      │
│  ├─ cloud/build.sh:                                            │
│  │   ├─ install-k3s.sh:                                        │
│  │   │   ├─ k3s binary → /usr/local/bin/k3s                   │
│  │   │   ├─ ZeroTier → zerotier-one                            │
│  │   │   └─ Dependencies (curl, iproute, python3, openssl)    │
│  │   └─ configure-cluster.sh:                                  │
│  │       ├─ wb-register.service (first-boot registration)      │
│  │       ├─ k3s-config.service (write k3s config)             │
│  │       └─ k3s-agent.service.d/override.conf (ordering)      │
│  ├─ system_files/cloud/:                                       │
│  │   ├─ /usr/local/bin/wb-register (registration client)      │
│  │   └─ /usr/local/bin/k3s-config-write (config writer)       │
│  ├─ ostree container commit                                     │
│  └─ bootc container lint                                        │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                Disk Build (bootc-image-builder)                 │
│                                                                 │
│  Output: QCOW2 / raw disk (no per-node secrets baked in)       │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    First Boot (VM / bare metal)                 │
│                                                                 │
│  1. ZeroTier starts, joins network (network ID in image)       │
│  2. wb-register.service runs registration client               │
│  3. Client proves identity → gets k3s token + config           │
│  4. k3s-config.service writes /etc/rancher/k3s/config.yaml    │
│  5. k3s-agent.service starts, joins cluster                    │
│  6. Node appears in cluster with correct labels                 │
└─────────────────────────────────────────────────────────────────┘
```

## File Layout

### In the Containerfile (build time)

```
build_files/cloud/
├── build.sh                    # Main orchestrator
├── install-k3s.sh              # k3s binary + dependencies
├── configure-cluster.sh        # systemd units, disabled services
├── k3s-join.bu                 # Butane source → transpiled to .ign
└── k3s-join.sh                 # Provisioning script (also in .bu)

system_files/cloud/
└── (currently empty — contents come from Butane)
```

### On the running node (first boot)

```
/usr/lib/ignition/config.ign          # Embedded Ignition config
/usr/local/bin/k3s                    # k3s binary (from build)
/usr/local/bin/k3s-join.sh            # Provisioning script
/etc/k3s-node-config.yaml             # Per-node config (injected at disk build)
/etc/rancher/k3s/config.yaml          # Generated by k3s-join.sh
/usr/lib/systemd/system/k3s-join.service  # First-boot service
```

## Butane Configuration

```yaml
variant: fcos
version: 1.5.0

storage:
  files:
    # Per-node config — overwritten at disk build time
    - path: /etc/k3s-node-config.yaml
      mode: 0600
      overwrite: false
      contents:
        inline: |
          # PLACEHOLDER: Overwritten at disk build time
          # with actual cluster credentials

    # Provisioning script
    - path: /usr/local/bin/k3s-join.sh
      mode: 0755
      overwrite: true
      contents:
        inline: |
          #!/bin/bash
          set -euo pipefail

          CONFIG="/etc/k3s-node-config.yaml"
          K3S_CONFIG="/etc/rancher/k3s/config.yaml"
          K3S_TOKEN_FILE="/var/lib/rancher/k3s/server/token"

          # --- Parse YAML (no yq dependency) ---
          yaml_val() { grep "^$1:" "$CONFIG" | head -1 | sed 's/^[^:]*: *//' | tr -d '"' ; }
          yaml_list() { grep "^  - " "$CONFIG" | sed 's/^  - //' ; }

          CLUSTER_TOKEN=$(yaml_val cluster_token)
          SERVER_URL=$(yaml_val server_url)
          ZT_NETWORK=$(yaml_val zerotier_network)
          NODE_NAME=$(yaml_val node_name)

          # --- 1. Join ZeroTier ---
          zerotier-cli join "$ZT_NETWORK"

          # --- 2. Wait for ZeroTier IP (60s timeout) ---
          ZT_IFACE=$(zerotier-cli listnetworks -j | python3 -c "
          import sys,json
          nets = json.load(sys.stdin)
          for n in nets:
              if n.get('nwid') == '$ZT_NETWORK':
                  print(n.get('portDevice',''))
                  break
          ")

          for i in $(seq 1 60); do
              ZT_IP=$(ip -4 addr show "$ZT_IFACE" 2>/dev/null \
                  | grep -oP 'inet \K[\d.]+' | head -1)
              [ -n "$ZT_IP" ] && break
              sleep 1
          done
          [ -z "$ZT_IP" ] && { echo "ERROR: ZeroTier IP not acquired"; exit 1; }

          # --- 3. Write k3s agent config ---
          mkdir -p /etc/rancher/k3s
          cat > "$K3S_CONFIG" <<EOF
          server: "$SERVER_URL"
          token: "$CLUSTER_TOKEN"
          node-ip: "$ZT_IP"
          node-name: "$NODE_NAME"
          flannel-iface: "$ZT_IFACE"
          node-external-ip: "$(curl -s https://api.ipify.org || echo $ZT_IP)"
          write-kubeconfig-mode: "0644"
          disable:
            - servicelb
            - traefik
          EOF

          # --- 4. Write node labels ---
          while IFS= read -r label; do
              echo "    - \"$label\"" >> "$K3S_CONFIG"
          done < <(yaml_list node_labels)

          # --- 5. Write cluster token file ---
          mkdir -p /var/lib/rancher/k3s/server
          echo "$CLUSTER_TOKEN" > "$K3S_TOKEN_FILE"
          chmod 0600 "$K3S_TOKEN_FILE"

          # --- 6. Install k3s (skip enable, we manage the service) ---
          curl -sfL https://get.k3s.io | \
              INSTALL_K3S_SKIP_ENABLE=true \
              INSTALL_K3S_VERSION="${K3S_VERSION:-v1.35.5+k3s1}" \
              sh -

          # --- 7. Start k3s agent ---
          systemctl enable --now k3s-agent.service

          echo "k3s-join: agent started, joining $SERVER_URL"

    # k3s agent config template (reference, not used directly)
    - path: /usr/share/k3s-join/config.yaml.template
      mode: 0644
      overwrite: true
      contents:
        inline: |
          server: "{{SERVER_URL}}"
          token: "{{CLUSTER_TOKEN}}"
          node-ip: "{{ZT_IP}}"
          node-name: "{{NODE_NAME}}"
          flannel-iface: "{{ZT_IFACE}}"
          write-kubeconfig-mode: "0644"
          disable:
            - servicelb
            - traefik

    # Registry config for code.dev.whiteblossom.net
    - path: /etc/rancher/k3s/registries.yaml
      mode: 0644
      overwrite: true
      contents:
        inline: |
          mirrors:
            "code.dev.whiteblossom.net":
              endpoint:
                - "https://code.dev.whiteblossom.net"

systemd:
  units:
    # k3s agent join — runs once on first boot
    - name: k3s-join.service
      enabled: true
      contents: |
        [Unit]
        Description=K3s First-Boot Cluster Join
        ConditionFirstBoot=yes
        After=network-online.target zerotier-one.service
        Wants=network-online.target
        After=network-online.target

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/usr/local/bin/k3s-join.sh
        StandardOutput=journal
        StandardError=journal
        TimeoutStartSec=300

        [Install]
        WantedBy=multi-user.target

    # Ensure ZeroTier starts before k3s-join
    - name: zerotier-one.service
      enabled: true
```

## Per-Node Config Format

Each node gets a YAML file injected at disk build time:

```yaml
# node-alpha.yaml — deployed to /etc/k3s-node-config.yaml
cluster_token: "K1082460e741f329a75ac830a1ac68381aa48b41bb1814bf7e4760c16339a3441d6::server:0f70be14f3c3d13fa883b15477c1ca71"
server_url: "https://172.28.28.28:6443"
zerotier_network: "8286ac0e47f95192"
node_name: "k3s-node-alpha"
node_labels:
  - "topology.k8s.whiteblossom.net/location=hyderabad"
  - "topology.k8s.whiteblossom.net/region=hyderabad"
  - "topology.k8s.whiteblossom.net/country=in"
  - "topology.k8s.whiteblossom.net/site=cloud"
  - "topology.k8s.whiteblossom.net/storage=longhorn"
  - "topology.k8s.whiteblossom.net/gateway=true"
  - "public.k8s.whiteblossom.net/ip=1.2.3.4"
  - "node.longhorn.io/create-default-disk=true"
```

## Build Commands

### Build the image

```bash
# Transpile Butane → Ignition
butane --strict build_files/cloud/k3s-join.bu > k3s-join.ign

# Build container image
podman build --target cloud -t whiteblossom-cloud:latest .
```

### Build a disk for a specific node

```bash
# Create per-node config
cat > nodes/node-alpha.yaml <<EOF
cluster_token: "K1082460e..."
server_url: "https://172.28.28.28:6443"
zerotier_network: "8286ac0e47f95192"
node_name: "k3s-node-alpha"
node_labels:
  - "topology.k8s.whiteblossom.net/site=cloud"
EOF

# Build QCOW2 with per-node config injected
sudo podman run --rm --privileged \
  -v ./nodes/node-alpha.yaml:/config/files/etc/k3s-node-config.yaml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 \
  localhost/whiteblossom-cloud:latest
```

### Using Justfile

```bash
# Build cloud image
just build cloud

# Build cloud disk (needs node config)
just build-qcow2 cloud

# Boot cloud node
just boot-cloud
```

## bootc-image-builder Config Injection

The `bootc-image-builder` supports injecting files via volume mounts:

```bash
# Mount the per-node config into the builder
-v ./nodes/node-alpha.yaml:/config/files/etc/k3s-node-config.yaml:ro
```

This places the file at `/etc/k3s-node-config.yaml` in the output disk image. The Ignition config (`config.ign`) sets `overwrite: false` for this path, so the injected file takes precedence over the placeholder.

Alternatively, use the `--config` flag with a `config.toml`:

```toml
# config.toml (osbuild blueprint format)
[[customizations.files]]
path = "/etc/k3s-node-config.yaml"
data = """
cluster_token: "K1082460e..."
server_url: "https://172.28.28.28:6443"
"""
mode = 0600
```

## What This Doesn't Cover (Future Work)

### Control plane nodes

The current design is for **agent (worker) nodes only**. Control plane nodes need:
- kube-vip manifest generation (requires Docker + the kube-vip template)
- `--cluster-init` flag for the first control node
- `--server` flag pointing to existing cluster for additional control nodes
- etcd snapshot/restore capability

For control plane nodes, the Ansible playbook (`kluster.yaml`) is still the right tool. The image provides the prerequisites; the playbook handles the complex control plane bootstrap.

### Longhorn storage

Longhorn requires:
- Block devices (the playbook sets `node.longhorn.io/create-default-disk={{ longhorn_disk }}`)
- The Longhorn Helm chart deployed to the cluster

The node label `node.longhorn.io/create-default-disk=true` tells Longhorn to create a disk on that node. The Longhorn deployment itself is a cluster-level concern.

### Registry TLS

The playbook copies a Let's Encrypt staging CA bundle to `/etc/rancher/k3s/certs.d/code.dev.whiteblossom.net/ca.crt`. This could be baked into the image or injected per-node.

### Node updates

With bootc, updating the k3s version means:
1. Update `K3S_VERSION` in the Butane config / Containerfile
2. Rebuild the image: `podman build --target cloud ...`
3. On the running node: `bootc upgrade`

The k3s-join service has `ConditionFirstBoot=yes`, so upgrades don't re-run the join logic.

## Comparison with Ansible Approach

| Aspect | Ansible (current) | Butane/Ignition (proposed) |
|--------|-------------------|---------------------------|
| Prerequisites | SSH, Python, sudo | None (image is self-contained) |
| Config delivery | Inventory YAML | `/etc/k3s-node-config.yaml` |
| First boot | Manual playbook run | Automatic |
| k3s version | Playbook variable | Baked into image |
| Token management | Playbook variable | Per-node config file |
| ZeroTier setup | Playbook role | Pre-installed in image |
| kube-vip | Generated at boot | Not covered (agent only) |
| Updates | Re-run playbook | `bootc upgrade` + rebuild |
| Multi-arch | Works (Ansible is arch-agnostic) | Needs per-arch images |

## Resolved Decisions

1. **Butane as build dependency:** Use `butane` via mise tools. Install from GitHub registry (like surge) if needed. Butane validates the YAML at build time; the transpiled Ignition config is embedded in the image.

2. **No monolithic k3s-join.sh:** Use multiple idempotent systemd units instead:
   - `wb-register.service` — runs registration client, writes secrets
   - `k3s-config.service` — writes k3s config from registration response
   - `k3s-agent.service.d/override.conf` — ensures agent starts after config
   Each unit checks `ConditionPathExists` for idempotency. No custom provisioning script needed.

3. **Include k3s binary in image:** The k3s binary is baked into the image during build. No network dependency on first boot for k3s installation.

4. **ZeroTier in image:** ZeroTier is installed during build and enabled by default. The ZeroTier network ID is public configuration baked into the image — it's not a secret. The node joins the network immediately on boot, then contacts the registration service via ZeroTier.

5. **Registration service handles ZeroTier authorization:** The registration service can authorize ZeroTier nodes as part of the registration flow. After the node proves its identity, the service can issue ZeroTier-specific authorization (network tokens, etc.) alongside k3s tokens.

6. **Secret delivery:** Runtime registration only. No per-node secrets baked into the image or injected at disk build time. The node generates its identity at first boot, registers with the service, and receives short-lived tokens.

## Remaining Open Questions

1. **Registration service availability:** It runs in-cluster, but new nodes need it *before* they join. The service must be accessible via ZeroTier IP on an existing node. Should it run on the control plane VIP (`172.28.28.28`) or on a dedicated node?

2. **Fallback if registration fails:** If the registration service is down, the node can't join. Should there be a retry loop, or a fallback to manual provisioning?

3. **Vault deployment:** Is OpenBao/Vault already running somewhere, or does it need to be deployed? If not yet available, the registration service can hold secrets in memory and issue them directly (simpler, but less secure).

4. **Hardware UUID availability:** Not all VMs expose `/sys/class/dmi/id/product_uuid`. Cloud instances may need instance ID from metadata API instead. The registration client should fallback gracefully.

## Implementation Steps

1. ✅ Create `build_files/cloud/install-k3s.sh` — k3s binary + ZeroTier + dependencies
2. ✅ Create `build_files/cloud/configure-cluster.sh` — systemd units (wb-register, k3s-config, k3s-agent override)
3. ✅ Create `system_files/cloud/usr/local/bin/wb-register` — Registration client
4. ✅ Create `system_files/cloud/usr/local/bin/k3s-config-write` — Config writer
5. ✅ Update `build_files/cloud/build.sh` — Orchestrator
6. ✅ Update `Containerfile` cloud stage — fedora-bootc:44 base
7. Install Butane via mise — build dependency for Ignition config validation
8. Create `build_files/cloud/k3s-join.bu` — Butane config (if needed for Ignition-based provisioning)
9. Create `registration-service/` — Identity registration service
10. Update `Justfile` — cloud-specific build commands
11. Update `docs/iso-build.md` — Add cloud section
