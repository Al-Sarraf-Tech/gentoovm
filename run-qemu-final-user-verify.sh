#!/usr/bin/env bash
set -euo pipefail

# Stage 10: Final user-facing QEMU launch for manual verification
DISK="${1:-/home/jalsarraf/gentoo/qemu/test-disk.qcow2}"
ISO="/home/jalsarraf/gentoo/gentoovm.iso"

# Determine display mode
DISPLAY_MODE="${DISPLAY_MODE:-auto}"
if [ "$DISPLAY_MODE" = "auto" ]; then
    if [ -n "${DISPLAY:-}" ]; then
        DISPLAY_MODE="gtk"
    else
        DISPLAY_MODE="vnc"
    fi
fi

case "$DISPLAY_MODE" in
    gtk)  DISPLAY_ARGS="-display gtk" ;;
    vnc)  DISPLAY_ARGS="-display vnc=:0" ;;
    spice) DISPLAY_ARGS="-display spice-app" ;;
    *)    DISPLAY_ARGS="-display vnc=:0" ;;
esac

echo "=========================================="
echo "  GentooVM - Final Manual Verification"
echo "=========================================="
echo ""
echo "Display: $DISPLAY_MODE"

# Decide boot mode
if [ -f "$ISO" ] && [ -f "$DISK" ]; then
    DISK_SIZE=$(stat -c%s "$DISK" 2>/dev/null || echo 0)
    if [ "$DISK_SIZE" -lt 1073741824 ]; then
        echo "Boot mode: Live ISO (fresh disk for installation)"
        BOOT_ARGS="-cdrom $ISO -boot d"
    else
        echo "Boot mode: Installed system"
        BOOT_ARGS=""
    fi
elif [ -f "$DISK" ]; then
    echo "Boot mode: Installed system"
    BOOT_ARGS=""
else
    echo "ERROR: No disk image found"
    exit 1
fi

if [ "$DISPLAY_MODE" = "vnc" ]; then
    echo "VNC: Connect to localhost:5900"
fi
echo ""
echo "Resources: 4 vCPUs, 16 GB RAM, 50 GB disk"
echo "=========================================="

exec qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 16384 \
    -drive file="$DISK",format=qcow2,if=virtio \
    $BOOT_ARGS \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -device virtio-vga-gl \
    -device virtio-balloon \
    -device qemu-xhci \
    -device usb-tablet \
    $DISPLAY_ARGS \
    -name "GentooVM - Manual Verification"
