#!/usr/bin/env bash
# Unit tests: Post-install script safety and completeness
# Validates the script that runs during Calamares installation
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="postinstall-safety"

SCRIPT="$REPO_DIR/config/gentoovm-postinstall.sh"

echo "=== Post-Install Safety Tests ==="

# --- Script fundamentals ---
echo "--- Script fundamentals ---"
assert_file_exists "$SCRIPT"
assert_shell_syntax "$SCRIPT"
assert_script_strict "$SCRIPT"

# --- Bootloader support ---
echo "--- Bootloader ---"
assert_file_contains "$SCRIPT" "/sys/firmware/efi" "UEFI detection"
assert_file_contains "$SCRIPT" "x86_64-efi" "UEFI grub target"
assert_file_contains "$SCRIPT" "i386-pc" "BIOS grub target"
assert_file_contains "$SCRIPT" "grub-mkconfig" "GRUB config generation"

# --- Sudo configuration ---
echo "--- Sudo ---"
assert_file_contains "$SCRIPT" '%wheel ALL=\(ALL:ALL\) ALL' "wheel sudo policy"
assert_file_contains "$SCRIPT" "chmod 440.*sudoers" "sudoers permissions locked"

# --- Live session cleanup ---
echo "--- Live session cleanup ---"
assert_file_contains "$SCRIPT" "install-gentoovm.desktop.*-delete" "installer shortcut removed"
assert_file_contains "$SCRIPT" "live.conf" "live autologin removed"
assert_file_contains "$SCRIPT" "userdel.*gentoo" "live user cleanup"

# --- Defensive live user removal ---
echo "--- Defensive checks ---"
assert_file_contains "$SCRIPT" 'getent passwd gentoo' "checks live user exists before removal"
assert_file_contains "$SCRIPT" "other_users" "verifies other users exist before removing live user"

# --- Desktop environment ---
echo "--- Desktop config ---"
assert_file_contains "$SCRIPT" "user-session=cinnamon" "Cinnamon session configured"
assert_file_contains "$SCRIPT" "greeter-session=lightdm-gtk-greeter" "LightDM greeter set"

# --- VM tuning ---
echo "--- VM tuning ---"
assert_file_contains "$SCRIPT" "zram-size" "zram configured"
assert_file_contains "$SCRIPT" "vm.swappiness" "swappiness tuned"
assert_file_contains "$SCRIPT" "vm.vfs_cache_pressure" "cache pressure tuned"
assert_file_contains "$SCRIPT" "earlyoom" "earlyoom enabled"

# --- Locale/timezone ---
echo "--- Locale and timezone ---"
assert_file_contains "$SCRIPT" "en_US.UTF-8" "UTF-8 locale"
assert_file_contains "$SCRIPT" "locale-gen" "locale generated"
assert_file_contains "$SCRIPT" "America/Chicago" "timezone set"

# --- README deployment ---
echo "--- README ---"
assert_file_contains "$SCRIPT" "README.md" "README deployed to desktop"
assert_file_contains "$SCRIPT" "chown.*Desktop" "desktop ownership fixed"

# --- No hardcoded secrets ---
echo "--- Security ---"
assert_file_not_contains "$SCRIPT" 'password\s*=\s*["\x27]' "no hardcoded passwords"
assert_file_not_contains "$SCRIPT" 'api_key|api_token|secret_key' "no API keys"
assert_file_not_contains "$SCRIPT" 'BEGIN.*PRIVATE KEY' "no private keys"

test_summary
