#!/usr/bin/env bash
set -Eeuo pipefail

# ===== Colors =====
RED="\033[31m"; GREEN="\033[32m"; BLUE="\033[34m"; YELLOW="\033[33m"; CYAN="\033[36m"; GRAY="\033[90m"; RESET="\033[0m"; BOLD="\033[1m"

print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal Gaming Setup by XsMagical${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# ===== Helpers =====
have() { command -v "$1" >/dev/null 2>&1; }

# Detect real user to log under (even if run via sudo)
resolve_user_home() {
  if [[ -n "${SUDO_USER-}" && "${SUDO_USER}" != "root" ]]; then
    local u="${SUDO_USER}"
    local h
    h="$(getent passwd "$u" | cut -d: -f6)"
    [[ -z "$h" ]] && h="/home/$u"
    printf '%s\n' "$h"
  else
    printf '%s\n' "${HOME}"
  fi
}

# Sudo upfront (single prompt) + keepalive during run
ensure_sudo_once() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${CYAN}==> Elevation: requesting admin privileges once (sudo -v)...${RESET}"
    sudo -v
    # Keep sudo alive until we finish
    # shellcheck disable=SC2064
    trap 'exit 0' EXIT
    while true; do sudo -n true; sleep 30; kill -0 "$$" 2>/dev/null || exit; done &
  fi
}

# Package manager shorthands (non-interactive where possible)
apt_y() { sudo DEBIAN_FRONTEND=noninteractive apt-get -y "$@"; }
dnf_y() { sudo dnf -y "$@"; }
pac_y() { sudo pacman --noconfirm "$@"; }
zy_n()  { sudo zypper -n "$@"; }

# PackageKit lock helper (openSUSE)
release_pkgkit_lock() {
  if have pkcon; then pkcon quit >/dev/null 2>&1 || true; fi
  sleep 1
}

# Distro detect
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID_LIKE-} ${ID-}" in
      *arch*|*manjaro*|*endeavouros*|*arco*|*archlinux*|*arch*)
        echo "arch"; return;;
    esac
    case "${ID-}" in
      ubuntu|debian|linuxmint|pop) echo "debian"; return;;
      fedora) echo "fedora"; return;;
      opensuse*|sles|sled) echo "suse"; return;;
      arch|manjaro|endeavouros) echo "arch"; return;;
    esac
  fi
  # Fallbacks
  if have zypper; then echo "suse"; return; fi
  if have dnf; then echo "fedora"; return; fi
  if have apt-get; then echo "debian"; return; fi
  if have pacman; then echo "arch"; return; fi
  echo "unknown"
}

# Status recorder
# states: installed, present, skipped, error, unknown
declare -A STATUS MSG SCOPE

mark() { local key="$1" state="$2" msg="${3-}" scope="${4-}"; STATUS["$key"]="$state"; MSG["$key"]="$msg"; SCOPE["$key"]="$scope"; }

# Presence checks
present_bin() { have "$1"; }
present_flatpak() { flatpak info --user "$1" >/dev/null 2>&1 || flatpak info --system "$1" >/dev/null 2>&1; }

# ===== Per-distro installers =====

install_core_suse() {
  release_pkgkit_lock
  # Ensure Packman repo exists (safe if already added)
  zy_n ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
  zy_n ref || true
  zy_n in -l -y \
    steam lutris gamescope \
    mangohud mangohud-32bit \
    gamemode libgamemode0 libgamemodeauto0-32bit \
    vulkan-tools vulkan-validationlayers \
    Mesa-libGL1-32bit libvulkan1-32bit || true
}

install_qol_suse() {
  release_pkgkit_lock
  zy_n in -l -y discord obs-studio goverlay vkbasalt Mesa-demo || true
}

install_wine_suse() {
  release_pkgkit_lock
  zy_n in -l -y wine wine-32bit winetricks || true
}

install_kernel_extras_suse() {
  release_pkgkit_lock
  zy_n in -l -y kernel-default-devel v4l2loopback-kmp-default || true
  if modinfo v4l2loopback >/dev/null 2>&1; then
    sudo modprobe v4l2loopback exclusive_caps=1 max_buffers=2 card_label="Loopback" || true
  fi
}

install_core_fedora() {
  dnf_y install \
    steam lutris gamescope \
    mangohud \
    gamemode \
    vulkan-tools vulkan-validation-layers \
    mesa-libGL.i686 vulkan-loader.i686 || true
}

install_qol_fedora() {
  dnf_y install discord obs-studio vkbasalt || true
  # GOverlay (COPR provides goverlay); if not present, skip silently
  if have dnf && ! have goverlay; then
    dnf_y copr enable atim/goverlay || true
    dnf_y install goverlay || true
  fi
}

install_wine_fedora() {
  dnf_y install wine wine.i686 winetricks || true
}

install_core_debian() {
  apt_y update || true
  apt_y install \
    steam-installer lutris gamescope \
    mangohud \
    gamemode \
    vulkan-tools vulkan-validationlayers \
    libgl1:i386 libvulkan1:i386 || true
}

install_qol_debian() {
  # discord/obs may be from third-party; if not available skip
  apt_y install obs-studio || true
  # Discord often via flatpak; mark later
}

install_wine_debian() {
  dpkg --add-architecture i386 || true
  apt_y update || true
  apt_y install wine wine32 winetricks || true
}

install_core_arch() {
  pac_y -Syu || true
  pac_y -S \
    steam lutris gamescope \
    mangohud \
    gamemode \
    vulkan-tools vulkan-validation-layers || true
  # multilib for i386 GL/Vulkan is system-level; assume enabled
}

install_qol_arch() {
  pac_y -S obs-studio vkbasalt || true
  # Discord from repo is 'discord' (requires log in to AUR in some editions). Try, ignore failure.
  pac_y -S discord || true
  # GOverlay is 'goverlay' in community/extra
  pac_y -S goverlay || true
}

install_wine_arch() {
  pac_y -S wine winetricks || true
}

# Flatpak apps (user scope)
install_flatpaks_user() {
  if ! have flatpak; then
    case "$DISTRO" in
      suse) zy_n in -y flatpak || true ;;
      fedora) dnf_y install flatpak || true ;;
      debian) apt_y install flatpak || true ;;
      arch) pac_y -S flatpak || true ;;
    esac
  fi

  # Ensure user flathub remote
  if ! flatpak remotes --user | grep -q "^flathub"; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi

  # ProtonUp-Qt
  if flatpak info --user net.davidotek.pupgui2 >/dev/null 2>&1; then
    mark "protonupqt" "present" "Flatpak (user)" "user"
  else
    if flatpak install -y --user flathub net.davidotek.pupgui2; then
      mark "protonupqt" "installed" "Flatpak (user)" "user"
    else
      mark "protonupqt" "error" "Flatpak install failed" "user"
    fi
  fi

  # ProtonPlus
  if flatpak info --user com.vysp3r.ProtonPlus >/dev/null 2>&1; then
    mark "protonplus" "present" "Flatpak (user)" "user"
  else
    if flatpak install -y --user flathub com.vysp3r.ProtonPlus; then
      mark "protonplus" "installed" "Flatpak (user)" "user"
    else
      mark "protonplus" "error" "Flatpak install failed" "user"
    fi
  fi

  # Heroic
  if flatpak info --user com.heroicgameslauncher.hgl >/dev/null 2>&1; then
    mark "heroic" "present" "Flatpak (user)" "user"
  else
    if flatpak install -y --user flathub com.heroicgameslauncher.hgl; then
      mark "heroic" "installed" "Flatpak (user)" "user"
    else
      mark "heroic" "error" "Flatpak install failed" "user"
    fi
  fi
}

# ===== Main =====

# Parse Args
BUNDLE="full"; OVERLAYS="none"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle=*) BUNDLE="${1#*=}"; shift ;;
    --overlays=*) OVERLAYS="${1#*=}"; shift ;;
    -y|--yes) export ASSUME_YES=1; shift ;;
    *) echo "Unknown arg: $1"; shift ;;
  esac
done

# Setup logging (always under invoking user's home)
USER_HOME="$(resolve_user_home)"
LOG_DIR="${USER_HOME}/scripts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/gaming_$(date +%Y%m%d_%H%M%S).log"

# Begin tee
# shellcheck disable=SC2094
exec > >(tee -a "$LOG_FILE") 2>&1

print_banner
echo -e "${GRAY}Logging to: ${LOG_FILE}${RESET}"

# Sudo once
ensure_sudo_once

# Detect distro
DISTRO="$(detect_distro)"
echo -e "${CYAN}==> Distro detection: ${DISTRO}${RESET}"

# Core/native installs
case "$DISTRO" in
  suse)
    echo -e "${BLUE}==> openSUSE: Ensuring Packman & refreshing repositories${RESET}"
    install_core_suse
    echo -e "${BLUE}==> Installing QoL apps (Discord, OBS, GOverlay native)${RESET}"
    install_qol_suse
    echo -e "${BLUE}==> Installing Wine + Winetricks${RESET}"
    install_wine_suse
    echo -e "${BLUE}==> Installing optional kernel extras (v4l2loopback KMP)${RESET}"
    install_kernel_extras_suse
    ;;
  fedora)
    echo -e "${BLUE}==> Fedora: Installing core packages${RESET}"
    install_core_fedora
    echo -e "${BLUE}==> Fedora: QoL apps${RESET}"
    install_qol_fedora
    echo -e "${BLUE}==> Fedora: Wine + Winetricks${RESET}"
    install_wine_fedora
    ;;
  debian)
    echo -e "${BLUE}==> Debian/Ubuntu: Installing core packages${RESET}"
    install_core_debian
    echo -e "${BLUE}==> Debian/Ubuntu: QoL apps${RESET}"
    install_qol_debian
    echo -e "${BLUE}==> Debian/Ubuntu: Wine + Winetricks${RESET}"
    install_wine_debian
    ;;
  arch)
    echo -e "${BLUE}==> Arch: Installing core packages${RESET}"
    install_core_arch
    echo -e "${BLUE}==> Arch: QoL apps${RESET}"
    install_qol_arch
    echo -e "${BLUE}==> Arch: Wine + Winetricks${RESET}"
    install_wine_arch
    ;;
  *)
    echo -e "${YELLOW}Unknown distro. Skipping native package installs.${RESET}"
    ;;
esac

# Flatpaks (user scope)
echo -e "${BLUE}==> Installing Proton tools & Heroic via Flatpak (user scope)${RESET}"
install_flatpaks_user

echo -e "${BLUE}==> Overlays: ${OVERLAYS}${RESET}"

# ===== Status detection for summary =====
# native
present_bin steam        && mark steam        present "" "" || mark steam        unknown ""
present_bin lutris       && mark lutris       present "" "" || mark lutris       unknown ""
present_bin gamescope    && mark gamescope    present "" "" || mark gamescope    unknown ""
present_bin mangohud     && mark mangohud     present "" "" || mark mangohud     unknown ""
present_bin vulkaninfo   && mark vulkaninfo   present "" "" || mark vulkaninfo   unknown ""
present_bin gamemoded    && mark gamemoded    present "" "" || mark gamemoded    unknown ""
present_bin wine         && mark wine         present "" "" || mark wine         unknown ""
present_bin winetricks   && mark winetricks   present "" "" || mark winetricks   unknown ""
present_bin obs          && mark obs          present "" "" || mark obs          unknown ""
present_bin discord      && mark discord      present "" "" || mark discord      unknown ""
present_bin goverlay     && mark goverlay     present "" "" || mark goverlay     unknown ""

# v4l2loopback status
if lsmod | grep -q "^v4l2loopback"; then
  mark v4l2loopback present "Loaded" ""
elif modinfo v4l2loopback >/dev/null 2>&1; then
  mark v4l2loopback present "Installed (module available)" ""
else
  mark v4l2loopback unknown ""
fi

# ===== Summary =====
echo -e "${BLUE}----------------------------------------------------------${RESET}"
echo -e "${BOLD} Install Status Summary${RESET}"
echo -e "${BLUE}----------------------------------------------------------${RESET}"

# Glyphs
GL_OK="${GREEN}✔${RESET}"
GL_PRESENT="${CYAN}▮${RESET}"
GL_SKIP="${YELLOW}●${RESET}"
GL_ERR="${RED}✖${RESET}"
GL_UNK="${GRAY}▯${RESET}"

print_line () {
  local key="$1" label="$2"
  local st="${STATUS[$key]:-unknown}"
  local msg="${MSG[$key]:-}"
  local sc="${SCOPE[$key]:-}"
  local icon desc scope_txt
  case "$st" in
    installed) icon="$GL_OK"; desc="Installed";;
    present)   icon="$GL_PRESENT"; desc="Already present";;
    skipped)   icon="$GL_SKIP"; desc="Skipped";;
    error)     icon="$GL_ERR"; desc="Error";;
    *)         icon="$GL_UNK"; desc="Unknown";;
  esac
  [[ -n "$msg" ]] && desc="$desc — $msg"
  [[ -n "$sc" ]] && scope_txt=" (${sc})" || scope_txt=""
  printf " %b %-12s: %s%s\n" "$icon" "$label" "$desc" "$scope_txt"
}

print_line steam        "steam"
print_line lutris       "lutris"
print_line gamescope    "gamescope"
print_line mangohud     "mangohud"
print_line vulkaninfo   "vulkaninfo"
print_line gamemoded    "gamemoded"
print_line wine         "wine"
print_line winetricks   "winetricks"
print_line obs          "obs"
print_line discord      "discord"
print_line protonupqt   "ProtonUp-Qt"
print_line protonplus   "ProtonPlus"
print_line heroic       "Heroic"
print_line goverlay     "GOverlay"
print_line v4l2loopback "v4l2loopback"

echo -e "${BLUE}----------------------------------------------------------${RESET}"
echo -e "Tips:"
echo -e "- ProtonUp-Qt: flatpak run net.davidotek.pupgui2"
echo -e "- ProtonPlus : flatpak run com.vysp3r.ProtonPlus"
echo -e "- Heroic     : flatpak run com.heroicgameslauncher.hgl"
echo -e "${GRAY}Log saved to: ${LOG_FILE}${RESET}"
echo "Done."
