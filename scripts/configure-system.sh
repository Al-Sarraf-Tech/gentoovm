#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT=/home/jalsarraf/gentoo/build
LOG=/home/jalsarraf/gentoo/logs/configure-system.log

echo "=== Configuring system ===" | tee "$LOG"

sudo chroot "$BUILD_ROOT" /bin/bash << 'CHROOT_SCRIPT'
source /etc/profile

# ---- Locale ----
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo 'LANG="en_US.UTF-8"' > /etc/locale.conf
eselect locale set en_US.utf8

# ---- Timezone ----
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
echo "America/Chicago" > /etc/timezone

# ---- Hostname ----
echo "gentoovm" > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   gentoovm.localdomain gentoovm
HOSTS

# ---- Sudo ----
mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# ---- LightDM ----
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm.conf << 'LDM'
[LightDM]
logind-check-graphical=true

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=cinnamon
LDM

cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'LDMGTK'
[greeter]
theme-name = Adwaita
icon-theme-name = Adwaita
background = #2D2B55
LDMGTK

# ---- Systemd services ----
systemctl enable lightdm.service 2>/dev/null || true
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable qemu-guest-agent.service 2>/dev/null || true
systemctl enable spice-vdagentd.service 2>/dev/null || true
systemctl enable earlyoom.service 2>/dev/null || true
systemctl set-default graphical.target

# ---- zram ----
mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf.d/gentoovm.conf << 'ZRAM'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
ZRAM

# ---- sysctl VM tuning ----
cat > /etc/sysctl.d/99-gentoovm.conf << 'SYSCTL'
vm.swappiness=180
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.page-cluster=0
SYSCTL

# ---- README deployment ----
mkdir -p /usr/share/gentoovm
mkdir -p /etc/skel/Desktop

# ---- fstab template ----
cat > /etc/fstab << 'FSTAB'
# /etc/fstab - GentooVM
# <fs>      <mountpoint>  <type>  <opts>              <dump> <pass>
# Root filesystem (will be set by installer)
FSTAB

# ---- Kernel ----
# gentoo-kernel-bin installs to /usr/src and provides vmlinuz
# Make sure we have an initramfs
if command -v dracut &>/dev/null; then
    KVER=$(ls /lib/modules/ | sort -V | tail -1)
    if [ -n "$KVER" ] && [ ! -f "/boot/initramfs-${KVER}.img" ]; then
        dracut --force "/boot/initramfs-${KVER}.img" "$KVER" 2>/dev/null || true
    fi
fi

# ---- GRUB config ----
mkdir -p /etc/default
cat > /etc/default/grub << 'GRUB'
GRUB_DISTRIBUTOR="GentooVM"
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_TERMINAL_OUTPUT="console"
GRUB_GFXMODE="auto"
GRUB_GFXPAYLOAD_LINUX="keep"
GRUB_DISABLE_OS_PROBER=true
GRUB

echo "System configuration complete"
CHROOT_SCRIPT

echo "=== Configuration done ===" | tee -a "$LOG"
