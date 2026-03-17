#!/usr/bin/env bash
set -euo pipefail

DISK="${1:-/home/jalsarraf/gentoo/qemu/test-disk.qcow2}"

if [ ! -f "$DISK" ]; then
    echo "ERROR: Disk image not found: $DISK"
    exit 1
fi

exec qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 16384 \
    -drive file="$DISK",format=qcow2,if=virtio \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -device virtio-vga-gl \
    -device virtio-balloon \
    -device qemu-xhci \
    -device usb-tablet \
    -chardev spicevmc,id=vdagent,debug=0,name=vdagent \
    -device virtio-serial-pci \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \
    -spice port=5930,disable-ticketing=on \
    -display gtk,gl=on \
    -name "GentooVM Installed" \
    "$@"
