#!/usr/bin/env bash
# File: ~/scripts/tn_universal_nvidia_signed.sh
# Purpose: Universal NVIDIA driver install with Secure Boot (MOK) signing support
# Distros: Fedora/RHEL, Ubuntu/Debian, Arch/Manjaro
# Behavior: Safe-by-default, idempotent, vendor-signed where possible, DKMS+MOK if needed.

set -Eeuo pipefail

# ===== Colors =====
RED="\033[31m"; BLUE="\033[34m"; RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"

print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal NVIDIA (Signed) by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

log()   { printf '%b\n' "${DIM}==> $*${RESET}"; }
warn()  { printf '%b\n' "${RED}[!]${RESET} $*\n"; }
have()  { command -v "$1" >/dev/null 2>&1; }

trap 'warn "Error on line $LINENO"' ERR

# ===== Defaults / Flags =====
YES=0
DRY_RUN=0
SKIP_REPOS=0
NO_BLACKLIST=0
NO_MODESET=0
NO_SERVICES=0
NO_SIGN=0
FORCE_MOK_REIMPORT=0
FORCE_INITRAMFS=0
INSTALL_ONLY=0
CONFIG_ONLY=0

usage() {
  cat <<'EOF'
Usage: sudo ./tn_universal_nvidia_signed.sh [options]

General:
  -y, --yes                Non-interactive (assume yes where possible)
      --dry-run            Print actions without executing them
      --skip-repos         Do not enable or modify repository configuration
      --install-only       Install/upgrade NVIDIA packages only (no system config)
      --configure-only     Only do system config (blacklist, bootline, signing, services)
      --force-initramfs    Force initramfs/regenerate all images

Secure Boot / Signing:
      --no-sign            Do not perform local MOK signing even if SB is enabled
      --force-mok-reimport Recreate MOK keys and re-import (will require reboot enrollment)

Kernel / Modules:
      --no-blacklist       Do not blacklist nouveau
      --no-modeset         Do not add nvidia_drm.modeset=1
      --no-services        Do not enable nvidia-persistenced / nvidia-powerd

Help:
  -h, --help               Show this help

Notes:
- Safe to re-run. On Ubuntu/Pop it prefers vendor-signed drivers via ubuntu-drivers.
- On Fedora it uses RPM Fusion + akmods. On Arch it uses nvidia-dkms + headers.
EOF
}

# Simple runner (honors DRY_RUN)
run() {
  if ((DRY_RUN)); then
    echo "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

# ---- Secure Boot helpers ----
sb_enabled() { mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot.*enabled'; }
mod_signed() { modinfo "$1" 2>/dev/null | grep -qi '^signer:'; }

# Locate sign-file or kmodsign
find_sign_tool() {
  local sf="/usr/lib/modules/$(uname -r)/build/scripts/sign-file"
  if [[ -x "$sf" ]]; then echo "$sf"; return 0; fi
  if have kmodsign; then echo "kmodsign"; return 0; fi
  local sf2="/usr/src/kernels/$(uname -r)/scripts/sign-file"
  [[ -x "$sf2" ]] && { echo "$sf2"; return 0; }
  return 1
}

ensure_mok_key() {
  local d="/root/MOK"
  local key="$d/MOK.priv"
  local crt="$d/MOK.crt"

  if ((FORCE_MOK_REIMPORT)); then
    log "Forcing MOK key regeneration and re-import..."
    run "rm -f '$key' '$crt'"
  fi

  if [[ ! -s "$key" || ! -s "$crt" ]]; then
    log "Generating new MOK key (one-time)..."
    run "mkdir -p '$d'"
    run "openssl req -new -x509 -newkey rsa:2048 -keyout '$key' -out '$crt' -nodes -days 36500 -subj '/CN=Team-Nocturnal NVIDIA MOK/'"
    run "chmod 600 '$key'"
    log "Importing MOK (you must enroll it on next boot)..."
    run "mokutil --import '$crt' || true"
  else
    log "Existing MOK key found."
  fi
}

sign_nvidia_modules_if_needed() {
  if ! sb_enabled; then
    log "Secure Boot disabled — skipping signing."
    return 0
  fi
  if ((NO_SIGN)); then
    log "--no-sign specified — skipping signing."
    return 0
  fi
  if mod_signed nvidia; then
    log "NVIDIA module(s) already vendor-signed — no local signing needed."
    return 0
  fi

  ensure_mok_key
  local sign_tool; sign_tool="$(find_sign_tool)" || { warn "No sign-file/kmodsign found; skipping signing."; return 0; }

  local hash_alg="sha256"
  local key="/root/MOK/MOK.priv"
  local crt="/root/MOK/MOK.crt"
  local mods=()
  while IFS= read -r -d '' f; do mods+=("$f"); done < <(find "/lib/modules/$(uname -r)" -type f -name 'nvidia*.ko*' -print0 2>/dev/null || true)

  if ((${#mods[@]}==0)); then
    warn "No NVIDIA modules found to sign yet (they may build after reboot)."
    return 0
  fi

  log "Signing ${#mods[@]} NVIDIA module(s) with MOK..."
  for m in "${mods[@]}"; do
    if [[ "$sign_tool" == "kmodsign" ]]; then
      run "kmodsign '$hash_alg' '$key' '$crt' '$m' || true"
    else
      run "'$sign_tool' '$hash_alg' '$key' '$crt' '$m' || true"
    fi
  done
  log "Signing complete. If you just imported a new MOK, reboot and choose 'Enroll MOK'."
}

blacklist_nouveau() {
  if ((NO_BLACKLIST)); then
    log "--no-blacklist specified — skipping nouveau blacklist."
    return 0
  fi
  log "Blacklisting nouveau..."
  run "mkdir -p /etc/modprobe.d"
  run "bash -c 'cat >/etc/modprobe.d/blacklist-nouveau.conf <<EOF
blacklist nouveau
options nouveau modeset=0
EOF'"
}

set_kernel_cmdline_flags() {
  local flags=()
  if ((NO_MODESET==0)); then
    flags+=("nvidia_drm.modeset=1")
  fi
  if ((NO_BLACKLIST==0)); then
    flags+=("rd.driver.blacklist=nouveau" "modprobe.blacklist=nouveau" "nouveau.blacklist=1")
  fi
  ((${#flags[@]})) || { log "No kernel flags requested — skipping bootline update."; return 0; }

  if [[ -d /boot/loader/entries || -f /boot/loader/loader.conf ]]; then
    log "Updating /etc/kernel/cmdline for systemd-boot..."
    local f="/etc/kernel/cmdline"; [[ -f "$f" ]] || run "touch '$f'"
    local cur; cur="$(tr -d '\n' <"$f" 2>/dev/null || true)"
    for p in "${flags[@]}"; do
      grep -qw "$p" <<<"$cur" || cur="$cur $p"
    done
    cur="$(echo "$cur" | sed -E 's/ +/ /g;s/^ //')"
    run "bash -c 'echo \"$cur\" > \"$f\"'"
    if have bootctl; then run "bootctl update || true"; fi
    if have dracut; then run "dracut --regenerate-all --force || true"; fi
  else
    log "Updating GRUB kernel command line..."
    local f="/etc/default/grub"
    [[ -f "$f" ]] || run "touch '$f'"
    if grep -q '^GRUB_CMDLINE_LINUX=' "$f" 2>/dev/null; then
      for p in "${flags[@]}"; do
        grep -q "$p" "$f" || run "sed -i \"s|^GRUB_CMDLINE_LINUX=\\\"|GRUB_CMDLINE_LINUX=\\\"$p |\" '$f'"
      done
    else
      run "bash -c 'echo \"GRUB_CMDLINE_LINUX=\\\"${flags[*]}\\\"\" >> \"$f\"'"
    fi
    if have update-grub; then
      run "update-grub || true"
    elif have grub2-mkconfig; then
      if [[ -d /boot/grub2 ]]; then
        run "grub2-mkconfig -o /boot/grub2/grub.cfg || true"
      elif [[ -d /boot/efi/EFI/fedora ]]; then
        run "grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg || true"
      fi
    fi
  fi

  if ((FORCE_INITRAMFS)); then
    log "--force-initramfs specified — regenerating initramfs images."
    if have dracut; then run "dracut --regenerate-all --force || true"; fi
    if have update-initramfs; then run "update-initramfs -u -k all || true"; fi
    if have mkinitcpio; then run "mkinitcpio -P || true"; fi
  fi
}

enable_nvidia_services_if_present() {
  if ((NO_SERVICES)); then
    log "--no-services specified — skipping service enablement."
    return 0
  fi
  have systemctl || return 0
  run "systemctl enable --now nvidia-persistenced.service 2>/dev/null || true"
  run "systemctl enable --now nvidia-powerd.service 2>/dev/null || true"
}

# ---- Distro detect ----
read_os_release() { . /etc/os-release 2>/dev/null || true; }

is_fedora_like()  { [[ "${ID_LIKE:-}" =~ rhel|fedora || "${ID:-}" =~ fedora|rhel|centos|rocky|almalinux ]]; }
is_debian_like()  { [[ "${ID_LIKE:-}" =~ debian|ubuntu || "${ID:-}" =~ debian|ubuntu|linuxmint|pop ]]; }
is_arch_like()    { [[ "${ID_LIKE:-}" =~ arch || "${ID:-}" =~ arch|manjaro|endeavouros ]]; }

# ---- Install per-distro ----
install_fedora_like() {
  log "Detected Fedora/RHEL-like system."
  if ! have dnf; then warn "dnf not found; skipping Fedora section."; return 0; fi
  if ((SKIP_REPOS==0)); then
    log "Ensuring RPM Fusion (free & nonfree)..."
    run "dnf -y install dnf-plugins-core 2>/dev/null || true"
    run "dnf -y install \
      \"https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm\" \
      \"https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm\" || true"
  else
    log "--skip-repos specified — not touching repo config."
  fi
  log "Installing NVIDIA stack (akmods) and tools..."
  run "dnf -y install kernel-devel kernel-headers gcc make mokutil openssl nss-tools dracut \
      akmods kmodtool \
      xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda \
      xorg-x11-drv-nvidia-power nvidia-settings nvidia-persistenced || true"

  # Build modules proactively
  if have akmods; then run "akmods --force --kernels \"$(uname -r)\" || true"; fi
  if have depmod; then run "depmod -a || true"; fi
  if have dracut && ((FORCE_INITRAMFS)); then run "dracut --regenerate-all --force || true"; fi
}

install_debian_like() {
  log "Detected Ubuntu/Debian-like system."
  if ! have apt-get; then warn "apt-get not found; skipping Debian section."; return 0; fi

  if ((SKIP_REPOS==0)); then
    if grep -qi 'debian' /etc/os-release 2>/dev/null; then
      log "Ensuring contrib/non-free/non-free-firmware in /etc/apt/sources.list..."
      run "sed -i -E 's/^deb(.*) main( |$)/deb\\1 main contrib non-free non-free-firmware /' /etc/apt/sources.list || true"
    fi
  else
    log "--skip-repos specified — leaving apt sources as-is."
  fi

  run "apt-get update || true"
  if have ubuntu-drivers; then
    log "Using ubuntu-drivers for vendor-signed packages..."
    run "apt-get -y install ubuntu-drivers-common mokutil || true"
    run "DEBIAN_FRONTEND=noninteractive ubuntu-drivers autoinstall || true"
    run "apt-get -y install build-essential dkms linux-headers-$(uname -r) || true"
  else
    log "Installing via apt (Debian or Ubuntu without ubuntu-drivers)..."
    local yflag=""; ((YES)) && yflag="-y"
    run "apt-get $yflag install mokutil build-essential dkms linux-headers-$(uname -r) || true"
    run "apt-get $yflag install nvidia-driver || true"
    run "apt-get $yflag install nvidia-settings nvidia-persistenced || true"
  fi
}

install_arch_like() {
  log "Detected Arch/Manjaro-like system."
  if ! have pacman; then warn "pacman not found; skipping Arch section."; return 0; fi
  run "pacman --noconfirm -Syu || true"
  run "pacman --noconfirm -S linux-headers || true"
  run "pacman --noconfirm -S linux-lts-headers || true"
  run "pacman --noconfirm -S dkms base-devel mokutil || true"
  run "pacman --noconfirm -S nvidia-dkms nvidia-utils nvidia-settings || true"
  if have dkms; then run "dkms autoinstall || true"; fi
  if have depmod; then run "depmod -a || true"; fi
  if have mkinitcpio && ((FORCE_INITRAMFS)); then run "mkinitcpio -P || true"; fi
}

# ---- Arg parse ----
parse_args() {
  while (( $# )); do
    case "$1" in
      -y|--yes) YES=1;;
      --dry-run) DRY_RUN=1;;
      --skip-repos) SKIP_REPOS=1;;
      --no-blacklist) NO_BLACKLIST=1;;
      --no-modeset) NO_MODESET=1;;
      --no-services) NO_SERVICES=1;;
      --no-sign) NO_SIGN=1;;
      --force-mok-reimport) FORCE_MOK_REIMPORT=1;;
      --force-initramfs) FORCE_INITRAMFS=1;;
      --install-only) INSTALL_ONLY=1;;
      --configure-only) CONFIG_ONLY=1;;
      -h|--help) usage; exit 0;;
      *) warn "Unknown option: $1"; usage; exit 2;;
    esac
    shift
  done

  if ((INSTALL_ONLY && CONFIG_ONLY)); then
    warn "--install-only and --configure-only are mutually exclusive."
    exit 2
  fi
}

# ---- Main ----
main() {
  print_banner
  [[ $EUID -eq 0 ]] || { warn "Run this as root (sudo)."; exit 1; }
  parse_args "$@"
  read_os_release

  log "Secure Boot: $(sb_enabled && echo ENABLED || echo DISABLED)"
  log "Mode: $(
    ((INSTALL_ONLY)) && echo 'INSTALL-ONLY' || \
    ((CONFIG_ONLY)) && echo 'CONFIGURE-ONLY' || \
    echo 'FULL'
  )"

  if ((CONFIG_ONLY==0)); then
    if is_fedora_like; then
      install_fedora_like
    elif is_debian_like; then
      install_debian_like
    elif is_arch_like; then
      install_arch_like
    else
      warn "Unsupported distro (ID=${ID:-unknown} ID_LIKE=${ID_LIKE:-unknown}). Exiting."
      exit 1
    fi
  else
    log "--configure-only set — skipping package installation."
  fi

  if ((INSTALL_ONLY==0)); then
    blacklist_nouveau
    set_kernel_cmdline_flags
    sign_nvidia_modules_if_needed
    enable_nvidia_services_if_present
  else
    log "--install-only set — skipping system configuration."
  fi

  echo
  echo -e "✅ ${BOLD}Done.${RESET}"
  if sb_enabled && ((NO_SIGN==0)); then
    echo -e "🔁 If you just imported a new MOK, ${BOLD}reboot and select 'Enroll MOK'${RESET} to load signed modules."
  else
    echo -e "🔁 ${BOLD}Reboot${RESET} to start using the NVIDIA driver."
  fi
}

main "$@"
