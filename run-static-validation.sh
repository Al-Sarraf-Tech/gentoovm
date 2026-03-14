#!/usr/bin/env bash
set -euo pipefail

# Stage 1: Static Validation
BASE=/home/jalsarraf/gentoo
LOG="$BASE/logs/static-validation.log"
PASS=0
FAIL=0
WARN=0

log() { echo "$1" | tee -a "$LOG"; }
pass() { PASS=$((PASS+1)); log "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); log "  FAIL: $1"; }
warn() { WARN=$((WARN+1)); log "  WARN: $1"; }

echo "=== Stage 1: Static Validation ===" | tee "$LOG"

# ---- Config syntax ----
log "--- Config syntax ---"

# YAML syntax (Calamares configs)
for f in "$BASE/calamares/settings.conf" "$BASE/calamares/modules/"*.conf; do
    if [ -f "$f" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
            pass "YAML valid: $(basename "$f")"
        else
            fail "YAML invalid: $(basename "$f")"
        fi
    fi
done

# Branding desc
if [ -f "$BASE/calamares/branding/gentoovm/branding.desc" ]; then
    if python3 -c "import yaml; yaml.safe_load(open('$BASE/calamares/branding/gentoovm/branding.desc'))" 2>/dev/null; then
        pass "Branding YAML valid"
    else
        fail "Branding YAML invalid"
    fi
fi

# Shell script syntax
log "--- Shell script syntax ---"
for f in "$BASE/scripts/"*.sh "$BASE/qemu/"*.sh "$BASE"/run-*.sh; do
    if [ -f "$f" ]; then
        if bash -n "$f" 2>/dev/null; then
            pass "Shell syntax: $(basename "$f")"
        else
            fail "Shell syntax: $(basename "$f")"
        fi
    fi
done

# Executable permissions
log "--- Executable permissions ---"
for f in "$BASE/scripts/"*.sh "$BASE/qemu/"*.sh "$BASE"/run-*.sh; do
    if [ -f "$f" ]; then
        if [ -x "$f" ]; then
            pass "Executable: $(basename "$f")"
        else
            fail "Not executable: $(basename "$f")"
        fi
    fi
done

# ---- Calamares config checks ----
log "--- Calamares config checks ---"

# Check timezone default
if grep -q "America" "$BASE/calamares/modules/locale.conf" && grep -q "Chicago" "$BASE/calamares/modules/locale.conf"; then
    pass "Timezone default: America/Chicago"
else
    fail "Timezone default not America/Chicago"
fi

# Check users module has wheel/admin
if grep -q "wheel" "$BASE/calamares/modules/users.conf"; then
    pass "Admin group (wheel) configured"
else
    fail "Admin group not configured"
fi

# Check sudo config in shellprocess
if grep -q "sudo" "$BASE/calamares/modules/shellprocess.conf" || sudo grep -q "sudo" "$BASE/build/usr/local/bin/gentoovm-postinstall.sh" 2>/dev/null; then
    pass "Sudo configuration in post-install"
else
    fail "Sudo not configured in post-install"
fi

# Check users module exists
if grep -q "users" "$BASE/calamares/settings.conf"; then
    pass "Users module in installer sequence"
else
    fail "Users module missing from sequence"
fi

# Check partition module
if grep -q "partition" "$BASE/calamares/settings.conf"; then
    pass "Partition module in installer sequence"
else
    fail "Partition module missing"
fi

# Check bootloader (either as module or handled in shellprocess)
if grep -q "bootloader" "$BASE/calamares/settings.conf" || grep -q "grub-install\|bootloader\|gentoovm-postinstall" "$BASE/calamares/modules/shellprocess.conf"; then
    pass "Bootloader configured"
else
    fail "Bootloader not configured"
fi

# Check offline - no geoip/network requirements
if grep -q '"none"' "$BASE/calamares/modules/locale.conf" || grep -q "'none'" "$BASE/calamares/modules/locale.conf"; then
    pass "GeoIP disabled (offline)"
else
    warn "GeoIP may not be disabled"
fi

# Check welcome doesn't require internet
if grep -q "internetCheckUrl" "$BASE/calamares/modules/welcome.conf"; then
    if grep -q 'internetCheckUrl: ""' "$BASE/calamares/modules/welcome.conf"; then
        pass "Internet check disabled in welcome"
    else
        warn "Internet check may be enabled"
    fi
fi

# Check README deployment hooks
if grep -q "README" "$BASE/calamares/modules/shellprocess.conf" || sudo grep -q "README" "$BASE/build/usr/local/bin/gentoovm-postinstall.sh" 2>/dev/null; then
    pass "README deployment in post-install hooks"
else
    fail "README deployment missing"
fi

# Check display manager config
if [ -f "$BASE/calamares/modules/displaymanager.conf" ]; then
    if grep -q "lightdm" "$BASE/calamares/modules/displaymanager.conf"; then
        pass "LightDM configured as display manager"
    else
        fail "LightDM not configured"
    fi
else
    fail "displaymanager.conf missing"
fi

# ---- Installer defaults ----
log "--- Installer defaults ---"
if grep -q "erase" "$BASE/calamares/modules/partition.conf"; then
    pass "Whole-disk install path exists"
else
    fail "No whole-disk install path"
fi

if grep -q "gpt" "$BASE/calamares/modules/partition.conf"; then
    pass "GPT partition table configured"
else
    fail "GPT not configured"
fi

if grep -q "ext4" "$BASE/calamares/modules/partition.conf"; then
    pass "ext4 filesystem configured"
else
    fail "ext4 not configured"
fi

# ---- README content ----
log "--- README validation ---"
if [ -f "$BASE/config/README-desktop.md" ]; then
    pass "README source exists"
    for keyword in "sudo" "zram" "Cinnamon" "Gentoo" "emerge" "terminal" "package" "troubleshooting"; do
        if grep -qi "$keyword" "$BASE/config/README-desktop.md"; then
            pass "README contains: $keyword"
        else
            fail "README missing: $keyword"
        fi
    done
else
    fail "README source missing"
fi

# ---- Summary ----
log ""
log "=== Static Validation Summary ==="
log "PASS: $PASS | FAIL: $FAIL | WARN: $WARN"
if [ "$FAIL" -gt 0 ]; then
    log "STATUS: FAILED"
    exit 1
else
    log "STATUS: PASSED"
    exit 0
fi
