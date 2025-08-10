#!/usr/bin/env bash
set -euo pipefail

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
  printf '%b\n' "${BLUE} Team-Nocturnal.com Universal Post-Install Script by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# ---------- Config ----------
GAMING_SCRIPT_URL="https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh"
LOG_DIR="${HOME}/scripts/logs"
LOG_FILE="${LOG_DIR}/post_install_$(date +%Y%m%d_%H%M%S).log"

ASSUME_YES=false
NO_FLATPAK=false
DRY_RUN=false
INSTALL_CHROME=${INSTALL_CHROME:-1}

# ---------- Helpers ----------
log()  { printf "%b\n" "$1" | tee -a "$LOG_FILE"; }
die()  { printf "%b\n" "${RED}Error:${RESET} $*" | tee -a "$LOG_FILE"; exit 1; }
run()  { if $DRY_RUN; then printf "%b\n" "${DIM}[dry-run]${RESET} $*" | tee -a "$LOG_FILE"; else eval "$@" |& tee -a "$LOG_FILE"; fi; }
need_sudo() { [[ $EUID -ne 0 ]] && SUDO="sudo" || SUDO=""; }

detect_distro() {
  [[ -f /etc/os-release ]] || die "/etc/os-release not found"
  . /etc/os-release
  ID_LIKE="${ID_LIKE:-}"
  case "$ID" in
    fedora) DISTRO="fedora" ;;
    rhel|centos|rocky|almalinux) DISTRO="rhel" ;;
    ubuntu|debian|linuxmint|pop) DISTRO="debian" ;;
    arch|endeavouros|manjaro|arcolinux) DISTRO="arch" ;;
    opensuse*|sles|sle*) DISTRO="opensuse" ;;
    *) 
      if [[ "$ID_LIKE" == *fedora* ]]; then DISTRO="fedora"
      elif [[ "$ID_LIKE" == *rhel* ]]; then DISTRO="rhel"
      elif [[ "$ID_LIKE" == *debian* || "$ID_LIKE" == *ubuntu* ]]; then DISTRO="debian"
      elif [[ "$ID_LIKE" == *arch* ]]; then DISTRO="arch"
      elif [[ "$ID_LIKE" == *suse* ]]; then DISTRO="opensuse"
      else DISTRO="unknown"
      fi
      ;;
  esac
  [[ "$DISTRO" == "unknown" ]] && die "Unsupported or unknown distro."
}

pkg_installed() {
  local pkg="$1"
  case "$DISTRO" in
    fedora|rhel|opensuse) rpm -q "$pkg" &>/dev/null ;;
    debian) dpkg -s "$pkg" &>/dev/null ;;
    arch) pacman -Qi "$pkg" &>/dev/null ;;
  esac
}

ensure_pkgs() {
  local to_install=()
  for pkg in "$@"; do
    [[ -z "$pkg" ]] && continue
    if pkg_installed "$pkg"; then
      log "${DIM}✓ $pkg already installed${RESET}"
    else
      to_install+=("$pkg")
    fi
  done
  [[ ${#to_install[@]} -eq 0 ]] && return 0
  case "$DISTRO" in
    fedora|rhel)
      local y; $ASSUME_YES && y="-y" || y=""
      run $SUDO dnf install $y --skip-broken --best --allowerasing "${to_install[@]}"
      ;;
    debian)
      local y; $ASSUME_YES && y="-y" || y=""
      run $SUDO apt-get update
      run $SUDO apt-get install $y "${to_install[@]}"
      ;;
    arch)
      local y; $ASSUME_YES && y="--noconfirm" || y=""
      run $SUDO pacman -Syu $y --needed "${to_install[@]}"
      ;;
    opensuse)
      local y; $ASSUME_YES && y="-y" || y=""
      run $SUDO zypper refresh
      run $SUDO zypper install $y --no-recommends "${to_install[@]}"
      ;;
  esac
}

ensure_base_tools() {
  log "${BOLD}=> Ensuring base CLI/tools for this script...${RESET}"
  case "$DISTRO" in
    fedora)    ensure_pkgs curl wget git ca-certificates gnupg unzip p7zip p7zip-plugins dnf-plugins-core ;;
    rhel)      ensure_pkgs curl wget git ca-certificates gnupg2 unzip p7zip p7zip-plugins dnf-plugins-core epel-release ;;
    debian)    ensure_pkgs curl wget git ca-certificates gnupg unzip p7zip-full software-properties-common ;;
    arch)      ensure_pkgs curl wget git ca-certificates gnupg unzip p7zip pacman-contrib ;;
    opensuse)  ensure_pkgs curl wget git ca-certificates gpg2 unzip p7zip ;;
  esac
}

enable_repos_and_basics() {
  case "$DISTRO" in
    fedora)
      local y; $ASSUME_YES && y="-y" || y=""
      log "${BOLD}=> Enabling RPM Fusion...${RESET}"
      rpm -q rpmfusion-free-release &>/dev/null || run $SUDO dnf install $y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
      rpm -q rpmfusion-nonfree-release &>/dev/null || run $SUDO dnf install $y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
      run $SUDO dnf groupupdate $y core || true
      ;;
    rhel)
      log "${BOLD}=> RHEL-like: ensure EPEL/RPM Fusion manually if needed.${RESET}"
      ;;
    debian)
      log "${BOLD}=> Enabling contrib/non-free and updating...${RESET}"
      $DRY_RUN || {
        $SUDO apt-get update || true
        add-apt-repository -y universe 2>/dev/null || true
        sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list || true
        $SUDO apt-get update || true
      }
      ;;
    arch)
      log "${BOLD}=> Arch: consider enabling multilib manually.${RESET}"
      ;;
    opensuse)
      local y; $ASSUME_YES && y="-y" || y=""
      if ! zypper lr | grep -qi packman; then
        run $SUDO zypper ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
        run $SUDO zypper refresh || true
      fi
      ;;
  esac

  if ! $NO_FLATPAK; then
    log "${BOLD}=> Ensuring Flatpak & Flathub...${RESET}"
    ensure_pkgs flatpak || true
    $DRY_RUN || {
      flatpak remotes | grep -q '^flathub' || flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    }
  fi
}

install_codecs_and_media_stack() {
  log "${BOLD}=> Installing media stack & codecs...${RESET}"
  case "$DISTRO" in
    fedora|rhel)
      local y; $ASSUME_YES && y="-y" || y=""
      run $SUDO dnf groupupdate $y multimedia --setop="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin || true
      run $SUDO dnf groupupdate $y sound-and-video || true
      ensure_pkgs vlc mpv celluloid ffmpeg handbrake
      ;;
    debian)    ensure_pkgs vlc mpv ffmpeg handbrake handbrake-cli ;;
    arch)      ensure_pkgs vlc mpv ffmpeg handbrake ;;
    opensuse)  ensure_pkgs vlc mpv ffmpeg-5 gstreamer-plugins-bad gstreamer-plugins-ugly handbrake ;;
  esac
}

install_general_stack() {
  log "${BOLD}=> Installing general tools...${RESET}"
  case "$DISTRO" in
    fedora|rhel) ensure_pkgs git curl wget unzip p7zip p7zip-plugins htop btop fastfetch gparted lm_sensors nvtop btrfs-progs util-linux-user tar jq fzf ripgrep ;;
    debian)      ensure_pkgs git curl wget unzip p7zip-full htop btop fastfetch gparted lm-sensors nvtop btrfs-progs jq fzf ripgrep ;;
    arch)        ensure_pkgs git curl wget unzip p7zip htop btop fastfetch gparted lm_sensors nvtop btrfs-progs jq fzf ripgrep ;;
    opensuse)    ensure_pkgs git curl wget unzip p7zip htop btop fastfetch gparted lm_sensors nvtop btrfsprogs jq fzf ripgrep ;;
  esac
}

install_dev_and_full_tools() {
  log "${BOLD}=> Installing developer & power-user tools...${RESET}"
  case "$DISTRO" in
    fedora|rhel) ensure_pkgs gcc gcc-c++ make cmake ninja-build kernel-headers kernel-devel podman podman-compose distrobox toolbox virt-install virt-manager qemu-kvm libvirt-daemon-config-network flatpak-builder python3-pip ;;
    debian)      ensure_pkgs build-essential cmake ninja-build "linux-headers-$(uname -r)" podman podman-compose distrobox virt-manager qemu-system qemu-kvm libvirt-daemon-system flatpak-builder python3-pip || true ;;
    arch)        ensure_pkgs base-devel cmake ninja linux-headers podman podman-compose distrobox virt-manager qemu libvirt dnsmasq iptables-nft flatpak-builder python-pip ;;
    opensuse)    ensure_pkgs gcc gcc-c++ make cmake ninja libvirt qemu-kvm virt-manager podman podman-compose distrobox flatpak-builder python311-pip ;;
  esac
}

install_lite_stack() {
  log "${BOLD}=> Installing lite essentials...${RESET}"
  ensure_pkgs git curl wget unzip htop fastfetch
}

run_gaming_chain() {
  log "${BOLD}=> Running gaming setup from repo...${RESET}"
  local gscript="${HOME}/scripts/universal_gaming_setup.sh"
  [[ -f "$gscript" ]] || { log "Downloading gaming script..."; run curl -fsSL "$GAMING_SCRIPT_URL" -o "$gscript"; run chmod +x "$gscript"; }
  local fwd=""
  $ASSUME_YES && fwd="${fwd} --yes"
  $NO_FLATPAK && fwd="${fwd} --no-flatpak"
  $DRY_RUN || run "$gscript" $fwd
}

usage() {
cat <<USAGE
Usage: $(basename "$0") [options] <preset>

Presets:
  gaming   - Chain to repo gaming script
  media    - Media players, codecs, ffmpeg/HandBrake, etc.
  general  - Common CLI tools, sensors, utilities
  lite     - Minimal essentials
  full     - General + Media + Dev/Virtualization

Options:
  -y, --yes        Assume yes / non-interactive
      --no-flatpak Skip Flatpak/Flathub setup
      --dry-run    Show actions without executing
  -h, --help       Show help
USAGE
}

# ---------- Arg parsing ----------
PRESET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    gaming|media|general|lite|full) PRESET="$1"; shift ;;
    -y|--yes) ASSUME_YES=true; shift ;;
    --no-flatpak) NO_FLATPAK=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)";;
  esac
done
[[ -z "${PRESET}" ]] && usage && exit 1

# ---------- Main ----------
mkdir -p "$LOG_DIR"
print_banner
log "Log: $LOG_FILE"
need_sudo
detect_distro
ensure_base_tools
log "Detected distro: ${BOLD}${DISTRO}${RESET}"
enable_repos_and_basics

case "$PRESET" in
  gaming)  run_gaming_chain ;;
  media)   install_codecs_and_media_stack ;;
  general) install_general_stack ;;
  lite)    install_lite_stack ;;
  full)    install_general_stack; install_codecs_and_media_stack; install_dev_and_full_tools ;;
esac

log "${BOLD}✅ Done.${RESET}"
