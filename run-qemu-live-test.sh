#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

# Stage 8: Automated QEMU Live Boot Test
# Tests that the ISO boots to a live graphical environment
BASE="${GENTOOVM_BUILD_ROOT:-/home/jalsarraf/gentoo}"
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

# Wait for boot sequence in serial log — validate stages, not just any keyword
BOOT_STAGE=0
for i in $(seq 1 60); do
    sleep 3
    [ -f "$SERIAL_LOG" ] || continue

    # Stage 1: Kernel started (any kernel message)
    if [ "$BOOT_STAGE" -lt 1 ] && grep -qi "Linux version\|Booting Linux" "$SERIAL_LOG" 2>/dev/null; then
        BOOT_STAGE=1
        echo "  Boot stage 1: kernel started" | tee -a "$LOG"
    fi

    # Stage 2: systemd reached a target
    if [ "$BOOT_STAGE" -lt 2 ] && grep -qi "systemd.*reached target\|Started.*target" "$SERIAL_LOG" 2>/dev/null; then
        BOOT_STAGE=2
        echo "  Boot stage 2: systemd targets reached" | tee -a "$LOG"
    fi

    # Stage 3: Login prompt or display manager
    if [ "$BOOT_STAGE" -lt 3 ] && grep -qiE "login:|graphical.target|lightdm" "$SERIAL_LOG" 2>/dev/null; then
        BOOT_STAGE=3
        echo "  Boot stage 3: login/display manager ready" | tee -a "$LOG"
        break
    fi
done

# Kill QEMU
kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

if [ "$BOOT_STAGE" -ge 3 ]; then
    echo "PASS: ISO booted successfully (all 3 stages)" | tee -a "$LOG"
    exit 0
elif [ "$BOOT_STAGE" -ge 1 ]; then
    echo "FAIL: ISO partially booted (reached stage $BOOT_STAGE/3)" | tee -a "$LOG"
    echo "Serial log tail:" | tee -a "$LOG"
    tail -50 "$SERIAL_LOG" 2>/dev/null | tee -a "$LOG"
    exit 1
else
    echo "FAIL: ISO did not boot (no kernel messages in serial)" | tee -a "$LOG"
    echo "Serial log contents:" | tee -a "$LOG"
    cat "$SERIAL_LOG" 2>/dev/null | tee -a "$LOG"
    exit 1
fi
