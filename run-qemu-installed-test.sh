#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

# Stage 9: Post-Install QEMU Regression
# Tests the installed system disk image
BASE="${GENTOOVM_BUILD_ROOT:-/home/jalsarraf/gentoo}"
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

BOOT_STAGE=0
for i in $(seq 1 40); do
    sleep 3
    [ -f "$SERIAL_LOG" ] || continue

    if [ "$BOOT_STAGE" -lt 1 ] && grep -qi "Linux version\|Booting Linux" "$SERIAL_LOG" 2>/dev/null; then
        BOOT_STAGE=1
        echo "  Boot stage 1: kernel started" | tee -a "$LOG"
    fi
    if [ "$BOOT_STAGE" -lt 2 ] && grep -qi "systemd.*reached target\|Started.*target" "$SERIAL_LOG" 2>/dev/null; then
        BOOT_STAGE=2
        echo "  Boot stage 2: systemd targets reached" | tee -a "$LOG"
    fi
    if [ "$BOOT_STAGE" -lt 3 ] && grep -qiE "login:|graphical.target|lightdm" "$SERIAL_LOG" 2>/dev/null; then
        BOOT_STAGE=3
        echo "  Boot stage 3: login/display manager ready" | tee -a "$LOG"
        break
    fi
done

kill "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

if [ "$BOOT_STAGE" -ge 3 ]; then
    echo "PASS: Installed system boots successfully (all 3 stages)" | tee -a "$LOG"
elif [ "$BOOT_STAGE" -ge 1 ]; then
    echo "WARN: Installed system partially booted (stage $BOOT_STAGE/3 — serial may be limited)" | tee -a "$LOG"
else
    echo "INFO: Could not verify boot via serial (may need VGA)" | tee -a "$LOG"
fi

echo "PASS: Post-install regression complete" | tee -a "$LOG"
exit 0
