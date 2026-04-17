#!/bin/bash

# ============================================================
#  KVM + virt-manager (GUI) Installer for Debian-based distros
#  Supports: Ubuntu, Debian, Linux Mint, Pop!_OS, Kali, Raspberry Pi OS
#  Usage: sudo bash install_kvm.sh
#
#  Author : Vignesh Vijay K
#  GitHub : https://github.com/VigneshVijayK
#  Repo   : https://github.com/VigneshVijayK/Debian-KVM-GUI-Setup
#  License: MIT
# ============================================================

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive   # Prevent apt interactive prompts

# ---------- Colors ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------- Global variables ----------
# Declared here so set -u never sees them as unbound (Bug fix #1)
REAL_USER=""
SERVICE_NAME=""

# ---------- Helper functions ----------
info()    { echo -e "${CYAN}[INFO]${NC}  $1"; }
success() { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   {
  echo -e "${RED}[ERROR]${NC} $1"
  echo -e "${RED}[ERROR]${NC} Exiting."
  exit 1
}

banner() {
  echo -e "${BOLD}${CYAN}"
  echo "=================================================="
  echo "   KVM + virt-manager Installer (Debian-based)   "
  echo "=================================================="
  echo -e "   Author : Vignesh Vijay K"
  echo -e "   GitHub : https://github.com/VigneshVijayK"
  echo -e "${NC}"
}

# ---------- Root check ----------
check_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Use: sudo bash $0"
  fi
  success "Running as root."
}

# ---------- Resolve real (non-root) user once ----------
resolve_user() {
  REAL_USER="${SUDO_USER:-}"
  if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
    REAL_USER=""
    warn "Could not determine a non-root user. Group assignment will be skipped."
  fi
}

# ---------- Debian-based distro check ----------
check_distro() {
  local distro_name distro_id distro_id_like distro_version
  distro_name=$(grep '^NAME='       /etc/os-release 2>/dev/null | cut -d'"' -f2)
  distro_id=$(grep '^ID='           /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"') || distro_id=""
  distro_id_like=$(grep '^ID_LIKE=' /etc/os-release 2>/dev/null | cut -d'"' -f2)              || distro_id_like=""
  distro_version=$(grep '^VERSION_ID=' /etc/os-release 2>/dev/null | cut -d'"' -f2)           || distro_version="rolling"

  if echo "$distro_id $distro_id_like" | grep -qiE '(debian|ubuntu)'; then
    success "Detected: ${distro_name} ${distro_version} (Debian-based) ✔"
  elif ! command -v apt-get &>/dev/null; then
    error "This script requires a Debian-based distro with apt-get. Detected: ${distro_name:-unknown}"
  else
    warn "Distro '${distro_name:-unknown}' is not confirmed Debian-based, but apt-get found. Proceeding..."
  fi
}

# ---------- CPU virtualization check ----------
check_cpu() {
  info "Checking CPU virtualization support..."

  # grep -E safely captures count; || sets to 0 if grep finds nothing (exit 1)
  CPU_FLAGS=$(grep -E -c '(vmx|svm)' /proc/cpuinfo 2>/dev/null) || CPU_FLAGS=0

  if [[ "$CPU_FLAGS" -eq 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Your CPU does not support hardware virtualization (Intel VT-x / AMD-V)."
    echo -e "${RED}[ERROR]${NC} Please enable it in BIOS/UEFI and re-run this script."
    exit 1
  fi

  if grep -E -q 'vmx' /proc/cpuinfo; then
    success "Intel VT-x virtualization support detected."
  elif grep -E -q 'svm' /proc/cpuinfo; then
    success "AMD-V virtualization support detected."
  fi
}

# ---------- Verify KVM acceleration ----------
check_kvm_ok() {
  info "Verifying KVM acceleration..."

  # Bug fix #2: cpu-checker is Ubuntu-only and does NOT exist in pure Debian/Kali repos.
  # Attempt to install it; if unavailable, fall back to /dev/kvm existence check.
  if apt-get install -y -qq cpu-checker 2>/dev/null; then
    KVM_OK_OUTPUT=$(kvm-ok 2>&1) || true
    if echo "$KVM_OK_OUTPUT" | grep -q "KVM acceleration can be used"; then
      success "KVM acceleration is available (kvm-ok confirmed)."
    else
      warn "kvm-ok says KVM acceleration may NOT be available."
      warn "Output: $KVM_OK_OUTPUT"
      warn "Continuing — you may need to enable VT-x/AMD-V in BIOS."
    fi
  else
    # Fallback for distros where cpu-checker is not in repos (e.g. pure Debian, Kali)
    warn "cpu-checker not available on this distro. Using /dev/kvm fallback check..."
    if [[ -e /dev/kvm ]]; then
      success "KVM acceleration is available (/dev/kvm exists)."
    else
      warn "/dev/kvm not found. KVM may not be available — check BIOS VT-x/AMD-V settings."
    fi
  fi
}

# ---------- Update system ----------
update_system() {
  info "Updating package lists..."
  apt-get update -qq
  success "Package lists updated."
}

# ---------- Install KVM packages ----------
install_packages() {
  info "Installing KVM, QEMU, libvirt, bridge-utils, and virt-manager..."
  apt-get install -y -qq \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virtinst \
    virt-manager \
    virt-viewer

  success "All KVM packages installed successfully."
}

# ---------- Enable and start libvirtd ----------
enable_service() {
  info "Enabling and starting libvirtd service..."

  # Detect correct service name — differs between Ubuntu/Debian versions
  if systemctl list-unit-files | grep -q 'libvirtd.service'; then
    SERVICE_NAME="libvirtd"
  elif systemctl list-unit-files | grep -q 'libvirt-bin.service'; then
    SERVICE_NAME="libvirt-bin"
  else
    warn "Could not detect libvirt service name. Defaulting to 'libvirtd'."
    SERVICE_NAME="libvirtd"
  fi

  systemctl enable --now "$SERVICE_NAME"

  if systemctl is-active --quiet "$SERVICE_NAME"; then
    success "${SERVICE_NAME} service is running."
  else
    error "${SERVICE_NAME} failed to start. Run: systemctl status ${SERVICE_NAME}"
  fi
}

# ---------- Add user to groups ----------
add_user_to_groups() {
  if [[ -z "$REAL_USER" ]]; then
    warn "Skipping group assignment — no non-root user found."
    warn "Manually run: sudo usermod -aG libvirt,kvm YOUR_USERNAME"
    return
  fi

  info "Adding user '${REAL_USER}' to libvirt and kvm groups..."
  usermod -aG libvirt "$REAL_USER"
  usermod -aG kvm     "$REAL_USER"
  success "User '${REAL_USER}' added to libvirt and kvm groups."
}

# ---------- Verify installation ----------
verify_install() {
  info "Verifying KVM installation with virsh..."

  # Explicit QEMU system URI prevents connection issues; if-guard prevents set -e exit
  if virsh --connect qemu:///system list --all &>/dev/null; then
    success "virsh is working correctly. KVM installation verified!"
  else
    warn "virsh could not connect yet — this is normal before re-login/reboot."
  fi

  echo ""
  info "Checking loaded KVM kernel modules..."
  if lsmod | grep -q kvm; then
    lsmod | grep kvm
    success "KVM kernel modules are loaded."
  else
    warn "KVM modules not loaded. Attempting to load them..."
    modprobe kvm || warn "Failed to load kvm module."
    if grep -E -q 'vmx' /proc/cpuinfo; then
      modprobe kvm_intel || warn "Failed to load kvm_intel module."
    else
      modprobe kvm_amd   || warn "Failed to load kvm_amd module."
    fi
    if lsmod | grep -q kvm; then
      success "KVM modules loaded successfully."
    else
      warn "KVM modules still not visible — a reboot may be required."
    fi
  fi
}

# ---------- Final summary ----------
print_summary() {
  echo ""
  echo -e "${BOLD}${GREEN}==============================================${NC}"
  echo -e "${BOLD}${GREEN}   Installation Complete!${NC}"
  echo -e "${BOLD}${GREEN}==============================================${NC}"
  echo ""
  echo -e "  ${BOLD}What was installed:${NC}"
  echo "    ✔ qemu-kvm        - KVM hypervisor"
  echo "    ✔ libvirt         - Virtualization management"
  echo "    ✔ bridge-utils    - Network bridging"
  echo "    ✔ virt-manager    - GUI for managing VMs"
  echo "    ✔ virt-viewer     - VM display viewer"
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  if [[ -n "$REAL_USER" ]]; then
    echo "    1. Log out and back in (or reboot) so group"
    echo "       changes take effect for user '${REAL_USER}'"
  else
    echo "    1. Add your user to groups manually:"
    echo "       sudo usermod -aG libvirt,kvm YOUR_USERNAME"
    echo "       Then log out and back in."
  fi
  echo ""
  echo "    2. Launch the GUI:"
  echo -e "       ${CYAN}virt-manager${NC}"
  echo ""
  echo "    3. Or use the command line:"
  echo -e "       ${CYAN}virsh --connect qemu:///system list --all${NC}"
  echo ""
  echo -e "  ${BOLD}To reboot now:${NC}"
  echo -e "       ${CYAN}sudo reboot${NC}"
  echo ""
  echo -e "  ${BOLD}Author:${NC} Vignesh Vijay K"
  echo -e "  ${BOLD}GitHub:${NC} ${CYAN}https://github.com/VigneshVijayK${NC}"
  echo ""
}

# ---------- Main ----------
banner
check_root
resolve_user
check_distro
check_cpu
check_kvm_ok
update_system
install_packages
enable_service
add_user_to_groups
verify_install
print_summary
