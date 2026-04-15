#!/usr/bin/env bash
# Unit tests: System configuration management
# Deep validation of make.conf, package.use, grub-defaults, and kernel configs
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="config-management"

CONFIG="$REPO_DIR/config"

echo "=== Config Management Tests ==="

# --- grub-defaults validation ---
echo "--- GRUB defaults ---"
GRUB="$CONFIG/grub-defaults"
assert_file_exists "$GRUB"
assert_file_contains "$GRUB" 'GRUB_DISTRIBUTOR="GentooVM"' "distributor: GentooVM"
assert_file_contains "$GRUB" 'GRUB_DEFAULT=0' "default entry: 0"
assert_file_contains "$GRUB" 'GRUB_TIMEOUT=30' "timeout: 30s"
assert_file_contains "$GRUB" 'GRUB_TIMEOUT_STYLE=menu' "timeout style: menu (visible)"
assert_file_contains "$GRUB" 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' "cmdline: quiet splash"
assert_file_contains "$GRUB" 'GRUB_GFXMODE="auto"' "gfx mode: auto"
assert_file_contains "$GRUB" 'GRUB_DISABLE_OS_PROBER=true' "os-prober: disabled (VM)"
assert_file_contains "$GRUB" 'GRUB_DISABLE_SUBMENU=true' "submenus: disabled (flat list)"

# --- package.use format validation ---
echo "--- package.use format ---"
PKG_USE="$CONFIG/package.use"
assert_file_exists "$PKG_USE"

# Every non-comment, non-blank line should start with a category/package or keyword
BAD_LINES=0
while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    # Valid: category/package flags  OR  category/package KEY: value  OR  category/package KEY value
    if ! [[ "$line" =~ ^[a-z] ]]; then
        fail "package.use bad line: $line"
        BAD_LINES=$((BAD_LINES+1))
    fi
done < "$PKG_USE"
[ "$BAD_LINES" -eq 0 ] && pass "package.use: all lines valid format"

# Key packages should have USE flags set
assert_file_contains "$PKG_USE" "sys-boot/grub" "grub USE flags configured"
assert_file_contains "$PKG_USE" "www-client/firefox" "firefox USE flags configured"
assert_file_contains "$PKG_USE" "app-admin/calamares" "calamares USE flags configured"
assert_file_contains "$PKG_USE" "sys-kernel/installkernel.*dracut" "installkernel uses dracut"
assert_file_contains "$PKG_USE" "media-libs/mesa.*virgl" "mesa has virgl driver"

# --- Kernel manager scripts exist and are valid ---
echo "--- Kernel manager ---"
assert_file_exists "$CONFIG/gentoovm-kernel-manager"
assert_file_exists "$CONFIG/gentoovm-kernel-manager-gui"

# CLI kernel manager should be a shell script
if head -1 "$CONFIG/gentoovm-kernel-manager" | grep -qE '^#!/'; then
    pass "kernel-manager: has shebang"
else
    fail "kernel-manager: missing shebang"
fi

# GUI kernel manager should be Python with valid syntax
if head -1 "$CONFIG/gentoovm-kernel-manager-gui" | grep -qE 'python'; then
    pass "kernel-manager-gui: Python script"
else
    fail "kernel-manager-gui: not Python"
fi
if python3 -m py_compile "$CONFIG/gentoovm-kernel-manager-gui" 2>/dev/null; then
    pass "kernel-manager-gui: Python syntax valid"
else
    fail "kernel-manager-gui: Python syntax error"
fi

# CLI kernel manager shell syntax
assert_shell_syntax "$CONFIG/gentoovm-kernel-manager"

# --- Desktop README has essential content ---
echo "--- Desktop README content ---"
DESKTOP_README="$CONFIG/README-desktop.md"
assert_file_exists "$DESKTOP_README"
for section in "Package Management" "System Administration" "Kernel Management" "Troubleshooting"; do
    assert_file_contains "$DESKTOP_README" "$section" "desktop README section: $section"
done

# --- postinstall.sh config consistency ---
echo "--- Postinstall consistency ---"
POSTINSTALL="$CONFIG/gentoovm-postinstall.sh"
# Timezone in postinstall must match locale.conf default
assert_file_contains "$POSTINSTALL" "America/Chicago" "postinstall timezone matches locale.conf"
# Locale in postinstall must match what configure-system.sh sets
assert_file_contains "$POSTINSTALL" "en_US.UTF-8" "postinstall locale matches system config"
# Cinnamon session must match displaymanager.conf
assert_file_contains "$POSTINSTALL" "user-session=cinnamon" "postinstall cinnamon matches displaymanager"
# LightDM greeter must match configure-system.sh
assert_file_contains "$POSTINSTALL" "lightdm-gtk-greeter" "postinstall greeter matches system config"

# --- Cross-file consistency: make.conf ↔ package.use ---
echo "--- Cross-file consistency ---"
MAKECONF="$CONFIG/make.conf"
# GRUB_PLATFORMS in make.conf should match package.use grub entry
assert_file_contains "$MAKECONF" "efi-64" "make.conf: efi-64 platform"
assert_file_contains "$PKG_USE" "efi-64" "package.use: efi-64 for grub"
assert_file_contains "$MAKECONF" "GRUB_PLATFORMS.*pc" "make.conf: BIOS platform"
assert_file_contains "$PKG_USE" "grub_platforms_pc" "package.use: BIOS for grub"

test_summary
