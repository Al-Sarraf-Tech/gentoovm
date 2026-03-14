# GentooVM — Your Custom Gentoo Desktop

Welcome to **GentooVM**, a custom Gentoo-based Linux distribution built for virtual machine use. This system runs the **Cinnamon** desktop environment on a lean, optimized Gentoo foundation.

---

## What Is This?

GentooVM is a purpose-built Gentoo Linux installation optimized for QEMU/KVM virtual machines. It provides a familiar, polished desktop experience while preserving Gentoo's power and flexibility.

**Gentoo Linux** is a source-based distribution known for its flexibility and performance. Unlike Ubuntu or Fedora, Gentoo compiles software from source by default, giving you precise control over your system. This installation uses prebuilt binary packages for convenience.

**Cinnamon** is a modern desktop environment originally forked from GNOME. It provides a traditional desktop layout with a taskbar, system tray, application menu, and window management that feels intuitive to anyone familiar with Windows or traditional Linux desktops.

---

## Getting Started

### Logging In

Enter your username and password at the LightDM login screen. Cinnamon starts automatically after login.

### The Desktop

- **Application Menu**: Bottom-left corner — click the menu icon or press `Super` (Windows key)
- **Taskbar**: Bottom panel shows running applications
- **System Tray**: Bottom-right shows clock, network, volume, and notifications
- **File Manager**: Nemo — open from the menu or click "Files"
- **Right-click Desktop**: Access desktop settings and wallpaper options

### Opening a Terminal

- **Menu → System Tools → Terminal** (or search "terminal" in the menu)
- **Keyboard shortcut**: `Ctrl+Alt+T` (if configured)

---

## Package Management

Gentoo uses **Portage** (`emerge`) for package management.

### Updating the System

```bash
# Sync the package database
sudo emerge --sync

# Update all installed packages
sudo emerge --update --deep --newuse @world

# Clean up old packages
sudo emerge --depclean

# Rebuild anything that needs it
sudo revdep-rebuild
```

### Installing Software

```bash
# Search for a package
emerge --search firefox

# Show package info
emerge --info firefox

# Install a package (binary if available)
sudo emerge --ask www-client/firefox

# Install using binary packages only (faster)
sudo emerge --ask --getbinpkg www-client/firefox
```

### Removing Software

```bash
# Remove a package
sudo emerge --deselect www-client/firefox
sudo emerge --depclean
```

### Important Portage Concepts

- **USE flags**: Control which features are compiled into packages. View with `emerge --info | grep USE`. Edit in `/etc/portage/make.conf`.
- **Ebuilds**: Package build scripts in `/var/db/repos/gentoo/`
- **Binary packages**: Prebuilt packages from Gentoo's binary repository, enabled by default on this system
- **@world set**: Your explicitly installed packages, tracked in `/var/lib/portage/world`
- **Slots**: Gentoo can install multiple versions of a library simultaneously

---

## System Administration

### Using sudo

Your user account has administrator privileges via `sudo`.

```bash
# Run a single command as root
sudo <command>

# Get an interactive root shell
sudo -i

# Edit a system file
sudo nano /etc/some/config
```

You will be prompted for **your own password** (not the root password).

### Shutting Down and Rebooting

```bash
# Shutdown
sudo systemctl poweroff

# Reboot
sudo systemctl reboot

# From the desktop: use the menu → Quit → Shut Down / Restart
```

---

## Networking

NetworkManager handles network connections.

```bash
# Show connections
nmcli connection show

# Show network devices
nmcli device status

# Connect to Wi-Fi (if applicable)
nmcli device wifi connect "SSID" password "password"

# Show IP addresses
ip addr show
```

The network icon in the system tray provides a GUI for managing connections.

---

## Important File Locations

| Location | Purpose |
|---|---|
| `/etc/portage/make.conf` | Portage build configuration and USE flags |
| `/etc/portage/package.use/` | Per-package USE flag overrides |
| `/etc/portage/package.accept_keywords/` | Package keyword (version) overrides |
| `/var/db/repos/gentoo/` | Portage tree (package database) |
| `/var/log/` | System logs |
| `/var/log/emerge.log` | Package installation history |
| `/etc/fstab` | Filesystem mount table |
| `/etc/systemd/` | systemd service configuration |
| `/etc/conf.d/` | Service configuration |
| `~/.config/` | User application settings |
| `~/.local/share/` | User application data |

### Viewing Logs

```bash
# View system journal
journalctl -b             # current boot
journalctl -b -p err      # errors only
journalctl -f             # follow live

# View specific service logs
journalctl -u NetworkManager
journalctl -u lightdm

# View emerge log
cat /var/log/emerge.log | tail -50
```

---

## Disks and Mounts

```bash
# Show mounted filesystems
df -h

# Show block devices
lsblk

# Show disk UUIDs
blkid

# View fstab
cat /etc/fstab
```

This system uses **GPT** partitioning with **ext4** as the root filesystem. Swap is handled by **zram** (compressed memory — see below).

---

## Gentoo Concepts for Linux Users

If you come from Ubuntu, Fedora, or Arch, here are key Gentoo differences:

| Concept | Other Distros | Gentoo |
|---|---|---|
| Package manager | apt, dnf, pacman | emerge (Portage) |
| Package format | .deb, .rpm, .pkg.tar | ebuilds (source recipes) + binpkgs |
| Config management | Automatic | You own `/etc` — `etc-update` or `dispatch-conf` to merge |
| Init system | systemd (usually) | systemd (this install) or OpenRC |
| Release model | Point release or rolling | Rolling (continuous updates) |
| Compilation | Prebuilt only | Source or binary — your choice |

**Important Gentoo habits:**
- Run `sudo dispatch-conf` after updates to merge configuration file changes
- Check `eselect news read` for important announcements after syncing
- Gentoo is rolling-release — update regularly to avoid large, painful updates

---

## VM Optimizations

This system is specifically tuned for virtual machine use:

- **virtio drivers**: Block, network, and display use paravirtualized virtio drivers for near-native I/O performance
- **QEMU guest agent**: `qemu-guest-agent` enables host-guest communication (graceful shutdown, time sync)
- **SPICE agent**: `spice-vdagent` provides clipboard sharing and display auto-resize between host and guest
- **Minimal services**: Only essential services run at boot to reduce overhead
- **Lean kernel configuration**: Unnecessary hardware drivers are excluded

---

## zram and Compressed Memory

Instead of a traditional swap partition, this system uses **zram** — a compressed block device in RAM.

**What it does**: zram creates a compressed swap device in memory. When the system needs to swap, data is compressed and kept in RAM rather than written to the (slow, virtual) disk. This is dramatically faster than disk-based swap, especially in VMs.

**How it works**:
- zram compresses memory pages using the `zstd` algorithm
- Typical compression ratio is 2:1 to 4:1, effectively expanding usable memory
- A 4 GB zram device can hold 8-16 GB of compressed data

```bash
# Check zram status
zramctl

# View memory and swap usage
free -h
swapon --show

# Check vm.swappiness (controls swap eagerness)
cat /proc/sys/vm/swappiness
```

**Tuning**: `vm.swappiness=180` is set, which tells the kernel to prefer compressing memory into zram over evicting file caches. This is optimal for zram setups.

---

## Troubleshooting

### Desktop won't start
```bash
# Switch to a text console: Ctrl+Alt+F2
# Check LightDM status
sudo systemctl status lightdm
# Check Xorg logs
cat /var/log/Xorg.0.log | grep EE
# Restart display manager
sudo systemctl restart lightdm
```

### Package installation fails
```bash
# Check for blocked packages
emerge --pretend --verbose <package>
# Update portage itself
sudo emerge --oneshot portage
# Sync and retry
sudo emerge --sync
```

### System feels slow
```bash
# Check memory usage
free -h
# Check CPU usage
top
# Check disk I/O
iostat -x 1
# Verify zram is active
zramctl
```

### Network not working
```bash
# Restart NetworkManager
sudo systemctl restart NetworkManager
# Check device status
nmcli device status
# Check logs
journalctl -u NetworkManager --since "5 minutes ago"
```

### Cannot sudo
```bash
# Your user must be in the 'wheel' group
groups
# If not in wheel, from a root shell:
usermod -aG wheel <username>
```

### Merge configuration changes after update
```bash
sudo dispatch-conf
# Review each change: use 'u' to use the new version, 'z' to zap (keep old)
```

---

## Kernel Management

GentooVM includes a built-in **Kernel Manager** for browsing, installing, and removing Linux kernels. It supports both a graphical interface and a command-line interface.

### GUI Kernel Manager

Open from the application menu: **Menu > System > Kernel Manager**

Or from a terminal:
```bash
sudo gentoovm-kernel-manager-gui
```

The GUI provides three tabs:
- **Installed** — shows kernels on your system, with options to remove old ones
- **Available** — shows all Gentoo binary kernels you can install
- **kernel.org** — fetches the latest release info from https://www.kernel.org

### CLI Kernel Manager

```bash
# Launch interactive menu
sudo gentoovm-kernel-manager

# Check kernel.org for latest releases
sudo gentoovm-kernel-manager --check

# List available Gentoo binary kernels
sudo gentoovm-kernel-manager --list

# List installed kernels
sudo gentoovm-kernel-manager --installed

# Install a specific kernel version
sudo gentoovm-kernel-manager --install 6.19.8

# Remove an old kernel
sudo gentoovm-kernel-manager --remove 6.18.12

# Show running kernel
sudo gentoovm-kernel-manager --current
```

### Selecting a Kernel at Boot

When multiple kernels are installed, the **GRUB boot menu** appears for 5 seconds at startup. Use the arrow keys to select which kernel to boot, then press Enter. The most recently installed kernel is the default.

### Kernel Versions

- **Default**: 7.0 (mainline, when available in Gentoo packages)
- **Recommended**: Latest 6.19.x stable release
- **Browse releases**: https://www.kernel.org

After installing a new kernel, GRUB is updated automatically. Reboot to select the new kernel from the boot menu.

---

## Quick Reference

| Task | Command |
|---|---|
| Update system | `sudo emerge --sync && sudo emerge -uDN @world` |
| Install package | `sudo emerge --ask <package>` |
| Remove package | `sudo emerge --deselect <pkg> && sudo emerge --depclean` |
| Search packages | `emerge --search <name>` |
| System info | `emerge --info` |
| Disk usage | `df -h` |
| Memory usage | `free -h` |
| Running services | `systemctl list-units --type=service` |
| Boot log | `journalctl -b` |
| Reboot | `sudo systemctl reboot` |
| Shutdown | `sudo systemctl poweroff` |
| Root shell | `sudo -i` |

---

*GentooVM — Built with Gentoo. Optimized for VMs. Ready to use.*
