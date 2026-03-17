#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT=/home/jalsarraf/gentoo/build
STAGING=/home/jalsarraf/gentoo/staging
ISO_OUT=/home/jalsarraf/gentoo/gentoovm.iso
LOG=/home/jalsarraf/gentoo/logs/build-iso.log

echo "=== Building ISO ===" | tee "$LOG"

# Clean staging
sudo rm -rf "$STAGING"
mkdir -p "$STAGING"/{boot/grub,LiveOS,EFI/BOOT}

# ---- Create squashfs of the rootfs ----
echo "Creating squashfs..." | tee -a "$LOG"
sudo mksquashfs "$BUILD_ROOT" "$STAGING/LiveOS/rootfs.squashfs" \
    -comp zstd -Xcompression-level 15 \
    -e proc -e sys -e dev -e run -e tmp \
    -e var/cache/distfiles -e var/cache/binpkgs \
    -e var/tmp/portage \
    -noappend 2>&1 | tail -5 | tee -a "$LOG"

echo "Squashfs size: $(du -sh "$STAGING/LiveOS/rootfs.squashfs" | cut -f1)" | tee -a "$LOG"

# ---- Copy kernel and initramfs ----
echo "Copying boot files..." | tee -a "$LOG"
KVER=$(ls "$BUILD_ROOT/lib/modules/" 2>/dev/null | sort -V | tail -1)
if [ -z "$KVER" ]; then
    echo "ERROR: No kernel modules found in $BUILD_ROOT/lib/modules/" | tee -a "$LOG"
    exit 1
fi
echo "Kernel version: $KVER" | tee -a "$LOG"

# Find kernel
if [ -f "$BUILD_ROOT/boot/vmlinuz-${KVER}" ]; then
    sudo cp "$BUILD_ROOT/boot/vmlinuz-${KVER}" "$STAGING/boot/vmlinuz"
elif [ -f "$BUILD_ROOT/boot/vmlinuz" ]; then
    sudo cp "$BUILD_ROOT/boot/vmlinuz" "$STAGING/boot/vmlinuz"
else
    # Find any vmlinuz
    VMLINUZ=$(find "$BUILD_ROOT/boot/" -name "vmlinuz*" -o -name "kernel*" | head -1)
    if [ -n "$VMLINUZ" ]; then
        sudo cp "$VMLINUZ" "$STAGING/boot/vmlinuz"
    else
        echo "ERROR: No kernel found!" | tee -a "$LOG"
        exit 1
    fi
fi

# Find or create initramfs
if [ -f "$BUILD_ROOT/boot/initramfs-${KVER}.img" ]; then
    sudo cp "$BUILD_ROOT/boot/initramfs-${KVER}.img" "$STAGING/boot/initramfs.img"
elif [ -f "$BUILD_ROOT/boot/initrd" ]; then
    sudo cp "$BUILD_ROOT/boot/initrd" "$STAGING/boot/initramfs.img"
else
    INITRD=$(find "$BUILD_ROOT/boot/" -name "initramfs*" -o -name "initrd*" | head -1)
    if [ -n "$INITRD" ]; then
        sudo cp "$INITRD" "$STAGING/boot/initramfs.img"
    else
        echo "WARNING: No initramfs found, will create one" | tee -a "$LOG"
        sudo chroot "$BUILD_ROOT" /bin/bash -c "
            source /etc/profile
            KVER=\$(ls /lib/modules/ | sort -V | tail -1)
            dracut --force /boot/initramfs-live.img \$KVER \
                --add 'dmsquash-live livenet' \
                --add-drivers 'squashfs overlay loop' \
                --no-hostonly 2>/dev/null
        "
        sudo cp "$BUILD_ROOT/boot/initramfs-live.img" "$STAGING/boot/initramfs.img"
    fi
fi

# ---- Create live-boot initramfs with squashfs support ----
echo "Creating live-boot initramfs..." | tee -a "$LOG"
sudo chroot "$BUILD_ROOT" /bin/bash -c "
    source /etc/profile
    KVER=\$(ls /lib/modules/ | sort -V | tail -1)
    if command -v dracut &>/dev/null; then
        dracut --force /boot/initramfs-live.img \$KVER \
            --add 'dmsquash-live' \
            --add-drivers 'squashfs overlay loop virtio_blk virtio_net virtio_pci virtio_scsi' \
            --no-hostonly --no-early-microcode 2>&1 | tail -5
    fi
" 2>&1 | tee -a "$LOG"

if [ -f "$BUILD_ROOT/boot/initramfs-live.img" ]; then
    sudo cp "$BUILD_ROOT/boot/initramfs-live.img" "$STAGING/boot/initramfs.img"
fi

# ---- GRUB config for live boot ----
cat > /tmp/grub-live.cfg << 'GRUBCFG'
set default=0
set timeout=5

menuentry "GentooVM Live" {
    linux /boot/vmlinuz root=live:CDLABEL=GENTOOVM rd.live.image rd.live.overlay.overlayfs=1 quiet splash
    initrd /boot/initramfs.img
}

menuentry "GentooVM Live (Safe Mode)" {
    linux /boot/vmlinuz root=live:CDLABEL=GENTOOVM rd.live.image nomodeset single
    initrd /boot/initramfs.img
}
GRUBCFG
sudo cp /tmp/grub-live.cfg "$STAGING/boot/grub/grub.cfg"

# ---- EFI boot ----
echo "Setting up EFI boot..." | tee -a "$LOG"
# Create EFI GRUB image
if command -v grub2-mkstandalone &>/dev/null; then
    GRUB_MKSTANDALONE=grub2-mkstandalone
elif command -v grub-mkstandalone &>/dev/null; then
    GRUB_MKSTANDALONE=grub-mkstandalone
else
    echo "WARNING: grub-mkstandalone not found" | tee -a "$LOG"
    GRUB_MKSTANDALONE=""
fi

if [ -n "$GRUB_MKSTANDALONE" ]; then
    $GRUB_MKSTANDALONE \
        --format=x86_64-efi \
        --output="$STAGING/EFI/BOOT/BOOTX64.EFI" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=/tmp/grub-live.cfg" 2>&1 | tee -a "$LOG"
fi

# ---- Also set up BIOS boot ----
if command -v grub2-mkstandalone &>/dev/null; then
    GRUB_MKSTANDALONE=grub2-mkstandalone
fi
# Create BIOS GRUB image for El Torito
if [ -n "$GRUB_MKSTANDALONE" ]; then
    $GRUB_MKSTANDALONE \
        --format=i386-pc \
        --output="$STAGING/boot/grub/bios.img" \
        --install-modules="linux normal iso9660 biosdisk memdisk search tar ls all_video" \
        --modules="linux normal iso9660 biosdisk search" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=/tmp/grub-live.cfg" 2>&1 | tee -a "$LOG"
fi

# ---- Build ISO ----
echo "Building ISO image..." | tee -a "$LOG"

# Determine xorriso arguments
XORRISO_ARGS=(
    -as mkisofs
    -iso-level 3
    -full-iso9660-filenames
    -volid "GENTOOVM"
    -output "$ISO_OUT"
)

# Add BIOS boot if bios.img exists
if [ -f "$STAGING/boot/grub/bios.img" ]; then
    # Need core.img for BIOS boot
    cat /usr/lib/grub/i386-pc/cdboot.img "$STAGING/boot/grub/bios.img" > /tmp/bios-combined.img 2>/dev/null || true
    if [ -f /tmp/bios-combined.img ]; then
        sudo cp /tmp/bios-combined.img "$STAGING/boot/grub/bios-combined.img"
        XORRISO_ARGS+=(
            -b boot/grub/bios-combined.img
            -no-emul-boot
            -boot-load-size 4
            -boot-info-table
            --grub2-boot-info
        )
    fi
fi

# Add EFI boot
if [ -f "$STAGING/EFI/BOOT/BOOTX64.EFI" ]; then
    # Create EFI boot image
    EFI_IMG="$STAGING/boot/efi.img"
    dd if=/dev/zero of="$EFI_IMG" bs=1M count=8 2>/dev/null
    mkfs.vfat "$EFI_IMG" 2>/dev/null
    MNTDIR=$(mktemp -d)
    sudo mount "$EFI_IMG" "$MNTDIR"
    sudo mkdir -p "$MNTDIR/EFI/BOOT"
    sudo cp "$STAGING/EFI/BOOT/BOOTX64.EFI" "$MNTDIR/EFI/BOOT/BOOTX64.EFI"
    sudo umount "$MNTDIR"
    rmdir "$MNTDIR"

    XORRISO_ARGS+=(
        -eltorito-alt-boot
        -e boot/efi.img
        -no-emul-boot
        -isohybrid-gpt-basdat
    )
fi

XORRISO_ARGS+=("$STAGING")

xorriso "${XORRISO_ARGS[@]}" 2>&1 | tee -a "$LOG"

# ---- Checksums ----
echo "Generating checksums..." | tee -a "$LOG"
cd /home/jalsarraf/gentoo
sha256sum gentoovm.iso > gentoovm.iso.sha256
md5sum gentoovm.iso > gentoovm.iso.md5

echo "=== ISO Build Complete ===" | tee -a "$LOG"
echo "ISO: $ISO_OUT ($(du -sh "$ISO_OUT" | cut -f1))" | tee -a "$LOG"
echo "SHA256: $(cat gentoovm.iso.sha256)" | tee -a "$LOG"
