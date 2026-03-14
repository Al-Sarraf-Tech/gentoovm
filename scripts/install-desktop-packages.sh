#!/usr/bin/env bash
set -euo pipefail

# Install all desktop packages into the chroot
BUILD_ROOT=/home/jalsarraf/gentoo/build
LOG=/home/jalsarraf/gentoo/logs/install-desktop.log

echo "=== Installing desktop packages ==="
echo "Log: $LOG"

# Package list - lean Cinnamon desktop
PACKAGES=(
    # Cinnamon desktop
    gnome-extra/cinnamon
    gnome-extra/cinnamon-screensaver
    gnome-extra/cinnamon-translations
    gnome-extra/nemo

    # Display manager
    x11-misc/lightdm
    x11-misc/lightdm-gtk-greeter

    # Network
    net-misc/networkmanager
    gnome-extra/nm-applet

    # Terminal
    x11-terms/xfce4-terminal

    # Text editors
    app-editors/mousepad
    app-editors/nano

    # Browser - use firefox-bin to avoid massive compilation
    www-client/firefox-bin

    # File manager already included (nemo)

    # Archive support
    app-arch/file-roller
    app-arch/p7zip
    app-arch/unzip
    app-arch/zip

    # Screenshot
    media-gfx/gnome-screenshot

    # System tools
    gnome-extra/gnome-system-monitor

    # Sudo
    app-admin/sudo

    # Boot
    sys-boot/grub
    sys-kernel/gentoo-kernel-bin
    sys-kernel/linux-firmware

    # VM tools
    app-emulation/qemu-guest-agent
    app-emulation/spice-vdagent

    # Calamares installer
    app-admin/calamares

    # Filesystem tools
    sys-fs/e2fsprogs
    sys-fs/dosfstools
    sys-block/parted

    # zram
    sys-block/zram-init

    # Misc essentials
    sys-apps/dbus
    sys-auth/elogind
    sys-apps/xdg-desktop-portal
    x11-misc/xdg-utils
    media-fonts/noto
    x11-themes/adwaita-icon-theme

    # Earlyoom
    sys-apps/earlyoom

    # Display/X11
    x11-base/xorg-server
    x11-drivers/xf86-video-qxl
    x11-apps/xrandr
)

sudo chroot "$BUILD_ROOT" /bin/bash -c "
    source /etc/profile
    export MAKEOPTS='-j10'
    emerge --ask=n --quiet --keep-going --getbinpkg --binpkg-respect-use=y \
        ${PACKAGES[*]} 2>&1
" | tee "$LOG"

echo "=== Desktop package installation complete ==="
