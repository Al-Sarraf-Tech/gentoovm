#!/usr/bin/env bash
set -euo pipefail

# Stage 6: Pre-QEMU End-to-End Preflight
BASE=/home/jalsarraf/gentoo
BUILD_ROOT="$BASE/build"
LOG="$BASE/logs/e2e-preflight.log"
PASS=0
FAIL=0

log() { echo "$1" | tee -a "$LOG"; }
pass() { PASS=$((PASS+1)); log "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); log "  FAIL: $1"; }

echo "=== Stage 6: Pre-QEMU E2E Preflight ===" | tee "$LOG"

# ---- Installed filesystem skeleton ----
log "--- Filesystem skeleton ---"
for d in etc/calamares etc/lightdm etc/sudoers.d etc/skel/Desktop usr/share/gentoovm boot; do
    if [ -d "$BUILD_ROOT/$d" ]; then
        pass "Dir exists: /$d"
    else
        fail "Dir missing: /$d"
    fi
done

# ---- Calamares config installed ----
log "--- Calamares installed config ---"
if [ -f "$BUILD_ROOT/etc/calamares/settings.conf" ]; then
    pass "Calamares settings.conf installed"
else
    fail "Calamares settings.conf not installed"
fi

# ---- README deployment readiness ----
log "--- README deployment ---"
if [ -f "$BUILD_ROOT/usr/share/gentoovm/README.md" ]; then
    pass "README in /usr/share/gentoovm"
else
    fail "README not in /usr/share/gentoovm"
fi
if [ -f "$BUILD_ROOT/etc/skel/Desktop/README.md" ]; then
    pass "README in /etc/skel/Desktop"
else
    fail "README not in skel"
fi

# ---- Display manager ----
log "--- Display manager ---"
if [ -f "$BUILD_ROOT/etc/lightdm/lightdm.conf" ]; then
    pass "LightDM config exists"
else
    fail "LightDM config missing"
fi

# Cinnamon session
if ls "$BUILD_ROOT/usr/share/xsessions/cinnamon"* &>/dev/null; then
    pass "Cinnamon session file exists"
else
    fail "Cinnamon session file missing"
fi

# ---- systemd services ----
log "--- Service enablement ---"
for svc in lightdm NetworkManager; do
    if [ -L "$BUILD_ROOT/etc/systemd/system/display-manager.service" ] || \
       sudo chroot "$BUILD_ROOT" /bin/bash -c "systemctl is-enabled $svc 2>/dev/null" | grep -q "enabled"; then
        pass "Service enabled: $svc"
    else
        fail "Service not enabled: $svc"
    fi
done

# ---- Sudo policy ----
log "--- Sudo policy ---"
if sudo test -f "$BUILD_ROOT/etc/sudoers.d/wheel"; then
    if sudo grep -q "%wheel" "$BUILD_ROOT/etc/sudoers.d/wheel"; then
        pass "Sudo wheel policy correct"
    else
        fail "Sudo wheel policy malformed"
    fi
else
    fail "Sudo wheel policy missing"
fi

# ---- zram config ----
log "--- zram ---"
if [ -f "$BUILD_ROOT/etc/systemd/zram-generator.conf.d/gentoovm.conf" ]; then
    pass "zram config exists"
else
    fail "zram config missing"
fi

# ---- sysctl tuning ----
if [ -f "$BUILD_ROOT/etc/sysctl.d/99-gentoovm.conf" ]; then
    if grep -q "swappiness" "$BUILD_ROOT/etc/sysctl.d/99-gentoovm.conf"; then
        pass "sysctl tuning exists"
    else
        fail "sysctl tuning incomplete"
    fi
else
    fail "sysctl tuning missing"
fi

# ---- Bootloader ----
log "--- Bootloader ---"
if sudo chroot "$BUILD_ROOT" /bin/bash -c "command -v grub-install" &>/dev/null || \
   sudo chroot "$BUILD_ROOT" /bin/bash -c "command -v grub2-install" &>/dev/null; then
    pass "GRUB install binary present"
else
    fail "GRUB install binary missing"
fi

# ---- Kernel ----
log "--- Kernel ---"
KVER=$(ls "$BUILD_ROOT/lib/modules/" 2>/dev/null | sort -V | tail -1)
if [ -n "$KVER" ]; then
    pass "Kernel modules: $KVER"
else
    fail "No kernel modules found"
fi

# ---- Key packages ----
log "--- Key packages installed ---"
for pkg in cinnamon lightdm sudo networkmanager calamares; do
    if sudo chroot "$BUILD_ROOT" /bin/bash -c "qlist -I | grep -qi $pkg" 2>/dev/null || \
       ls "$BUILD_ROOT/var/db/pkg/"*"$pkg"* &>/dev/null 2>&1; then
        pass "Package installed: $pkg"
    else
        fail "Package not installed: $pkg"
    fi
done

# ---- Summary ----
log ""
log "=== E2E Preflight Summary ==="
log "PASS: $PASS | FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    log "STATUS: FAILED"
    exit 1
else
    log "STATUS: PASSED"
    exit 0
fi
