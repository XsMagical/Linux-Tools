#!/usr/bin/env bash
# tn_xs_post_install.sh

# ===== Colors =====
RED="\033[31m"; BLUE="\033[34m"; RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
GREEN="\033[32m"; YELLOW="\033[33m"

print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal Post-Install Script by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# ================== Script Settings ==================
set +e
trap 'echo "Error on line $LINENO"' ERR

START_TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="${HOME}/scripts/logs"
LOG_FILE="${LOG_DIR}/post_install_${START_TS}.log"
mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

# ================== Globals / CLI ==================
ASSUME_YES=0
VERBOSE=0
PRESET=""

checkmark(){ printf "%b\n" "${GREEN}✅${RESET} $*"; }
crossmark(){  printf "%b\n" "${RED}❌${RESET} $*"; }
warn(){       printf "%b\n" "${YELLOW}⚠${RESET}  $*"; }
info(){       printf "%b\n" "${BLUE}ℹ${RESET}  $*"; }
step(){       printf "%b\n" "${BOLD}${BLUE}==>${RESET} $*"; }

usage() {
  cat <<EOF2
Usage: $(basename "$0") [options] <preset>

Presets:
  gaming   - Run universal gaming setup (fetches from GitHub if missing)
  media    - Install VLC, MPV, Celluloid, FFmpeg, HandBrake, GStreamer codecs
  general  - Common CLI tools/utilities
  lite     - Minimal essentials
  full     - general + media + dev/virtualization stack

Options:
  -y, --assume-yes   Auto-confirm installs
      --verbose      Extra status output
  -h, --help         Show this help

Examples:
  $(basename "$0") --verbose -y full
  $(basename "$0") media
EOF2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--assume-yes) ASSUME_YES=1; shift ;;
    --verbose)       VERBOSE=1; shift ;;
    -h|--help)       usage; exit 0 ;;
    gaming|media|general|lite|full) PRESET="$1"; shift ;;
    *) warn "Unknown argument: $1"; shift ;;
  esac
done

if [[ -z "${PRESET}" ]]; then usage; exit 1; fi

print_banner
step "Log: ${LOG_FILE}"

# ================== Privileges ==================
if [[ $EUID -ne 0 ]]; then SUDO="sudo"; else SUDO=""; fi

# Pre-auth sudo once (avoids mid-run password prompts)
if [[ -n "$SUDO" ]]; then $SUDO -v || true; fi

# ================== Distro Detect ==================
DISTRO="unknown"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*|*centos*) DISTRO="fedora" ;;
    *debian*|*ubuntu*)        DISTRO="debian" ;;
    *arch*)                   DISTRO="arch" ;;
    *suse*)                   DISTRO="opensuse" ;;
    *) DISTRO="${ID:-unknown}";;
  esac
fi
info "Detected distro: ${DISTRO}"

# ================== Package Manager Abstractions ==================
DNF_FLAGS=(--best --allowerasing --skip-broken)

pm_refresh() {
  case "$DISTRO" in
    fedora)   ${SUDO} sh -c 'command -v dnf5 &>/dev/null && dnf5 -q makecache || dnf -q makecache' || true ;;
    debian)   ${SUDO} apt-get update -y || true ;;
    arch)     ${SUDO} pacman -Sy --noconfirm || true ;;
    opensuse) ${SUDO} zypper --non-interactive refresh || true ;;
    *) true ;;
  esac
}

pm_install() {
  local pkgs=("$@"); [[ ${#pkgs[@]} -eq 0 ]] && return 0
  case "$DISTRO" in
    fedora)
      local args=(); [[ $ASSUME_YES -eq 1 ]] && args+=(-y)
      if command -v dnf5 &>/dev/null; then
        ${SUDO} dnf5 install "${DNF_FLAGS[@]}" "${args[@]}" "${pkgs[@]}" || true
      else
        ${SUDO} dnf  install "${DNF_FLAGS[@]}" "${args[@]}" "${pkgs[@]}" || true
      fi
      ;;
    debian)
      local args=(); [[ $ASSUME_YES -eq 1 ]] && args+=(-y)
      ${SUDO} apt-get install "${args[@]}" "${pkgs[@]}" || true
      ;;
    arch)
      local args=(--needed); [[ $ASSUME_YES -eq 1 ]] && args+=(--noconfirm)
      ${SUDO} pacman -S "${args[@]}" "${pkgs[@]}" || true
      ;;
    opensuse)
      local args=(--non-interactive); [[ $ASSUME_YES -eq 1 ]] && args+=(-y)
      ${SUDO} zypper "${args[@]}" install "${pkgs[@]}" || true
      ;;
    *)
      warn "Unsupported distro for package install. Skipping: ${pkgs[*]}";;
  esac
}

pkg_installed() {
  local pkg="${1:-}"
  case "$DISTRO" in
    fedora)
      rpm -q "$pkg" &>/dev/null || \
      { command -v dnf5 &>/dev/null && dnf5 -q list installed "$pkg" &>/dev/null; } || \
      { command -v dnf  &>/dev/null && dnf  -q list installed "$pkg" &>/dev/null; }
      ;;
    debian)   dpkg -s "$pkg" &>/dev/null ;;
    arch)     pacman -Qi "$pkg" &>/dev/null ;;
    opensuse) rpm -q "$pkg" &>/dev/null ;;
    *) return 1 ;;
  esac
}

# ================== Repo Helpers (Fedora) ==================
enable_rpmfusion() {
  [[ "$DISTRO" != "fedora" ]] && return 0
  step "Ensuring RPM Fusion (free & nonfree) is enabled"
  local rel; rel="$(rpm -E %fedora 2>/dev/null)"
  pm_install "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${rel}.noarch.rpm"
  pm_install "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${rel}.noarch.rpm"
  checkmark "RPM Fusion ensured"
}

# ================== Package Lists ==================
add_general_packages() {
  case "$DISTRO" in
    fedora) PKGS+=(
      curl wget git vim nano htop unzip zip tar rsync jq ripgrep fzf tree fastfetch
      util-linux-user net-tools iproute bind-utils bc dnf-plugins-core
    ) ;;
    debian) PKGS+=(
      curl wget git vim nano htop unzip zip tar rsync jq ripgrep fzf tree fastfetch
      net-tools iproute2 dnsutils bc
    ) ;;
    arch) PKGS+=(
      curl wget git vim nano htop unzip zip tar rsync jq ripgrep fzf tree fastfetch
      net-tools iproute2 bind bc
    ) ;;
    opensuse) PKGS+=(
      curl wget git vim nano htop unzip zip tar rsync jq ripgrep fzf tree fastfetch
      net-tools iproute2 bind-utils bc
    ) ;;
  esac
}

add_lite_packages() { PKGS+=(curl wget git vim htop unzip); }

add_media_packages() {
  case "$DISTRO" in
    fedora)
      PKGS+=( vlc mpv celluloid ffmpeg HandBrake-gui HandBrake-cli
              gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugins-ugly
              gstreamer1-plugins-bad-freeworld gstreamer1-libav )
      ;;
    debian)
      PKGS+=( vlc mpv celluloid ffmpeg handbrake
              gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
              gstreamer1.0-plugins-ugly gstreamer1.0-libav libavcodec-extra )
      ;;
    arch)
      PKGS+=( vlc mpv celluloid ffmpeg handbrake
              gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav )
      ;;
    opensuse)
      PKGS+=( vlc mpv celluloid ffmpeg HandBrake
              gstreamer-plugins-base gstreamer-plugins-good gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-libav )
      ;;
  esac
}

add_devvirt_packages() {
  case "$DISTRO" in
    fedora)   PKGS+=( gcc make cmake clang pkgconf kernel-headers kernel-devel qemu-kvm libvirt virt-install virt-manager edk2-ovmf ) ;;
    debian)   PKGS+=( build-essential "linux-headers-$(uname -r)" qemu-kvm libvirt-daemon-system libvirt-clients virtinst virt-manager ovmf ) ;;
    arch)     PKGS+=( base-devel clang cmake qemu libvirt virt-manager edk2-ovmf ) ;;
    opensuse) PKGS+=( gcc make cmake clang kernel-default-devel qemu-x86 libvirt virt-install virt-manager ovmf ) ;;
  esac
}

# ================== Gaming Preset ==================
run_gaming_preset() {
  step "Gaming preset selected"
  local local_script="${HOME}/scripts/universal_gaming_setup.sh"
  if [[ ! -x "$local_script" ]]; then
    info "Fetching universal_gaming_setup.sh from GitHub (raw)"
    mkdir -p "${HOME}/scripts" || true
    curl -fsSL "https://raw.githubusercontent.com/XsMagical/Linux-Tools/main/scripts/gaming/universal_gaming_setup.sh" -o "$local_script" || true
    chmod +x "$local_script" || true
  fi

  if [[ -x "$local_script" ]]; then
    # IMPORTANT: run via sudo; do NOT pass -y/--verbose (gaming script doesn't accept them and uses runuser)
    ${SUDO:-sudo} "$local_script"
    rc=$?
    if (( rc != 0 )); then
      warn "Gaming script returned ${rc}"
    fi
    checkmark "Gaming preset completed (see above for details)"
  else
    crossmark "Could not obtain universal_gaming_setup.sh"
  fi
}
# ================== Preset Runners ==================
run_media_preset()   { PKGS=(); add_media_packages;   pm_refresh; pm_install "${PKGS[@]}"; checkmark "Media tools attempted"; }
run_general_preset() { PKGS=(); add_general_packages; pm_refresh; pm_install "${PKGS[@]}"; checkmark "General tools attempted"; }
run_lite_preset()    { PKGS=(); add_lite_packages;    pm_refresh; pm_install "${PKGS[@]}"; checkmark "Lite essentials attempted"; }

run_full_preset() {
  run_general_preset
  run_media_preset
  PKGS=(); add_devvirt_packages; pm_refresh; pm_install "${PKGS[@]}"

  # Libvirt/Virt-Manager post-setup (Fedora/RHEL & friends)
  # Keep going even if any unit isn't present (|| true).
  step "Configuring libvirt (sockets, groups, default network)"
  ${SUDO} systemctl enable --now virtqemud.socket virtqemud-ro.socket virtqemud-admin.socket || true
  ${SUDO} systemctl enable --now virtlogd.socket virtlockd.socket || true
  ${SUDO} systemctl enable --now libvirtd || true

  # Allow current user to manage VMs (re-login required to take effect)
  ${SUDO} usermod -aG libvirt "$USER" || true
  ${SUDO} usermod -aG kvm "$USER" || true

  # Ensure the default NAT network exists and autostarts
  ${SUDO} virsh net-autostart default 2>/dev/null || true
  ${SUDO} virsh net-start default 2>/dev/null || true

  checkmark "Dev/Virtualization stack attempted"
}


# ================== Pre-flight (Fedora) ==================
[[ "$DISTRO" == "fedora" ]] && enable_rpmfusion

# ================== Execute Selected Preset ==================
case "$PRESET" in
  gaming)  run_gaming_preset ;;
  media)   run_media_preset ;;
  general) run_general_preset ;;
  lite)    run_lite_preset ;;
  full)    run_full_preset ;;
esac

echo
checkmark "Post-install complete. Log: ${LOG_FILE}"
