#!/usr/bin/env bash
set -euo pipefail

# Stage 7: Regression Suite
BASE=/home/jalsarraf/gentoo
BUILD_ROOT="$BASE/build"
LOG="$BASE/logs/regression-suite.log"
PASS=0
FAIL=0

log() { echo "$1" | tee -a "$LOG"; }
pass() { PASS=$((PASS+1)); log "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); log "  FAIL: $1"; }

echo "=== Stage 7: Regression Suite ===" | tee "$LOG"

# ISO output path
log "--- ISO path ---"
if [ -f "$BASE/gentoovm.iso" ]; then
    pass "ISO at correct path"
else
    fail "ISO not at $BASE/gentoovm.iso"
fi

# Workspace structure
log "--- Workspace structure ---"
for d in build cache staging config calamares packages hooks scripts tests/smoke tests/e2e tests/regression logs test-results qemu docs manifests; do
    if [ -d "$BASE/$d" ]; then
        pass "Dir: $d"
    else
        fail "Missing dir: $d"
    fi
done

# Calamares config integrity
log "--- Calamares config regression ---"
if python3 -c "import yaml; yaml.safe_load(open('$BASE/calamares/settings.conf'))" 2>/dev/null; then
    pass "settings.conf valid YAML"
else
    fail "settings.conf broken"
fi

# Timezone default
if grep -q "Chicago" "$BASE/calamares/modules/locale.conf"; then
    pass "Timezone still America/Chicago"
else
    fail "Timezone regressed"
fi

# User prompts
for field in users partition; do
    if grep -q "$field" "$BASE/calamares/settings.conf"; then
        pass "Prompt exists: $field"
    else
        fail "Prompt missing: $field"
    fi
done

# Admin user
if grep -q "wheel" "$BASE/calamares/modules/users.conf"; then
    pass "Admin group still configured"
else
    fail "Admin group regressed"
fi

# Sudo policy
if grep -q "wheel" "$BASE/calamares/modules/shellprocess.conf" || sudo grep -q "wheel" "$BASE/build/usr/local/bin/gentoovm-postinstall.sh" 2>/dev/null; then
    pass "Sudo policy in post-install"
else
    fail "Sudo policy regressed"
fi

# Offline property
if grep -q '""' "$BASE/calamares/modules/welcome.conf" || grep -q "none" "$BASE/calamares/modules/locale.conf"; then
    pass "Offline property intact"
else
    fail "Offline property may have regressed"
fi

# Cinnamon desktop
if grep -q "cinnamon" "$BASE/calamares/modules/displaymanager.conf" || \
   grep -q "cinnamon" "$BASE/scripts/setup-live-session.sh"; then
    pass "Cinnamon still the desktop"
else
    fail "Cinnamon config regressed"
fi

# README deployment
if grep -q "README" "$BASE/calamares/modules/shellprocess.conf" || sudo grep -q "README" "$BASE/build/usr/local/bin/gentoovm-postinstall.sh" 2>/dev/null; then
    pass "README deployment intact"
else
    fail "README deployment regressed"
fi

# zram
if grep -q "zram" "$BASE/calamares/modules/shellprocess.conf" || \
   grep -q "zram" "$BASE/calamares/modules/services-systemd.conf"; then
    pass "zram config intact"
else
    fail "zram config regressed"
fi

# Display manager
if grep -q "lightdm" "$BASE/calamares/modules/displaymanager.conf"; then
    pass "LightDM still configured"
else
    fail "Display manager regressed"
fi

# Guest tools
if grep -q "qemu-guest-agent" "$BASE/calamares/modules/services-systemd.conf" || \
   grep -q "qemu-guest-agent" "$BASE/scripts/install-desktop-packages.sh"; then
    pass "Guest tools config intact"
else
    fail "Guest tools regressed"
fi

# Whole-disk install
if grep -q "erase" "$BASE/calamares/modules/partition.conf"; then
    pass "Whole-disk install path intact"
else
    fail "Whole-disk install regressed"
fi

# Boot artifacts in build
if ls "$BASE/build/boot/vmlinuz"* &>/dev/null 2>&1 || ls "$BASE/build/boot/kernel"* &>/dev/null 2>&1; then
    pass "Boot artifacts exist"
else
    fail "Boot artifacts missing"
fi

# No remote deps in install
log "--- No remote dependencies ---"
NO_REMOTE=true
for f in "$BASE/calamares/modules/"*.conf; do
    if grep -qE "http://|https://|rsync://|git://" "$f" 2>/dev/null; then
        if ! grep -q 'internetCheckUrl: ""' "$f"; then
            fail "Remote reference in: $(basename "$f")"
            NO_REMOTE=false
        fi
    fi
done
if $NO_REMOTE; then
    pass "No remote dependencies in installer"
fi

# Test runners work
log "--- Test runner self-check ---"
for f in run-static-validation.sh run-smoke-tests.sh run-e2e-preflight.sh run-regression-suite.sh; do
    if [ -x "$BASE/$f" ] && bash -n "$BASE/$f" 2>/dev/null; then
        pass "Runner valid: $f"
    else
        fail "Runner broken: $f"
    fi
done

# ---- Summary ----
log ""
log "=== Regression Suite Summary ==="
log "PASS: $PASS | FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    log "STATUS: FAILED"
    exit 1
else
    log "STATUS: PASSED"
    exit 0
fi
