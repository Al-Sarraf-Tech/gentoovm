# GentooVM

[![CI](https://github.com/jalsarraf0/gentoovm/actions/workflows/ci.yml/badge.svg)](https://github.com/jalsarraf0/gentoovm/actions/workflows/ci.yml)
[![Release](https://github.com/jalsarraf0/gentoovm/actions/workflows/release.yml/badge.svg)](https://github.com/jalsarraf0/gentoovm/actions/workflows/release.yml)

A custom Gentoo Linux distribution built from scratch for QEMU/KVM virtual machines. Boots into a polished Cinnamon desktop with a one-click GUI installer.

**New to Linux or VMs?** Start here: **[Getting Started Guide](GETTING-STARTED.md)** — a step-by-step walkthrough with no prior experience needed.

---

> **This distribution is designed exclusively for virtual machine use (QEMU/KVM).**
> Running on bare metal hardware is untested and unsupported. If you attempt bare metal installation, you do so entirely at your own risk. No support will be provided for bare metal configurations.

---

## Download

### Option 1: GitHub Release

Download from the [Releases page](../../releases/latest). The ISO is split into two parts due to GitHub's file size limit.

**Linux / macOS:**
```bash
# Download all files from the release, then:
chmod +x reassemble.sh
./reassemble.sh
```

**Windows (PowerShell):**
```powershell
# Download all files from the release, then:
.\reassemble.ps1
```

**Manual reassembly:**
```bash
cat gentoovm.iso.part.* > gentoovm.iso
sha256sum -c gentoovm.iso.sha256
```

### Option 2: Torrent

Download the `.torrent` file from the [Releases page](../../releases/latest), or use the magnet link:

```
magnet:?xt=urn:btih:9b7428083903e40ac48c05e1c1150ac69536f41b&dn=gentoovm.iso
```

The torrent downloads the full ISO in a single file — no reassembly needed. Uses public trackers.

---

## What You Get

- **Gentoo Linux** base with 889 prebuilt packages
- **Cinnamon 6.4.13** desktop environment
- **Kernel 6.19.7** with virtio and virgl GPU acceleration
- **Calamares** graphical installer — no Gentoo knowledge required to install
- **Offline installation** — no internet needed during install
- **BIOS and UEFI** auto-detection — works with SeaBIOS or OVMF
- **zram** compressed memory with aggressive VM tuning
- **Kernel Manager** — GUI and CLI tools to browse, install, and switch kernels
- **GRUB boot menu** with 30-second kernel selection timeout

### Included Software

| Category | Application |
|---|---|
| Desktop | Cinnamon 6.4.13 |
| Display Manager | LightDM |
| Browser | Firefox |
| File Manager | Nemo |
| Terminal | XFCE4 Terminal |
| GUI Text Editor | Mousepad |
| Terminal Text Editor | nano |
| Screenshot | GNOME Screenshot |
| Archive Manager | File Roller (p7zip, zip, unzip) |
| System Monitor | GNOME System Monitor |
| Network | NetworkManager |
| VM Integration | qemu-guest-agent, spice-vdagent, virtio GPU |

---

## Quick Start

### Requirements

- QEMU/KVM with `virtio-vga-gl` support
- Host with OpenGL (for virgl GPU passthrough to the guest)
- 4+ CPU cores, 4+ GB RAM (16 GB recommended), 50 GB disk

### Boot the ISO

```bash
# Create a virtual disk
qemu-img create -f qcow2 disk.qcow2 50G

# Boot from ISO
qemu-system-x86_64 \
    -enable-kvm -cpu host -smp 4 -m 16384 \
    -drive file=disk.qcow2,format=qcow2,if=virtio \
    -cdrom gentoovm.iso -boot d \
    -device virtio-net-pci,netdev=net0 -netdev user,id=net0 \
    -device virtio-vga-gl \
    -device virtio-balloon -device qemu-xhci -device usb-tablet \
    -display gtk,gl=on \
    -name "GentooVM"
```

### Install

1. The live desktop loads automatically (user `gentoo`, password `gentoo`)
2. Double-click **Install GentooVM** on the desktop
3. Follow the prompts: language, timezone, keyboard, disk, username/password
4. Timezone defaults to **America/Chicago**
5. Click **Install** and wait for completion
6. Click **Restart Now** — the ISO ejects automatically

### Boot the Installed System

```bash
qemu-system-x86_64 \
    -enable-kvm -cpu host -smp 4 -m 16384 \
    -drive file=disk.qcow2,format=qcow2,if=virtio \
    -device virtio-net-pci,netdev=net0 -netdev user,id=net0 \
    -device virtio-vga-gl \
    -device virtio-balloon -device qemu-xhci -device usb-tablet \
    -display gtk,gl=on \
    -name "GentooVM"
```

GRUB shows a 30-second menu for kernel selection, then boots into the LightDM login screen.

---

## Using Gentoo

GentooVM is a full Gentoo Linux system. If you are new to Gentoo, here is what you need to know.

### Package Management

Gentoo uses **Portage** (`emerge`) instead of apt, dnf, or pacman.

```bash
# Update the package database
sudo emerge --sync

# Update all packages
sudo emerge --update --deep --newuse @world

# Install a package
sudo emerge --ask <package-name>

# Remove a package
sudo emerge --deselect <package-name>
sudo emerge --depclean

# Search for a package
emerge --search <name>
```

This system uses **binary packages** by default — most installs download prebuilt binaries rather than compiling from source.

### System Administration

Your user is in the `wheel` group with full `sudo` access.

```bash
# Run a command as root
sudo <command>

# Get a root shell
sudo -i

# Reboot
sudo systemctl reboot

# Shutdown
sudo systemctl poweroff
```

### Configuration Management

After updating packages, Gentoo may have new configuration files that need merging:

```bash
sudo dispatch-conf
```

Review each change and choose to accept or keep the old version.

### Important Locations

| Path | Purpose |
|---|---|
| `/etc/portage/make.conf` | Build settings and USE flags |
| `/etc/portage/package.use/` | Per-package USE flag overrides |
| `/var/db/repos/gentoo/` | Package database (portage tree) |
| `/var/log/emerge.log` | Package install history |
| `/etc/systemd/` | Service configuration |
| `~/.config/` | User app settings |

---

## Kernel Management

GentooVM includes a built-in kernel manager for browsing, installing, and removing kernels.

### GUI Kernel Manager

Open from the menu: **Menu > System > Kernel Manager**

Or from a terminal:
```bash
sudo gentoovm-kernel-manager-gui
```

Three tabs:
- **Installed** — kernels on your system, remove old ones
- **Available** — Gentoo binary kernels ready to install
- **kernel.org** — latest release info from https://www.kernel.org

### CLI Kernel Manager

```bash
sudo gentoovm-kernel-manager              # Interactive menu
sudo gentoovm-kernel-manager --check      # Check kernel.org
sudo gentoovm-kernel-manager --list       # Available kernels
sudo gentoovm-kernel-manager --installed  # Installed kernels
sudo gentoovm-kernel-manager --install 6.19.8   # Install specific version
sudo gentoovm-kernel-manager --remove 6.18.12   # Remove old kernel
```

### Selecting a Kernel at Boot

When multiple kernels are installed, the **GRUB boot menu** appears for 30 seconds at startup. Use arrow keys to select, then press Enter. The most recently installed kernel is the default.

### Kernel Versions

- **Default**: 7.0 (mainline, when available in Gentoo packages)
- **Recommended**: Latest stable 6.19.x
- **Browse releases**: https://www.kernel.org

---

## VM Optimizations

This system is specifically tuned for QEMU/KVM:

- **virtio drivers** for disk, network, and GPU (near-native I/O)
- **virgl GPU** acceleration (hardware OpenGL in the guest)
- **zram** compressed swap in RAM (no disk swap partition)
- **vm.swappiness=180** — prefer compressing memory over evicting caches
- **earlyoom** — OOM protection kills runaway processes before the kernel OOM killer
- **qemu-guest-agent** — host-guest communication (graceful shutdown, time sync)
- **spice-vdagent** — clipboard sharing and display auto-resize

### Important: virtio-vga-gl Required

Cinnamon requires OpenGL. This distribution uses the **virgl** GPU driver, which requires launching QEMU with:

```
-device virtio-vga-gl -display gtk,gl=on
```

Without `gl=on`, the Cinnamon desktop will fail to start. The LightDM greeter will still work, but the Cinnamon session will crash on login.

---

## How It Was Built

GentooVM is built from a Gentoo stage3 tarball using the following process:

1. **Base system**: Gentoo stage3-amd64-systemd extracted and updated
2. **Profile**: `default/linux/amd64/23.0/desktop/systemd`
3. **Package installation**: Cinnamon, LightDM, Calamares, kernel, firmware, apps — 889 packages total
4. **Configuration**: LightDM, sudo, zram, sysctl, NetworkManager, earlyoom, GRUB
5. **Live session**: Auto-login user, Calamares desktop shortcut, polkit rules
6. **ISO assembly**: squashfs (zstd compressed) + dracut initramfs (dmsquash-live) + GRUB (grub2-mkrescue)
7. **Validation**: 234 automated checks across static analysis, smoke tests, E2E preflight, regression suite, QEMU boot tests, and installed system deep scans

### Rebuilding from Source

```bash
# 1. Extract a Gentoo stage3 into build/
sudo tar xpf cache/stage3-*.tar.xz -C build/ --xattrs-include='*.*' --numeric-owner

# 2. Mount chroot filesystems
sudo mount --types proc /proc build/proc
sudo mount --rbind /sys build/sys && sudo mount --make-rslave build/sys
sudo mount --rbind /dev build/dev && sudo mount --make-rslave build/dev
sudo mount --bind /run build/run
sudo cp -L /etc/resolv.conf build/etc/resolv.conf

# 3. Inside chroot: sync portage, set profile, install packages
sudo chroot build emerge-webrsync
sudo chroot build eselect profile set default/linux/amd64/23.0/desktop/systemd
bash scripts/install-desktop-packages.sh

# 4. Configure system
bash scripts/configure-system.sh

# 5. Set up live session
bash scripts/setup-live-session.sh

# 6. Build ISO
bash scripts/build-iso.sh

# 7. Validate
bash run-all-preqemu-validation.sh
```

See `docs/README.md` for detailed rebuild instructions.

---

## Validation

Run the full test suite:

```bash
bash run-all-preqemu-validation.sh    # Stages 1-7 (static, smoke, E2E, regression)
bash run-qemu-live-test.sh            # Stage 8 (QEMU ISO boot)
bash run-qemu-installed-test.sh       # Stage 9 (installed system boot)
```

---

## Repository Structure

```
gentoovm/
  calamares/           Calamares installer configuration
    branding/          Installer branding (logo, slideshow)
    modules/           Module configs (partition, users, bootloader, etc.)
    settings.conf      Installer module sequence
  config/              System configuration templates
    README-desktop.md  README placed on installed user's Desktop
    gentoovm-kernel-manager      CLI kernel manager script
    gentoovm-kernel-manager-gui  GUI kernel manager (Python/GTK3)
  scripts/             Build scripts
  qemu/                QEMU launch scripts
  docs/                Detailed rebuild documentation
  manifests/           Package manifests
  iso/                 Golden ISO output (checksums tracked, ISO gitignored)
  run-*.sh             Validation pipeline scripts
```

---

## Troubleshooting

**Cinnamon won't start / kicks back to login**
- Ensure QEMU is launched with `-device virtio-vga-gl -display gtk,gl=on`
- Without GL passthrough, Cinnamon cannot initialize its compositor

**GRUB menu doesn't appear**
- The menu shows for 30 seconds. If it's too fast, edit `/etc/default/grub` and set `GRUB_TIMEOUT=` to a higher value, then run `sudo grub-mkconfig -o /boot/grub/grub.cfg`

**Installer fails at bootloader step**
- The post-install script auto-detects BIOS vs UEFI and uses `--force` for GPT+BIOS
- If it fails, boot into the live ISO and run `grub-install` manually from a chroot

**System feels slow**
- Verify zram is active: `zramctl`
- Check memory: `free -h`
- Ensure earlyoom is running: `systemctl status earlyoom`

**Package installation errors**
- Run `sudo emerge --sync` to update the package database
- Check USE flag conflicts: `emerge --pretend --verbose <package>`

---

## License

GentooVM is built from Gentoo Linux packages, each under their respective licenses. The build scripts and configuration in this repository are provided as-is for personal and educational use.

---

*GentooVM 1.0 — Built with Gentoo. Optimized for VMs. Ready to use.*
