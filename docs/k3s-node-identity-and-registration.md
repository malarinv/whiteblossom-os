# Design: K3s Node Identity and Registration

## Problem

The cloud image is identical for every node. No secrets (cluster token, ZeroTier network ID, Vault credentials) can be baked into the image or injected at disk build time — doing so means every node shares the same secret, defeating the purpose of per-node authentication.

Nodes need a way to:
1. Prove their identity to a registration service
2. Be approved (manually or automatically)
3. Receive cluster secrets from OpenBao/Vault at runtime
4. Join the cluster with those secrets

## Threat Model

| Threat | Mitigation |
|--------|-----------|
| Cloned disk image impersonates a node | Each node generates its own keypair at first boot |
| Stolen image leaks cluster token | Token never leaves Vault, issued as short-lived bootstrap |
| Unauthorized node joins cluster | Registration service requires approval |
| Compromised node re-registers after revocation | Remove public key from allowlist; node can't authenticate |
| Man-in-the-middle on registration | Registration service runs on ZeroTier (trust boundary) |

## How Talos Linux Solves This

Talos uses a **four-layer cryptographic chain** with no pre-shared tokens:

```
Layer 1: Machine Identity
  Hardware UUID + partition labels → KDF → Node Identity Key (Ed25519)
  Public key = node identity, unique per physical machine

Layer 2: TPM Sealing
  TPM measures boot state (firmware, kernel, secure boot)
  Sealed keys released only if PCR measurements match
  Prevents cloned/moved nodes from authenticating

Layer 3: CSR-Based Join (OS level)
  Node signs CSR with its Node Identity Key
  Control plane (machined) validates against cluster CA
  Issues OS-level mTLS identity certificate

Layer 4: Kubernetes TLS Bootstrap
  kubelet submits K8s CSR
  Auto-approved by Talos components
  Node gets kubelet certificate, joins cluster
```

Key insight: **the node never holds the cluster token**. The control plane validates hardware identity and issues certificates. SideroLink/Omni maintains the allowlist of approved hardware identities.

## Adapted Architecture for k3s + bootc

k3s doesn't have Talos's machined daemon or TPM integration. We adapt the pattern:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Image Build (podman build)                       │
│                                                                     │
│  IDENTICAL for all nodes:                                           │
│  ├─ k3s binary                                                      │
│  ├─ ZeroTier                                                        │
│  ├─ Registration client (/usr/local/bin/wb-register)               │
│  ├─ First-boot service (k3s-join.service)                          │
│  └─ NO secrets, NO identity material                                │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼  (first boot)
┌─────────────────────────────────────────────────────────────────────┐
│                    Node First Boot                                   │
│                                                                     │
│  1. Generate Ed25519 keypair → /etc/whiteblossom/node-identity/     │
│  2. Read hardware UUID → /sys/class/dmi/id/product_uuid            │
│  3. Sign registration payload with node.key                        │
│  4. POST to registration service (via ZeroTier)                    │
│  5. Receive: k3s token (TTL 5m), server URL, ZT network, labels   │
│  6. Join ZeroTier, wait for IP                                     │
│  7. Write k3s config, start k3s agent                              │
│  8. k3s joins cluster                                              │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Registration Service                              │
│                    (in-cluster, accessible via ZeroTier)             │
│                                                                     │
│  POST /v1/register                                                  │
│  {                                                                  │
│    "public_key": "ssh-ed25519 AAAA...",                             │
│    "hardware_uuid": "a1b2c3d4-...",                                 │
│    "node_name": "k3s-edge-1",                                       │
│    "timestamp": "2025-07-10T12:00:00Z",                             │
│    "signature": "<HMAC-SHA256 of payload signed by node.key>"      │
│  }                                                                  │
│                                                                     │
│  Validation:                                                        │
│  ├─ Verify signature against public key                            │
│  ├─ Check public key in allowlist (ConfigMap or Vault)             │
│  ├─ Check hardware UUID in allowlist                               │
│  └─ Check timestamp freshness (replay protection)                  │
│                                                                     │
│  On approval:                                                       │
│  ├─ Call Vault: issue short-lived k3s bootstrap token (TTL 5m)    │
│  ├─ Authorize node on ZeroTier network (if ZT auth enabled)       │
│  ├─ Read Vault: server_url, zerotier_network, node_labels         │
│  └─ Return to node (signed response)                               │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    OpenBao / Vault                                   │
│                                                                     │
│  KV Engine (cluster secrets — never leave Vault):                  │
│  ├─ k3s/cluster-token    (long-lived, used to mint short tokens)   │
│  ├─ k3s/server-url       (172.28.28.28:6443)                      │
│  ├─ zerotier/network-id  (8286ac0e47f95192)                        │
│  └─ k3s/node-labels      (per-node label sets)                     │
│                                                                     │
│  PKI Engine (node certificates — Phase 2):                          │
│  ├─ Root CA for node identity verification                         │
│  └─ Issues short-lived node certs on approval                      │
│                                                                     │
│  Policy:                                                            │
│  ├─ registration-service: read k3s/*, read zerotier/*, mint token  │
│  └─ nodes: cannot read any Vault paths directly                    │
└─────────────────────────────────────────────────────────────────────┘
```

## Why the Image Must Be Identity-Free

```
WRONG: Identity baked at build time
  podman build → generates keypair → copies to image
  Result: every node has the same private key = shared secret

CORRECT: Identity generated at first boot
  podman build → image has zero identity material
  First boot → node generates its OWN keypair
  Result: each node has a unique identity
```

The image is a template. Identity is runtime, not buildtime.

## Registration Protocol

### Request (node → registration service)

```json
{
  "public_key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGk8...",
  "hardware_uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "node_name": "k3s-edge-1",
  "timestamp": "2025-07-10T12:00:00Z",
  "signature": "base64(HMAC-SHA256(node.key, payload_json))"
}
```

### Response (registration service → node)

```json
{
  "status": "approved",
  "k3s_token": "K1082...::server:0f70be14...",
  "k3s_token_ttl": 300,
  "server_url": "https://172.28.28.28:6443",
  "zerotier_network": "8286ac0e47f95192",
  "node_labels": [
    "topology.k8s.whiteblossom.net/site=cloud",
    "topology.k8s.whiteblossom.net/region=hyderabad"
  ]
}
```

The k3s token has a 5-minute TTL. The node uses it immediately to join. After joining, k3s issues its own kubelet certificate via standard TLS bootstrapping — the bootstrap token is discarded.

## Approval Modes

### Mode 1: Pre-approved allowlist (simplest)

Public keys and hardware UUIDs are stored in a Kubernetes ConfigMap. Registration service checks against it.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: approved-node-identities
  namespace: kube-system
data:
  # Public key → node metadata
  node-alpha.pub: |
    name: k3s-node-alpha
    hardware_uuid: "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
    labels:
      topology.k8s.whiteblossom.net/site: cloud
      topology.k8s.whiteblossom.net/region: hyderabad
      topology.k8s.whiteblossom.net/country: in
      topology.k8s.whiteblossom.net/location: oci
      node.longhorn.io/create-default-disk: "true"
  node-beta.pub: |
    name: k3s-node-beta
    hardware_uuid: "b2c3d4e5-f6a7-8901-bcde-f12345678901"
    labels:
      topology.k8s.whiteblossom.net/site: edge
      topology.k8s.whiteblossom.net/region: tirunelveli
      topology.k8s.whiteblossom.net/country: in
      topology.k8s.whiteblossom.net/location: origin
      node.longhorn.io/create-default-disk: "false"
```

### Mode 2: Manual approval via dashboard

Node registers → status is "pending" → admin approves via web UI or `kubectl`.

### Mode 3: Auto-approve with hardware UUID check

If the hardware UUID is in the allowlist, auto-approve. Otherwise, queue for manual approval. Good middle ground for known hardware.

## First-Boot Provisioning Script

```bash
#!/bin/bash
# /usr/local/bin/wb-register — WhiteBlossom node registration client
set -euo pipefail

IDENTITY_DIR="/etc/whiteblossom/node-identity"
REGISTRATION_URL="${WB_REGISTRATION_URL:-https://172.28.28.28:9443}"
PAYLOAD_FILE=$(mktemp)

# --- 1. Generate identity if first boot ---
if [ ! -f "$IDENTITY_DIR/node.key" ]; then
    mkdir -p "$IDENTITY_DIR"
    openssl genpkey -algorithm Ed25519 -out "$IDENTITY_DIR/node.key" 2>/dev/null
    openssl pkey -in "$IDENTITY_DIR/node.key" -pubout \
        -out "$IDENTITY_DIR/node.pub" 2>/dev/null
    chmod 0600 "$IDENTITY_DIR/node.key"
fi

# --- 2. Read hardware UUID ---
HW_UUID=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null || echo "unknown")
NODE_NAME=$(hostname)

# --- 3. Build and sign payload ---
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PUB_KEY=$(cat "$IDENTITY_DIR/node.pub")

PAYLOAD=$(cat <<EOF
{
  "public_key": "$PUB_KEY",
  "hardware_uuid": "$HW_UUID",
  "node_name": "$NODE_NAME",
  "timestamp": "$TIMESTAMP"
}
EOF
)

SIGNATURE=$(echo -n "$PAYLOAD" | \
    openssl dgst -sha256 -sign "$IDENTITY_DIR/node.key" | \
    base64 -w0)

# --- 4. Register ---
RESPONSE=$(curl -sf --max-time 30 \
    -X POST "$REGISTRATION_URL/v1/register" \
    -H "Content-Type: application/json" \
    -d "{\"payload\": $PAYLOAD, \"signature\": \"$SIGNATURE\"}")

STATUS=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")

if [ "$STATUS" != "approved" ]; then
    echo "Registration denied: $RESPONSE"
    exit 1
fi

# --- 5. Extract secrets ---
K3S_TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['k3s_token'])")
SERVER_URL=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['server_url'])")
ZT_NETWORK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['zerotier_network'])")

# --- 6. Join ZeroTier ---
zerotier-cli join "$ZT_NETWORK"
ZT_IFACE=$(zerotier-cli listnetworks -j | python3 -c "
import sys,json
for n in json.load(sys.stdin):
    if n.get('nwid') == '$ZT_NETWORK':
        print(n.get('portDevice','')); break
")

for i in $(seq 1 60); do
    ZT_IP=$(ip -4 addr show "$ZT_IFACE" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
    [ -n "$ZT_IP" ] && break
    sleep 1
done
[ -z "$ZT_IP" ] && { echo "ZeroTier IP timeout"; exit 1; }

# --- 7. Write k3s config ---
mkdir -p /etc/rancher/k3s /var/lib/rancher/k3s/server
echo "$K3S_TOKEN" > /var/lib/rancher/k3s/server/token
chmod 0600 /var/lib/rancher/k3s/server/token

EXTERNAL_IP=$(curl -sf --max-time 5 https://api.ipify.org || echo "$ZT_IP")

cat > /etc/rancher/k3s/config.yaml <<EOF
server: "$SERVER_URL"
token: "$K3S_TOKEN"
node-ip: "$ZT_IP"
node-name: "$NODE_NAME"
flannel-iface: "$ZT_IFACE"
node-external-ip: "$EXTERNAL_IP"
write-kubeconfig-mode: "0644"
disable:
  - servicelb
  - traefik
EOF

# Append labels from registration response
echo "$RESPONSE" | python3 -c "
import sys, json
labels = json.load(sys.stdin).get('node_labels', [])
for l in labels:
    print(f'  - \"{l}\"')
" >> /etc/rancher/k3s/config.yaml

# --- 8. Start k3s agent ---
systemctl enable --now k3s-agent.service
echo "k3s-join: agent started, joining $SERVER_URL"
```

## Registration Service

A lightweight Go or Python HTTP service. Deployed as a k3s Deployment + Service on the existing cluster (before new nodes join).

### Minimal Go skeleton

```go
package main

import (
    "crypto/ed25519"
    "encoding/json"
    "net/http"
    "time"
)

type RegistrationRequest struct {
    Payload struct {
        PublicKey    string `json:"public_key"`
        HardwareUUID string `json:"hardware_uuid"`
        NodeName     string `json:"node_name"`
        Timestamp    string `json:"timestamp"`
    } `json:"payload"`
    Signature string `json:"signature"`
}

type RegistrationResponse struct {
    Status          string   `json:"status"`
    K3sToken        string   `json:"k3s_token,omitempty"`
    K3sTokenTTL     int      `json:"k3s_token_ttl,omitempty"`
    ServerURL       string   `json:"server_url,omitempty"`
    ZerotierNetwork string   `json:"zerotier_network,omitempty"`
    NodeLabels      []string `json:"node_labels,omitempty"`
    Reason          string   `json:"reason,omitempty"`
}

func handleRegister(w http.ResponseWriter, r *http.Request) {
    var req RegistrationRequest
    json.NewDecoder(r.Body).Decode(&req)

    // 1. Verify timestamp freshness (5 min window)
    ts, _ := time.Parse(time.RFC3339, req.Payload.Timestamp)
    if time.Since(ts) > 5*time.Minute {
        respond(w, RegistrationResponse{Status: "rejected", Reason: "timestamp expired"})
        return
    }

    // 2. Verify signature against public key
    pubKeyBytes := parseEd25519PubKey(req.Payload.PublicKey)
    payloadBytes, _ := json.Marshal(req.Payload)
    sigBytes := base64Decode(req.Signature)
    if !ed25519.Verify(pubKeyBytes, payloadBytes, sigBytes) {
        respond(w, RegistrationResponse{Status: "rejected", Reason: "invalid signature"})
        return
    }

    // 3. Check allowlist (from ConfigMap or Vault)
    nodeMeta, found := lookupAllowlist(req.Payload.PublicKey, req.Payload.HardwareUUID)
    if !found {
        respond(w, RegistrationResponse{Status: "pending", Reason: "awaiting approval"})
        return
    }

    // 4. Fetch secrets from Vault
    secrets, _ := vaultClient.Read("secret/data/k3s/cluster")

    // 5. Mint short-lived bootstrap token
    // (k3s token create --ttl 5m, or via k3s API)

    respond(w, RegistrationResponse{
        Status:          "approved",
        K3sToken:        bootstrapToken,
        K3sTokenTTL:     300,
        ServerURL:       secrets["server_url"],
        ZerotierNetwork: secrets["zerotier_network"],
        NodeLabels:      nodeMeta.Labels,
    })
}
```

## OpenBao / Vault Setup

### Enable KV engine for cluster secrets

```bash
vault secrets enable -path=secret kv-v2

vault kv put secret/k3s/cluster \
    token="K1082460e741f329a75ac830a1ac68381aa48b41bb1814bf7e4760c16339a3441d6::server:0f70be14f3c3d13fa883b15477c1ca71" \
    server_url="https://172.28.28.28:6443" \
    zerotier_network="8286ac0e47f95192"
```

### Policy for registration service

```hcl
# registration-service.hcl
path "secret/data/k3s/cluster" {
  capabilities = ["read"]
}

path "secret/data/k3s/node-labels/*" {
  capabilities = ["read"]
}
```

### Bootstrap token minting

k3s supports short-lived tokens:

```bash
# On a control plane node, generate a 5-minute bootstrap token:
k3s token create --ttl 5m

# Or programmatically via the k3s API:
curl -sf -X POST https://172.28.28.28:6443/v1-k3s/token \
    -H "Authorization: Bearer $SERVER_TOKEN" \
    -d '{"ttl": "5m"}'
```

The registration service calls this endpoint, gets a short-lived token, and passes it to the registering node.

## Phased Implementation

### Phase 1: Registration service + short-lived tokens

**What:** Node generates keypair at first boot, registers, gets 5-minute k3s token from Vault.

**Files:**
- `build_files/cloud/k3s-join.bu` — Butane config with registration client
- `build_files/cloud/wb-register` — Registration client script
- `build_files/cloud/k3s-join.service` — First-boot systemd unit
- `registration-service/` — Go or Python service (new directory)
- `docs/k3s-node-identity-and-registration.md` — This document

**What's in the image:**
- k3s binary
- ZeroTier
- Registration client
- First-boot service
- NO secrets, NO identity material

**What's in Vault:**
- Cluster token (long-lived, used to mint short tokens)
- Server URL
- ZeroTier network ID
- Per-node label sets

### Phase 2: Node certificates (add later)

**What:** After joining, nodes get X.509 certificates from Vault PKI engine. Enables mutual TLS between nodes without relying on k3s token.

**Adds:**
- Vault PKI engine for node certificates
- Certificate renewal daemon on each node
- mTLS between k3s agents and registration service

### Phase 3: TPM attestation (if hardware supports it)

**What:** Seal node identity to TPM measurements. Prevents cloned disk images from authenticating.

**Adds:**
- TPM 2.0 interaction in registration client
- PCR measurement verification in registration service
- Most relevant for VM nodes (cloud providers support vTPM)

## Comparison with Previous Design

| Aspect | Previous (token in disk image) | New (registration service) |
|--------|-------------------------------|---------------------------|
| Secrets on node | Yes (injected at disk build) | No (fetched at runtime) |
| Image reuse | Per-node disk images | Single image, any node |
| Node identity | None (all nodes identical) | Ed25519 keypair + HW UUID |
| Approval | None | Allowlist or manual |
| Revocation | Rotate token (all nodes) | Remove from allowlist |
| Complexity | Trivial | Medium |
| Network dependency | None (secrets baked in) | Needs ZT network at first boot |

## Resolved Decisions

1. **ZeroTier authorization:** The registration service handles ZeroTier node authorization as part of the registration flow. After the node proves its identity, the service can authorize it on the ZeroTier network (if ZT auth is enabled). This means the ZT network join happens in two steps: (1) node joins network immediately on boot (network ID is public), (2) registration service authorizes the node's ZT identity for full access.

## Remaining Open Questions

1. **Registration service availability:** It runs in-cluster, but new nodes need it *before* they join. The service must be accessible via ZeroTier IP on an existing node. Should it run on the control plane VIP (`172.28.28.28`) or on a dedicated node?

2. **Fallback if registration fails:** If the registration service is down, the node can't join. Should there be a retry loop, or a fallback to manual provisioning?

3. **Token minting mechanism:** k3s `token create --ttl 5m` requires access to the control plane. The registration service needs the server token to call this. Where does the registration service get the server token — Vault, or hardcoded on the control plane?

4. **Vault deployment:** Is OpenBao/Vault already running somewhere, or does it need to be deployed? If not yet available, the registration service can hold secrets in memory and issue them directly (simpler, but less secure).

5. **Hardware UUID availability:** Not all VMs expose `/sys/class/dmi/id/product_uuid`. Cloud instances may need instance ID from metadata API instead. The registration client should fallback gracefully.
