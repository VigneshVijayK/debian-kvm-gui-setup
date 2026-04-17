# Debian-KVM-GUI-Setup

> Automated KVM + virt-manager GUI installer for Debian-based Linux distros.

A single bash script that fully installs and configures KVM (Kernel-based Virtual Machine) with the **virt-manager** graphical interface on any Debian-based Linux distribution — no manual steps required.

---

## Supported Distros

| Distro | Status |
|---|---|
| Ubuntu (20.04, 22.04, 24.04+) | ✅ Supported |
| Debian (10, 11, 12+) | ✅ Supported |
| Linux Mint | ✅ Supported |
| Pop!\_OS | ✅ Supported |
| Kali Linux | ✅ Supported |
| Raspberry Pi OS (64-bit) | ✅ Supported |
| elementary OS | ✅ Supported |
| Zorin OS | ✅ Supported |

---

## Requirements

- 64-bit processor with **Intel VT-x** or **AMD-V** virtualization support
- Virtualization enabled in **BIOS/UEFI**
- A Debian-based distro with `apt-get`
- `sudo` / root access

> To check if your CPU supports virtualization, run:
> ```bash
> grep -E -c '(vmx|svm)' /proc/cpuinfo
> ```
> A result of **1 or more** means your CPU is supported.

---

## What the Script Does

1. Checks it is running as root
2. Detects your Debian-based distro and version
3. Verifies CPU hardware virtualization support (Intel VT-x / AMD-V)
4. Installs `cpu-checker` and runs `kvm-ok` to confirm KVM acceleration
5. Updates package lists
6. Installs all required packages:
   - `qemu-kvm` — KVM hypervisor
   - `libvirt-daemon-system` — virtualization daemon
   - `libvirt-clients` — CLI tools (`virsh`)
   - `bridge-utils` — network bridging
   - `virtinst` — VM creation utility
   - `virt-manager` — graphical VM manager
   - `virt-viewer` — VM display viewer
7. Enables and starts the `libvirtd` service
8. Adds your user to the `libvirt` and `kvm` groups
9. Verifies the installation with `virsh`
10. Checks and loads KVM kernel modules if needed
11. Prints a final summary with next steps

---

## Usage

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/Debian-KVM-GUI-Setup.git
cd Debian-KVM-GUI-Setup
```

### 2. Make the script executable

```bash
chmod +x install_kvm.sh
```

### 3. Run with sudo

```bash
sudo bash install_kvm.sh
```

### 4. Reboot or log out and back in

After the script completes, log out and back in (or reboot) so the group changes take effect:

```bash
sudo reboot
```

### 5. Launch virt-manager

```bash
virt-manager
```

Or find **Virtual Machine Manager** in your application menu.

---

## After Installation

**Create a new VM:**
Open virt-manager → File → New Virtual Machine → follow the wizard to select an ISO and allocate resources.

**Check running VMs via CLI:**
```bash
virsh --connect qemu:///system list --all
```

**Check service status:**
```bash
systemctl status libvirtd
```

---

## Troubleshooting

**`kvm-ok` reports KVM not available**
Enable Intel VT-x or AMD-V in your BIOS/UEFI settings, then reboot and re-run the script.

**`virt-manager` won't open**
Make sure you are on a desktop session. If using SSH, you need X forwarding (`ssh -X`).

**Permission denied errors**
Ensure you have logged out and back in after the script ran so group changes (`libvirt`, `kvm`) are applied.

**`virsh` connection error after install**
This is normal immediately after install. Log out and back in, then try again:
```bash
virsh --connect qemu:///system list --all
```

**Manually add user to groups (if skipped)**
```bash
sudo usermod -aG libvirt,kvm $USER
```
Then log out and back in.

---

## Packages Installed

| Package | Purpose |
|---|---|
| `qemu-kvm` | KVM hypervisor engine |
| `libvirt-daemon-system` | Virtualization management daemon |
| `libvirt-clients` | CLI tools for managing VMs |
| `bridge-utils` | Network bridge support |
| `virtinst` | Command-line VM creation |
| `virt-manager` | Graphical VM manager (GUI) |
| `virt-viewer` | VM display/console viewer |

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Contributing

Pull requests are welcome! If you encounter an issue on a specific Debian-based distro, please open an issue with your distro name, version, and the error output.

---

## Author

Made with ❤️ for the Linux community.
