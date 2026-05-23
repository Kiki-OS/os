VERSION ?= $(shell git describe --tags --always --dirty)
REGISTRY ?= ghcr.io/kiki-os

.PHONY: all build-base build-desktop build-server build-lite iso qcow2 ami clean

all: build-desktop build-server build-lite

build-base:
	podman build -f Containerfile.base \
		-t $(REGISTRY)/kiki-os-base:$(VERSION) \
		-t $(REGISTRY)/kiki-os-base:latest .

build-desktop: build-base
	podman build -f Containerfile.desktop \
		-t $(REGISTRY)/kiki-os-desktop:$(VERSION) \
		-t $(REGISTRY)/kiki-os-desktop:latest .

build-server: build-base
	podman build -f Containerfile.server \
		-t $(REGISTRY)/kiki-os-server:$(VERSION) \
		-t $(REGISTRY)/kiki-os-server:latest .

build-lite: build-base
	podman build --platform linux/arm64 -f Containerfile.lite \
		-t $(REGISTRY)/kiki-os-lite:$(VERSION) \
		-t $(REGISTRY)/kiki-os-lite:latest .

iso: build-desktop
	image-builder build \
		--image-ref $(REGISTRY)/kiki-os-desktop:$(VERSION) \
		--output-dir dist/ \
		--type iso

qcow2: build-server
	image-builder build \
		--image-ref $(REGISTRY)/kiki-os-server:$(VERSION) \
		--output-dir dist/ \
		--type qcow2

ami: build-server
	image-builder build \
		--image-ref $(REGISTRY)/kiki-os-server:$(VERSION) \
		--output-dir dist/ \
		--type ami

dev-vm: iso
	qemu-system-x86_64 \
		-enable-kvm -m 4G -smp 2 \
		-cdrom dist/kiki-os-desktop-$(VERSION).iso \
		-boot d

clean:
	rm -rf dist/
