#!/usr/bin/env bash
# Unit tests: Calamares installer configuration
# Deep schema validation — checks values, types, and invariants, not just existence
# shellcheck disable=SC2034
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_DIR/tests/lib/assertions.sh"
TEST_NAME="calamares-config"

CALAM="$REPO_DIR/calamares"

echo "=== Calamares Config Tests ==="

# --- YAML validity ---
echo "--- YAML syntax ---"
for f in "$CALAM/settings.conf" "$CALAM/modules/"*.conf "$CALAM/branding/gentoovm/branding.desc"; do
    [ -f "$f" ] && assert_yaml_valid "$f"
done

# --- settings.conf module sequence ---
echo "--- Module sequence ---"
for mod in welcome locale keyboard partition users summary finished; do
    assert_file_contains "$CALAM/settings.conf" "^\s*- $mod" "show/exec module: $mod"
done
for mod in mount unpackfs machineid fstab shellprocess umount; do
    assert_file_contains "$CALAM/settings.conf" "^\s*- $mod" "exec module: $mod"
done

# --- Partition config (deep) ---
echo "--- Partition config ---"
assert_yaml_value "$CALAM/modules/partition.conf" "defaultPartitionTableType" "gpt" "partition table: GPT"
assert_yaml_value "$CALAM/modules/partition.conf" "defaultFileSystemType" "ext4" "filesystem: ext4"
assert_yaml_value "$CALAM/modules/partition.conf" "initialPartitioningChoice" "erase" "partitioning: erase"
assert_yaml_value "$CALAM/modules/partition.conf" "initialSwapChoice" "none" "swap: none (zram instead)"
assert_file_contains "$CALAM/modules/partition.conf" "efiSystemPartition.*boot/efi" "EFI partition at /boot/efi"
assert_file_contains "$CALAM/modules/partition.conf" "efiSystemPartitionSize.*512M" "EFI partition 512M"

# --- Users config (deep) ---
echo "--- Users config ---"
assert_yaml_value "$CALAM/modules/users.conf" "sudoersGroup" "wheel" "sudoers group: wheel"
assert_yaml_value "$CALAM/modules/users.conf" "userShell" "/bin/bash" "user shell: bash"
assert_yaml_value "$CALAM/modules/users.conf" "doAutologin" "False" "autologin: disabled"
assert_yaml_value "$CALAM/modules/users.conf" "setRootPassword" "True" "root password: set"
assert_yaml_value "$CALAM/modules/users.conf" "setHostname" "EtcFile" "hostname: via /etc/hostname"
assert_yaml_value "$CALAM/modules/users.conf" "writeHostsFile" "True" "writes /etc/hosts"

# --- Locale config (deep) ---
echo "--- Locale config ---"
assert_yaml_value "$CALAM/modules/locale.conf" "region" "America" "default region: America"
assert_yaml_value "$CALAM/modules/locale.conf" "zone" "Chicago" "default zone: Chicago"
assert_yaml_value "$CALAM/modules/locale.conf" "geoip.style" "none" "GeoIP: disabled"

# --- Bootloader config (deep) ---
echo "--- Bootloader config ---"
assert_yaml_value "$CALAM/modules/bootloader.conf" "efiBootLoader" "grub" "EFI bootloader: grub"
assert_yaml_value "$CALAM/modules/bootloader.conf" "efiBootloaderId" "GentooVM" "EFI ID: GentooVM"
assert_yaml_value "$CALAM/modules/bootloader.conf" "installEFIFallback" "True" "EFI fallback: enabled"
assert_file_contains "$CALAM/modules/bootloader.conf" "grubInstall.*grub-install" "grub-install command"
assert_file_contains "$CALAM/modules/bootloader.conf" "grubMkconfig.*grub-mkconfig" "grub-mkconfig command"

# --- Welcome requirements ---
echo "--- Welcome config ---"
assert_yaml_value "$CALAM/modules/welcome.conf" "requirements.requiredStorage" "15.0" "min storage: 15 GB"
assert_yaml_value "$CALAM/modules/welcome.conf" "requirements.requiredRam" "2.0" "min RAM: 2 GB"
assert_yaml_value "$CALAM/modules/welcome.conf" "requirements.internetCheckUrl" "" "internet check: disabled"
assert_yaml_value "$CALAM/modules/welcome.conf" "showSupportUrl" "False" "hide support URL"
assert_yaml_value "$CALAM/modules/welcome.conf" "showKnownIssuesUrl" "False" "hide known issues URL"

# --- Display manager ---
echo "--- Display manager ---"
assert_file_contains "$CALAM/modules/displaymanager.conf" "lightdm" "LightDM configured"

# --- Services (systemd) ---
echo "--- Services config ---"
assert_file_contains "$CALAM/modules/services-systemd.conf" "NetworkManager" "NetworkManager service"
assert_file_contains "$CALAM/modules/services-systemd.conf" "lightdm" "lightdm service"
assert_file_contains "$CALAM/modules/services-systemd.conf" "qemu-guest-agent" "qemu-guest-agent service"
assert_file_contains "$CALAM/modules/services-systemd.conf" "graphical" "graphical target"

# --- Shell process (post-install hook) ---
echo "--- Shell process config ---"
assert_file_contains "$CALAM/modules/shellprocess.conf" "gentoovm-postinstall" "postinstall script referenced"
assert_yaml_value "$CALAM/modules/shellprocess.conf" "dontChroot" "False" "runs inside chroot"
assert_yaml_value "$CALAM/modules/shellprocess.conf" "timeout" "300" "timeout: 300s"

# --- Branding ---
echo "--- Branding config ---"
BRANDING="$CALAM/branding/gentoovm/branding.desc"
assert_yaml_value "$BRANDING" "componentName" "gentoovm" "component: gentoovm"
assert_yaml_value "$BRANDING" "strings.productName" "GentooVM" "product name: GentooVM"
assert_yaml_value "$BRANDING" "strings.bootloaderEntryName" "GentooVM" "bootloader entry: GentooVM"
assert_file_contains "$BRANDING" "productLogo.*gentoo-logo.png" "logo: gentoo-logo.png"
assert_file_contains "$BRANDING" "slideshow.*show.qml" "slideshow: show.qml"
assert_file_contains "$BRANDING" "sidebarBackground.*#2D2B55" "sidebar color: #2D2B55"
# Verify branding assets exist and are valid
assert_file_exists "$CALAM/branding/gentoovm/gentoo-logo.png"
assert_file_exists "$CALAM/branding/gentoovm/show.qml"

# QML slideshow structural validation (no QML linter, check structure)
QML="$CALAM/branding/gentoovm/show.qml"
assert_file_contains "$QML" "import QtQuick" "QML imports QtQuick"
assert_file_contains "$QML" "import calamares.slideshow" "QML imports calamares slideshow"
assert_file_contains "$QML" "Presentation" "QML has Presentation root"
assert_file_contains "$QML" "Slide" "QML has at least one Slide"
# Verify branding color consistency between QML and branding.desc
assert_file_contains "$QML" "#2D2B55" "QML sidebar color matches branding"

# Logo file should be non-trivial (not a zero-byte placeholder)
LOGO_SIZE=$(stat -c%s "$CALAM/branding/gentoovm/gentoo-logo.png" 2>/dev/null || echo 0)
if [ "$LOGO_SIZE" -gt 100 ]; then
    pass "logo is non-trivial ($LOGO_SIZE bytes)"
else
    fail "logo too small ($LOGO_SIZE bytes — placeholder?)"
fi

# --- No remote URLs in installer modules ---
echo "--- No remote dependencies ---"
REMOTE_FOUND=false
for f in "$CALAM/modules/"*.conf; do
    if grep -qE 'https?://|rsync://|git://' "$f" 2>/dev/null; then
        if ! grep -q 'internetCheckUrl: ""' "$f"; then
            fail "remote URL in $(basename "$f")"
            REMOTE_FOUND=true
        fi
    fi
done
$REMOTE_FOUND || pass "no remote dependencies in modules"

# --- Settings.conf flags ---
echo "--- Installer flags ---"
assert_file_contains "$CALAM/settings.conf" "prompt-install: true" "install confirmation: enabled"
assert_file_contains "$CALAM/settings.conf" "dont-chroot: false" "chroot: enabled"
assert_file_contains "$CALAM/settings.conf" "disable-cancel-during-exec: true" "cancel during exec: disabled"

test_summary
