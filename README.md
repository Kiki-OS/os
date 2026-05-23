# kiki-os

OS images for Kiki — a Linux-based operating system designed from the ground up for the agentic computing era. The AI agent is not an application running on top of the OS; it is the substrate of the system.

> **Kiki OS** targets RISC-V (primary), ARM, and x86\_64. Hardware classes range from sensor-class (256 MB RAM) to flagship devices.

---

## Design philosophy

Conventional operating systems (Linux, Android, iOS) were designed before the agentic shift. Patching an agent onto them produces structural compromises in permissions, memory, and lifecycle management. Kiki redesigns the OS from first principles so that the agent is the central privileged process.

Priorities, in order: **Safety > Privacy > Security > Reliability > Performance > Convenience**

---

## How it works

The OS is an OCI image built with Podman, distributed via a container registry, and applied atomically with `bootc switch <ref>`. Updates never leave the system in a broken state — OSTree provides implicit A/B partitions and automatic rollback.

```
┌──────────────────────────────────────────┐
│  OS image      → bootc (OSTree, A/B)     │
│  Apps          → OSTree refs in /var/kiki/store/   │
│  Components    → OSTree refs (dedup by SHA256)     │
│  Agent state   → OSTree commits per step           │
└──────────────────────────────────────────┘
```

---

## Image variants

| Image | Base | Purpose |
|---|---|---|
| `kiki-os-base` | `fedora-bootc:42` | Foundation for all profiles — agentd + core dirs |
| `kiki-os-desktop` | `kiki-os-base` | Full DE — Wayland compositor + OOBE provisioning |
| `kiki-os-server` | `kiki-os-base` | Headless fleet node — remote management, no GUI |
| `kiki-os-lite` | `fedora-bootc:42` | Constrained hardware — 512 MB RAM limit, ARM target |

---

## Repository structure

```
Containerfile.base       ← base image
Containerfile.desktop    ← desktop profile
Containerfile.server     ← server/headless profile
Containerfile.lite       ← resource-constrained profile
Makefile                 ← build targets
rootfs/                  ← systemd units, configs per profile
ignition/                ← provisioning configs
```

---

## Architecture layers

```
L10  Compositor + UI       (Wayland / kiki-wm)
L9   Agent harness         (agentd)
L8   Apps                  (sandboxed, capability-gated)
L7   Memory subsystem      (episodic / semantic / procedural / identity)
L6   IPC + capability gate (kiki-bus / MCP)
L5   Sandbox               (Landlock + seccomp + namespaces + cgroups)
L4   System services       (s6-rc / opkg / RAUC / network / HAL)
L3   Kernel                (Linux + Landlock LSM)
L2   Boot chain            (verified boot / A-B partitions via OSTree)
L1   Hardware              (hardware manifest TOML)
```

---

## Building

Requires Podman.

```sh
# Build the base image
make base

# Build a specific profile
make desktop
make server
make lite

# Override the default on-device model
podman build --build-arg DEFAULT_MODEL=llama3.2:3b -f Containerfile.base .
```

---

## Related repos

| Repo | Description |
|---|---|
| [agent](https://github.com/Kiki-OS/agent) | `agentd` — the central privileged daemon |
| [wm](https://github.com/Kiki-OS/wm) | Wayland compositor and desktop environment |
| [sdk](https://github.com/Kiki-OS/sdk) | Developer SDK for building Kiki apps |
| [app](https://github.com/Kiki-OS/app) | Companion mobile app |
| [cloud](https://github.com/Kiki-OS/cloud) | Optional cloud backend (fleet, OTA, AI gateway) |

---

## License

GNU General Public License v3.0 or later. See [LICENSE](LICENSE).
