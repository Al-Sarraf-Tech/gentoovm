#!/usr/bin/env bash
set -euo pipefail

# Configure the live session environment
BUILD_ROOT=/home/jalsarraf/gentoo/build

echo "=== Setting up live session ==="

sudo chroot "$BUILD_ROOT" /bin/bash << 'CHROOT'
source /etc/profile

# ---- Live user for the live session ----
if ! id gentoo &>/dev/null; then
    useradd -m -G wheel,audio,video,users -s /bin/bash gentoo
    echo "gentoo:gentoo" | chpasswd
fi

# ---- Auto-login for live session ----
mkdir -p /etc/lightdm/lightdm.conf.d
cat > /etc/lightdm/lightdm.conf.d/live.conf << 'LIVE'
[Seat:*]
autologin-user=gentoo
autologin-session=cinnamon
LIVE

# ---- Desktop shortcut for Calamares installer ----
mkdir -p /home/gentoo/Desktop
cat > /home/gentoo/Desktop/install-gentoovm.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Install GentooVM
Comment=Install GentooVM to disk
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
StartupNotify=true
DESKTOP
chmod +x /home/gentoo/Desktop/install-gentoovm.desktop
chown -R gentoo:gentoo /home/gentoo/Desktop

# ---- Polkit rule to allow installer to run ----
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-nopasswd-calamares.rules << 'POLKIT'
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POLKIT

# ---- Place Calamares config ----
mkdir -p /etc/calamares/branding/gentoovm
mkdir -p /etc/calamares/modules

echo "Live session setup complete"
CHROOT

# Copy Calamares config files
CALAM_SRC=/home/jalsarraf/gentoo/calamares
sudo cp "$CALAM_SRC/settings.conf" "$BUILD_ROOT/etc/calamares/settings.conf"
sudo cp -r "$CALAM_SRC/branding/gentoovm/"* "$BUILD_ROOT/etc/calamares/branding/gentoovm/"
for f in "$CALAM_SRC/modules/"*.conf; do
    sudo cp "$f" "$BUILD_ROOT/etc/calamares/modules/"
done

# Copy README for deployment
sudo mkdir -p "$BUILD_ROOT/usr/share/gentoovm"
sudo cp /home/jalsarraf/gentoo/config/README-desktop.md "$BUILD_ROOT/usr/share/gentoovm/README.md"

# Also put in skel
sudo mkdir -p "$BUILD_ROOT/etc/skel/Desktop"
sudo cp /home/jalsarraf/gentoo/config/README-desktop.md "$BUILD_ROOT/etc/skel/Desktop/README.md"

echo "=== Live session setup complete ==="
