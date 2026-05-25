# Provisioning a Kiki OS node

Kiki OS images are **netinst-lean**: they ship the agent + runtime, and everything
machine-specific (which fleet to join, which model to run, login access) is
applied at **first boot** via provisioning — never baked into the image.

The `server` image enables **cloud-init**, so a node is provisioned by supplying
user-data (a cloud provider's user-data field, or a seed ISO for local VMs).

## What provisioning sets

agentd and the model-fetch oneshot read these from the environment, so
provisioning only needs to drop a systemd env drop-in + `/etc/kiki/model.env`:

| Variable | Read by | Purpose |
|---|---|---|
| `KIKI_FLEET_URL` | agentd | Fleet control-plane origin (node register + relay). Overrides `[fleet] cloud_url`. |
| `KIKI_FLEET_TOKEN` | agentd | Enrollment bearer token (skips the device-flow prompt). |
| `KIKI_MODEL_ID` | kiki-model-fetch | Logical model id agentd requests. |
| `KIKI_MODEL_URL` | kiki-model-fetch | GGUF weights URL fetched on first boot. |

See [`cloud-init/user-data.example.yaml`](cloud-init/user-data.example.yaml) for a
complete example. Adjust the SSH key, fleet endpoint/token, and model URL.

## Local VM (seed ISO)

```sh
# Build a seed ISO from the example and attach it as a second drive in QEMU/UTM.
cloud-localds dist/seed.iso ignition/cloud-init/user-data.example.yaml
# then add: -drive file=dist/seed.iso,if=virtio,format=raw
```

## Without provisioning

A node still boots fine with no user-data: agentd runs locally, the model-fetch
oneshot no-ops (no `KIKI_MODEL_URL`), and the node stays unbound to any fleet
until a model and/or fleet endpoint are provided later.
