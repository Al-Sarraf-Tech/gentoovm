#!/usr/bin/env bash
set -euo pipefail

# Stage 2: Smoke Tests
BASE=/home/jalsarraf/gentoo
LOG="$BASE/logs/smoke-tests.log"
PASS=0
FAIL=0

log() { echo "$1" | tee -a "$LOG"; }
pass() { PASS=$((PASS+1)); log "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); log "  FAIL: $1"; }

echo "=== Stage 2: Smoke Tests ===" | tee "$LOG"

# Required directories
log "--- Required directories ---"
for d in build cache staging config calamares packages hooks scripts tests logs test-results qemu docs manifests; do
    if [ -d "$BASE/$d" ]; then
        pass "Directory: $d"
    else
        fail "Directory missing: $d"
    fi
done

# Required config files
log "--- Required config files ---"
for f in calamares/settings.conf calamares/modules/users.conf calamares/modules/partition.conf \
         calamares/modules/locale.conf calamares/modules/bootloader.conf \
         calamares/modules/shellprocess.conf calamares/modules/displaymanager.conf \
         calamares/branding/gentoovm/branding.desc config/README-desktop.md; do
    if [ -f "$BASE/$f" ]; then
        pass "Config: $f"
    else
        fail "Config missing: $f"
    fi
done

# Build root checks
log "--- Build root ---"
if [ -f "$BASE/build/etc/gentoo-release" ]; then
    pass "Gentoo release file exists"
else
    fail "No gentoo-release"
fi

# Boot artifacts
log "--- Boot artifacts ---"
if ls "$BASE/build/boot/vmlinuz"* &>/dev/null || ls "$BASE/build/boot/kernel"* &>/dev/null; then
    pass "Kernel found in build root"
else
    fail "No kernel in build root"
fi

# Scripts exist and are executable
log "--- Scripts ---"
for f in scripts/install-desktop-packages.sh scripts/configure-system.sh scripts/build-iso.sh \
         scripts/setup-live-session.sh qemu/launch-live.sh qemu/launch-installed.sh; do
    if [ -x "$BASE/$f" ]; then
        pass "Script executable: $f"
    else
        fail "Script not executable: $f"
    fi
done

# ISO check
log "--- ISO ---"
if [ -f "$BASE/gentoovm.iso" ]; then
    SIZE=$(stat -c%s "$BASE/gentoovm.iso" 2>/dev/null || echo 0)
    if [ "$SIZE" -gt 1048576 ]; then
        pass "ISO exists and non-trivial ($((SIZE/1048576)) MB)"
    else
        fail "ISO exists but too small ($SIZE bytes)"
    fi
else
    fail "ISO not yet created"
fi

# Checksums
log "--- Checksums ---"
if [ -f "$BASE/gentoovm.iso.sha256" ]; then
    pass "SHA256 checksum file exists"
else
    fail "SHA256 checksum missing"
fi

# ---- Summary ----
log ""
log "=== Smoke Test Summary ==="
log "PASS: $PASS | FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    log "STATUS: FAILED"
    exit 1
else
    log "STATUS: PASSED"
    exit 0
fi
