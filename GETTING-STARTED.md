# Getting Started with GentooVM

Welcome! This guide walks you through everything step by step. No Linux expertise required.

---

## What is GentooVM?

GentooVM is a ready-to-use Linux desktop that runs inside a virtual machine (VM). Think of it as a complete computer running inside a window on your existing computer. You don't need to install anything on your real hard drive.

**What you'll get:** A full desktop with a web browser, file manager, text editor, terminal, and more — all running safely inside a virtual machine.

---

## Step 1: Download

Go to the [Releases page](../../releases/latest) and download **all** files:

- `gentoovm.iso.part.01` — first half of the ISO
- `gentoovm.iso.part.02` — second half of the ISO
- `gentoovm.iso.sha256` — checksum for verification
- `reassemble.sh` — reassembly script (Linux/macOS)
- `reassemble.ps1` — reassembly script (Windows)

The ISO is split into two files because GitHub doesn't allow uploads larger than 2 GB.

### Reassemble the ISO

Put all downloaded files in the same folder, then:

**Linux / macOS:**
```bash
chmod +x reassemble.sh
./reassemble.sh
```

**Windows (PowerShell):**
```powershell
.\reassemble.ps1
```

**Manual (any OS with a terminal):**
```bash
cat gentoovm.iso.part.01 gentoovm.iso.part.02 > gentoovm.iso
```

The script will reassemble the parts and verify the checksum automatically. You should see "ISO verified successfully!" when done.

---

## Step 2: Install QEMU

GentooVM runs in QEMU, a free virtual machine program.

**Fedora/RHEL:**
```bash
sudo dnf install qemu-system-x86
```

**Ubuntu/Debian:**
```bash
sudo apt install qemu-system-x86 qemu-kvm
```

**Arch:**
```bash
sudo pacman -S qemu-desktop
```

**macOS (Homebrew):**
```bash
brew install qemu
```

---

## Step 3: Create a Virtual Disk

This creates an empty 50 GB virtual hard drive for GentooVM to install onto. It doesn't use 50 GB immediately — it grows as needed.

```bash
qemu-img create -f qcow2 gentoovm-disk.qcow2 50G
```

---

## Step 4: Boot the Installer

Copy and paste this command to start GentooVM from the ISO:

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 8192 \
    -drive file=gentoovm-disk.qcow2,format=qcow2,if=virtio \
    -cdrom gentoovm.iso \
    -boot d \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -device virtio-vga-gl \
    -device virtio-balloon \
    -device qemu-xhci \
    -device usb-tablet \
    -display gtk,gl=on \
    -name "GentooVM"
```

**What the options mean:**
- `-smp 4` — give the VM 4 CPU cores (adjust to your system)
- `-m 8192` — give it 8 GB of RAM (use 16384 for 16 GB if you have enough)
- `-device virtio-vga-gl` and `-display gtk,gl=on` — **required** for the desktop to work

A window will open showing the GentooVM boot screen.

---

## Step 5: Install

1. The desktop loads automatically — you're now in the "live" environment
2. **Double-click "Install GentooVM"** on the desktop
3. Follow the installer:
   - **Welcome** — click Next
   - **Location** — defaults to America/Chicago, change if needed
   - **Keyboard** — pick your layout
   - **Partitions** — select "Erase disk" (this only erases the virtual disk, not your real one!)
   - **Users** — pick a username and password
   - **Summary** — review and click Install
4. Wait for installation to finish (a few minutes)
5. Click **Restart Now**

---

## Step 6: Boot Your Installed System

After the installer finishes, close the QEMU window and run this command (no `-cdrom` this time):

```bash
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 8192 \
    -drive file=gentoovm-disk.qcow2,format=qcow2,if=virtio \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -device virtio-vga-gl \
    -device virtio-balloon \
    -device qemu-xhci \
    -device usb-tablet \
    -display gtk,gl=on \
    -name "GentooVM"
```

You'll see the GRUB boot menu (waits 30 seconds), then the login screen appears. Log in with the username and password you chose during installation.

---

## Step 7: Using Your Desktop

You now have a full Cinnamon desktop:

- **Application Menu** — bottom-left corner (or press the Super/Windows key)
- **Web Browser** — Firefox, in the menu under Internet
- **File Manager** — Nemo, click "Files" in the menu
- **Terminal** — Menu > System Tools > Terminal
- **Text Editor** — Mousepad (GUI) or `nano` (terminal)
- **Screenshot** — Menu > Accessories > Screenshot

A **README.md** file on your Desktop has detailed instructions for everything.

---

## Common Tasks

### Update your system
```bash
sudo emerge --sync
sudo emerge --update --deep --newuse @world
```

### Install new software
```bash
sudo emerge --ask <package-name>
```

### Manage kernels
Open **Kernel Manager** from the menu, or:
```bash
sudo gentoovm-kernel-manager
```

### Shut down
Click the menu > Quit > Shut Down, or:
```bash
sudo systemctl poweroff
```

---

## Troubleshooting

### "The desktop won't load" / "It kicks me back to the login screen"
You **must** launch QEMU with these exact options:
```
-device virtio-vga-gl -display gtk,gl=on
```
Without `gl=on`, the desktop compositor cannot start.

### "QEMU says KVM is not available"
- Make sure virtualization is enabled in your BIOS/UEFI
- On Linux, check: `ls /dev/kvm`
- You may need to add your user to the `kvm` group: `sudo usermod -aG kvm $USER`

### "The VM feels slow"
- Give it more RAM: change `-m 8192` to `-m 16384`
- Give it more CPUs: change `-smp 4` to `-smp 8`
- Make sure KVM is working (not software emulation)

### "I can't copy/paste between host and VM"
The VM includes spice-vdagent for clipboard sharing, but it requires a SPICE display. The default GTK display doesn't support clipboard sharing. This is a QEMU limitation.

---

## Safety

- GentooVM runs **entirely inside a virtual machine**. It cannot affect your real computer.
- The "Erase disk" option in the installer only erases the **virtual disk**, not your real hard drive.
- Your files, programs, and operating system are completely safe.
- **Do not** attempt to install GentooVM on real hardware (bare metal). It is designed and tested only for virtual machines.

---

*That's it! You now have a working Gentoo Linux desktop. Enjoy exploring!*
