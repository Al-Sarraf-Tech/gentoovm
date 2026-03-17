#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

# Stage 8: Automated QEMU Live Boot Test
# Tests that the ISO boots to a live graphical environment
BASE=/home/jalsarraf/gentoo
ISO="$BASE/gentoovm.iso"
DISK="$BASE/qemu/test-disk.qcow2"
LOG="$BASE/logs/qemu-live-test.log"
SERIAL_LOG="$BASE/logs/qemu-live-serial.log"

echo "=== Stage 8: QEMU Live Boot Test ===" | tee "$LOG"

if [ ! -f "$ISO" ]; then
    echo "FAIL: ISO not found" | tee -a "$LOG"
    exit 1
fi

# Create fresh test disk
qemu-img create -f qcow2 "$DISK" 50G 2>&1 | tee -a "$LOG"

# Boot the ISO and check serial output for boot success
echo "Booting ISO in QEMU (headless, serial monitoring)..." | tee -a "$LOG"

timeout 180 qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 16384 \
    -drive file="$DISK",format=qcow2,if=virtio \
    -cdrom "$ISO" \
    -boot d \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -device virtio-vga \
    -nographic \
    -serial file:"$SERIAL_LOG" \
    -name "GentooVM-LiveTest" \
    2>&1 | tee -a "$LOG" &

QEMU_PID=$!

# Wait for boot indicators in serial log
BOOTED=false
for i in $(seq 1 60); do
    sleep 3
    if [ -f "$SERIAL_LOG" ]; then
        if grep -qiE "login:|Welcome|systemd.*reached target|graphical.target" "$SERIAL_LOG" 2>/dev/null; then
            BOOTED=true
            break
        fi
    fi
done

# Kill QEMU
kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

if $BOOTED; then
    echo "PASS: ISO booted successfully" | tee -a "$LOG"
    exit 0
else
    echo "FAIL: ISO did not reach expected boot state within timeout" | tee -a "$LOG"
    echo "Serial log contents:" | tee -a "$LOG"
    cat "$SERIAL_LOG" 2>/dev/null | tail -50 | tee -a "$LOG"
    exit 1
fi
