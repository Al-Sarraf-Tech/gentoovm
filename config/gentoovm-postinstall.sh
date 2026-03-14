#!/bin/bash
set -e

log() { echo "[GentooVM] $1"; }

log "=== Starting GentooVM post-install ==="

# ---- Kernel symlinks ----
log "Creating kernel symlinks..."
cd /boot
for k in kernel-*; do
    [ -f "$k" ] || continue
    ver="${k#kernel-}"
    ln -sf "$k" "vmlinuz-${ver}"
    ln -sf "$k" vmlinuz
done
for i in initramfs-*.img; do
    [ -f "$i" ] || continue
    ver="${i#initramfs-}"
    ver="${ver%.img}"
    ln -sf "$i" "initrd.img-${ver}"
    ln -sf "$i" initramfs.img
done

# ---- Bootloader ----
log "Installing bootloader..."
TARGET=""
for dev in /dev/vda /dev/sda /dev/hda /dev/nvme0n1; do
    [ -b "$dev" ] && TARGET="$dev" && break
done
if [ -z "$TARGET" ]; then
    TARGET=$(lsblk -dpno NAME 2>/dev/null | head -1)
fi
log "Target disk: $TARGET"

if [ -d /sys/firmware/efi ]; then
    log "UEFI mode detected"
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GentooVM --recheck 2>&1 || true
else
    log "BIOS/SeaBIOS mode detected"
    grub-install --target=i386-pc --recheck --force "$TARGET" 2>&1
fi

log "Generating GRUB config..."
grub-mkconfig -o /boot/grub/grub.cfg 2>&1

# ---- Sudo ----
log "Configuring sudo..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# ---- README deployment ----
log "Deploying README..."
for userdir in /home/*/; do
    [ -d "$userdir" ] || continue
    username=$(basename "$userdir")
    # Skip system-like dirs
    [ "$username" = "lost+found" ] && continue
    mkdir -p "${userdir}Desktop"
    cp /usr/share/gentoovm/README.md "${userdir}Desktop/README.md" 2>/dev/null || true
    # Fix ownership
    if id "$username" >/dev/null 2>&1; then
        chown -R "$username":"$username" "${userdir}Desktop" 2>/dev/null || true
    fi
done

# ---- Remove installer shortcut ----
log "Removing installer shortcut..."
find /home -name "install-gentoovm.desktop" -type f -delete 2>/dev/null || true
rm -f /etc/skel/Desktop/install-gentoovm.desktop 2>/dev/null || true

# ---- Remove live autologin ----
log "Removing live session config..."
rm -f /etc/lightdm/lightdm.conf.d/live.conf 2>/dev/null || true

# ---- Remove live user ----
log "Cleaning up live user..."
if getent passwd gentoo >/dev/null 2>&1; then
    # Only remove if there's another real user
    other_users=$(awk -F: '$3 >= 1000 && $3 < 65000 && $1 != "gentoo" {print $1}' /etc/passwd)
    if [ -n "$other_users" ]; then
        userdel -r gentoo 2>/dev/null || true
        log "Removed live user 'gentoo'"
    fi
fi

# ---- Fix LightDM config ----
log "Configuring LightDM..."
cat > /etc/lightdm/lightdm.conf << 'LDMCONF'
[LightDM]
logind-check-graphical=false

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=cinnamon
session-wrapper=/etc/lightdm/Xsession
LDMCONF

# ---- zram ----
log "Configuring zram..."
mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf.d/gentoovm.conf << 'ZRAMCONF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
ZRAMCONF

# ---- sysctl ----
log "Setting VM sysctl tuning..."
cat > /etc/sysctl.d/99-gentoovm.conf << 'SYSCTLCONF'
vm.swappiness=180
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.page-cluster=0
SYSCTLCONF

# ---- Services ----
log "Enabling services..."
systemctl enable earlyoom.service 2>/dev/null || true

# ---- Timezone ----
log "Setting timezone..."
ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime

# ---- Locale ----
log "Configuring locale..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen 2>/dev/null || true
echo "LANG=en_US.UTF-8" > /etc/locale.conf

log "=== Post-install complete ==="
