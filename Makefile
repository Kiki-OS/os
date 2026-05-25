# Kiki OS image builds.
#
# The image build compiles agentd + the built-in apps from the sibling repos
# (kiki-agent, kiki-sdk, kiki-builtin), so the build CONTEXT is the workspace
# parent directory (..), with a .containerignore there keeping it lean. Run
# `make` from this directory (kiki-os/).
#
# Headless targets (base/server/lite) are the supported path today. `desktop`
# additionally needs the Wayland compositor (kiki-de) and OOBE, which are not
# built yet — it is kept for reference but excluded from `all`.

VERSION  ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
REGISTRY ?= ghcr.io/kiki-os
CONTEXT  := ..
PLATFORM ?= linux/arm64

.PHONY: all headless build-base build-server build-lite build-desktop \
        build-cloud push-cloud qcow2 run-vm clean \
        push push-base push-server push-lite

# Default: the headless image set.
all: headless
headless: build-server build-lite

build-base:
	podman build --platform $(PLATFORM) -f Containerfile.base \
		-t $(REGISTRY)/kiki-os-base:$(VERSION) \
		-t $(REGISTRY)/kiki-os-base:latest \
		-t kiki-base:latest \
		$(CONTEXT)

build-server: build-base
	podman build --platform $(PLATFORM) -f Containerfile.server \
		-t $(REGISTRY)/kiki-os-server:$(VERSION) \
		-t $(REGISTRY)/kiki-os-server:latest \
		-t kiki-server:latest \
		$(CONTEXT)

build-lite: build-base
	podman build --platform $(PLATFORM) -f Containerfile.lite \
		-t $(REGISTRY)/kiki-os-lite:$(VERSION) \
		-t $(REGISTRY)/kiki-os-lite:latest \
		-t kiki-lite:latest \
		$(CONTEXT)

# Requires the compositor (kiki-de) + OOBE images — not built yet.
build-desktop: build-base
	podman build --platform $(PLATFORM) -f Containerfile.desktop \
		-t $(REGISTRY)/kiki-os-desktop:$(VERSION) \
		-t $(REGISTRY)/kiki-os-desktop:latest \
		$(CONTEXT)

# ── Cloud session image (Cloudflare Containers) ──────────────────────────────
#
# A plain OCI container (NOT bootc) that runs agentd to host a migrated agentic
# session in the cloud. Standalone — it recompiles agentd onto a slim runtime
# rather than extending kiki-base. Cloudflare Containers require linux/amd64, so
# this target pins the platform regardless of the build host.
CLOUD_PLATFORM ?= linux/amd64

build-cloud:
	podman build --platform $(CLOUD_PLATFORM) -f Containerfile.cloud \
		-t $(REGISTRY)/kiki-os-cloud:$(VERSION) \
		-t $(REGISTRY)/kiki-os-cloud:latest \
		-t kiki-os-cloud:latest \
		$(CONTEXT)

# Push to the Cloudflare Registry — the registry CF Containers pulls from
# (alongside Docker Hub / ECR; ghcr is NOT supported). The fleet worker's
# [[containers]] block references this image ref. Requires CF_ACCOUNT_ID and a
# logged-in wrangler.
CF_ACCOUNT_ID ?= 329324a4ef92063153c879fd1b209669
CLOUD_REF      = registry.cloudflare.com/$(CF_ACCOUNT_ID)/kiki-os-cloud:$(VERSION)

push-cloud: build-cloud
	podman tag kiki-os-cloud:latest $(CLOUD_REF)
	wrangler containers push $(CLOUD_REF)

# ── Bootable disk + VM ───────────────────────────────────────────────────────
#
# bootc-image-builder turns the OCI image into a bootable qcow2. It runs
# privileged and writes to ./dist. IMAGE selects which image to convert.
IMAGE ?= kiki-server:latest

qcow2: build-server
	mkdir -p dist
	podman run --rm -it --privileged \
		--security-opt label=type:unconfined_t \
		-v ./dist:/output \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		quay.io/centos-bootc/bootc-image-builder:latest \
		build --type qcow2 --local $(IMAGE)

# Boot the produced qcow2 in QEMU (Apple Silicon: aarch64 + HVF accel).
run-vm:
	qemu-system-aarch64 \
		-machine virt,accel=hvf -cpu host -smp 2 -m 4G \
		-bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
		-drive file=dist/qcow2/disk.qcow2,if=virtio,format=qcow2 \
		-netdev user,id=net0,hostfwd=tcp::2222-:22 \
		-device virtio-net-pci,netdev=net0 \
		-nographic

clean:
	rm -rf dist/

# ── Registry push ─────────────────────────────────────────────────────────────
#
# Push built OS images to the registry (GHCR by default). Requires a prior
# `podman login ghcr.io`. CI does this automatically (.github/workflows/build.yml).
push: push-base push-server push-lite

push-base:
	podman push $(REGISTRY)/kiki-os-base:$(VERSION)
	podman push $(REGISTRY)/kiki-os-base:latest

push-server:
	podman push $(REGISTRY)/kiki-os-server:$(VERSION)
	podman push $(REGISTRY)/kiki-os-server:latest

push-lite:
	podman push $(REGISTRY)/kiki-os-lite:$(VERSION)
	podman push $(REGISTRY)/kiki-os-lite:latest
