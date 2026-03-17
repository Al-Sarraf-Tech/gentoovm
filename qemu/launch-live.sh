#!/usr/bin/env bash
set -euo pipefail

ISO=/home/jalsarraf/gentoo/gentoovm.iso
DISK=/home/jalsarraf/gentoo/qemu/test-disk.qcow2

# Create test disk if it doesn't exist
if [ ! -f "$DISK" ]; then
    qemu-img create -f qcow2 "$DISK" 50G
fi

exec qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 16384 \
    -drive file="$DISK",format=qcow2,if=virtio \
    -cdrom "$ISO" \
    -boot d \
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
    -name "GentooVM Live" \
    "$@"
