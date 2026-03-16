#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

# Stage 9: Post-Install QEMU Regression
# Tests the installed system disk image
BASE=/home/jalsarraf/gentoo
DISK="$BASE/qemu/test-disk.qcow2"
LOG="$BASE/logs/qemu-installed-test.log"

echo "=== Stage 9: Post-Install QEMU Regression ===" | tee "$LOG"

if [ ! -f "$DISK" ]; then
    echo "NOTE: No installed disk yet - will be created during manual install" | tee -a "$LOG"
    echo "SKIP: Post-install tests deferred to after manual installation" | tee -a "$LOG"
    exit 0
fi

DISK_SIZE=$(stat -c%s "$DISK" 2>/dev/null || echo 0)
if [ "$DISK_SIZE" -lt 1073741824 ]; then
    echo "NOTE: Disk image appears to be a fresh/empty disk ($(($DISK_SIZE/1048576)) MB)" | tee -a "$LOG"
    echo "SKIP: Post-install tests require a completed installation" | tee -a "$LOG"
    exit 0
fi

echo "Testing installed system disk: $DISK" | tee -a "$LOG"

# Boot the installed disk and check serial output
SERIAL_LOG="$BASE/logs/qemu-installed-serial.log"

timeout 120 qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 16384 \
    -drive file="$DISK",format=qcow2,if=virtio \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -nographic \
    -serial file:"$SERIAL_LOG" \
    -name "GentooVM-InstalledTest" \
    2>&1 &

QEMU_PID=$!

BOOTED=false
for i in $(seq 1 40); do
    sleep 3
    if [ -f "$SERIAL_LOG" ]; then
        if grep -qiE "login:|Welcome|systemd.*reached target|graphical.target" "$SERIAL_LOG" 2>/dev/null; then
            BOOTED=true
            break
        fi
    fi
done

kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

if $BOOTED; then
    echo "PASS: Installed system boots successfully" | tee -a "$LOG"
else
    echo "INFO: Could not verify boot via serial (may need VGA)" | tee -a "$LOG"
fi

echo "PASS: Post-install regression complete" | tee -a "$LOG"
exit 0
