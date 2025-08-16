#!/usr/bin/env bash
# Team-Nocturnal Universal Gaming Setup
# Focus in this drop: UTF-8 + colored status boxes, single sudo prompt, user-home logging,
# native-first Discord detection with Flatpak fallback. Cross-distro minimal core kept intact.

set -euo pipefail

############################
# Locale & Colors
############################
export LANG=${LANG:-en_US.UTF-8}
export LC_ALL=${LC_ALL:-en_US.UTF-8}

# ANSI colors
RED="\033[31m"; GREEN="\033[32m"; BLUE="\033[34m"; YELLOW="\033[33m"; RESET="\033[0m"; BOLD="\033[1m"

# Colored "checkboxes"
OK="${GREEN}✅${RESET}"        # Installed
ALREADY="${BLUE}☑️${RESET}"    # Already present
ERR="${RED}❌${RESET}"         # Error / Skipped

############################
# Banner
############################
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

############################
# Logging (always to invoking user's home)
############################
init_logging() {
  # Figure out the "real" user home even when script escalates
  if [[ "${SUDO_USER:-}" != "" && "${SUDO_USER}" != "root" ]]; then
    REAL_USER="${SUDO_USER}"
  else
    REAL_USER="${USER}"
  fi

  REAL_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"
  LOG_DIR="${REAL_HOME}/scripts/logs"
  mkdir -p "${LOG_DIR}"
  TS="$(date +%Y%m%d_%H%M%S)"
  LOG_FILE="${LOG_DIR}/gaming_${TS}.log"
  echo -e "Logging to: ${LOG_FILE}"
  # Mirror all subsequent stdout/stderr to log (but keep live output)
  exec > >(tee -a "${LOG_FILE}") 2>&1
}

############################
# Helpers
############################
have() { command -v "$1" >/dev/null 2>&1; }

# One sudo prompt up front; cache credential for the rest
ensure_sudo_once() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Note: Escalating once with sudo to avoid repeated prompts...${RESET}"
    sudo -v
    # keep-alive: refresh sudo timestamp while this script runs
    ( while true; do sleep 45; sudo -n true 2>/dev/null || true; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill ${SUDO_KEEPALIVE_PID} 2>/dev/null || true' EXIT
  fi
}

distro_id() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID}"
  else
    echo "unknown"
  fi
}

pkg_mgr() {
  if have zypper; then echo zypper; return; fi
  if have dnf; then echo dnf; return; fi
  if have apt-get; then echo apt; return; fi
  if have pacman; then echo pacman; return; fi
  echo none
}

# Status book-keeping
declare -A STATUS SYM REASON

set_status() {
  local key="$1" state="$2" why="${3:-}"
  case "$state" in
    installed) SYM["$key"]="${OK}";      STATUS["$key"]="Installed";        REASON["$key"]="$why" ;;
    present)   SYM["$key"]="${ALREADY}"; STATUS["$key"]="Already present";  REASON["$key"]="$why" ;;
    skipped)   SYM["$key"]="${ERR}";     STATUS["$key"]="Skipped";          REASON["$key"]="$why" ;;
    error)     SYM["$key"]="${ERR}";     STATUS["$key"]="Error";            REASON["$key"]="$why" ;;
    *)         SYM["$key"]="${ERR}";     STATUS["$key"]="Unknown";          REASON["$key"]="$why" ;;
  esac
}

print_status_line() {
  local key="$1" label="$2"
  local sym="${SYM[$key]:-${ERR}}"
  local st="${STATUS[$key]:-Unknown}"
  local why="${REASON[$key]:-}"
  if [[ -n "$why" ]]; then
    printf "  %b %s — %s (%s)\n" "${sym}" "${label}" "${st}" "${why}"
  else
    printf "  %b %s — %s\n" "${sym}" "${label}" "${st}"
  fi
}

############################
# Flatpak helpers
############################
ensure_flatpak_user_remote() {
  if ! have flatpak; then
    case "$(pkg_mgr)" in
      zypper)  sudo zypper -n in -y flatpak || true ;;
      dnf)     sudo dnf -y install flatpak || true ;;
      apt)     sudo apt-get update -y || true; sudo apt-get -y install flatpak || true ;;
      pacman)  sudo pacman -Sy --noconfirm flatpak || true ;;
    esac
  fi
  # Add flathub (user scope) if missing
  if ! flatpak remotes --user | grep -q '^flathub'; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi
}

flatpak_present_user() { flatpak info --user "$1" >/dev/null 2>&1; }
flatpak_present_sys()  { flatpak info --system "$1" >/dev/null 2>&1; }

############################
# Native-first Discord detector/installer
############################
install_discord_native_first() {
  local id="discord" label="Discord (native-first)"
  # Detect native first
  if command -v discord >/dev/null 2>&1 || \
     rpm -q discord >/dev/null 2>&1 || \
     dpkg -l discord >/dev/null 2>&1 || \
     pacman -Q discord >/dev/null 2>&1 2>/dev/null; then
    set_status "$id" present "native detected"
    return 0
  fi

  # Try to install native by distro
  case "$(pkg_mgr)" in
    zypper)
      # Tumbleweed: Packman provides discord
      if sudo zypper -n in -y discord; then
        set_status "$id" installed "native via zypper"
        return 0
      fi
      ;;
    dnf)
      # Fedora: RPM Fusion nonfree usually
      if rpm -q discord >/dev/null 2>&1; then
        set_status "$id" present "native (rpm)"
        return 0
      fi
      if sudo dnf -y install discord; then
        set_status "$id" installed "native via dnf"
        return 0
      fi
      ;;
    apt)
      if sudo apt-get update -y && sudo apt-get -y install discord; then
        set_status "$id" installed "native via apt"
        return 0
      fi
      ;;
    pacman)
      if sudo pacman -Sy --noconfirm discord; then
        set_status "$id" installed "native via pacman"
        return 0
      fi
      ;;
  esac

  # Fallback to Flatpak (user)
  ensure_flatpak_user_remote
  if flatpak_present_user com.discordapp.Discord; then
    set_status "$id" present "flatpak (user)"
  elif flatpak install -y --user flathub com.discordapp.Discord; then
    set_status "$id" installed "flatpak (user)"
  else
    set_status "$id" error "native failed; flatpak failed"
    return 1
  fi
}

############################
# Per-distro installers (minimal set shown; keep behavior you had)
############################
install_core_suse() {
  echo -e "${BLUE}==> openSUSE: Ensuring Packman & refreshing repositories${RESET}"
  # add packman if not present
  if ! zypper lr | grep -q '^packman'; then
    sudo zypper -n ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
  fi
  sudo zypper -n ref || true

  echo -e "${BLUE}==> Installing core gaming packages (Steam, Lutris, Wine, Vulkan, etc.)${RESET}"
  sudo zypper -n in -y \
    steam lutris gamescope \
    gamemode libgamemode0 libgamemodeauto0-32bit \
    mangohud mangohud-32bit \
    vulkan-tools vulkan-validationlayers \
    Mesa-libGL1-32bit libvulkan1-32bit || true

  echo -e "${BLUE}==> Installing QoL apps (Discord, OBS, GOverlay native)${RESET}"
  sudo zypper -n in -y obs-studio goverlay vkbasalt Mesa-demo || true
  install_discord_native_first || true

  echo -e "${BLUE}==> Installing Wine + Winetricks${RESET}"
  sudo zypper -n in -y wine wine-32bit winetricks || true

  echo -e "${BLUE}==> Installing Proton tools & Heroic via Flatpak (user scope)${RESET}"
  ensure_flatpak_user_remote
  if flatpak_present_user net.davidotek.pupgui2; then
    set_status pupgui2 present "flatpak user"
  elif flatpak install -y --user flathub net.davidotek.pupgui2; then
    set_status pupgui2 installed "flatpak user"
  else
    set_status pupgui2 error "flatpak failed"
  fi
  if flatpak_present_user com.vysp3r.ProtonPlus; then
    set_status protonplus present "flatpak user"
  elif flatpak install -y --user flathub com.vysp3r.ProtonPlus; then
    set_status protonplus installed "flatpak user"
  else
    set_status protonplus error "flatpak failed"
  fi
  if flatpak_present_user com.heroicgameslauncher.hgl; then
    set_status heroic present "flatpak user"
  elif flatpak install -y --user flathub com.heroicgameslauncher.hgl; then
    set_status heroic installed "flatpak user"
  else
    set_status heroic error "flatpak failed"
  fi

  # Status for native pieces
  command -v steam >/dev/null 2>&1   && set_status steam present ""   || set_status steam skipped "not found"
  command -v lutris >/dev/null 2>&1  && set_status lutris present ""  || set_status lutris skipped "not found"
  command -v gamescope >/dev/null 2>&1 && set_status gamescope present "" || set_status gamescope skipped "not found"
  command -v mangohud >/dev/null 2>&1 && set_status mangohud present "" || set_status mangohud skipped "not found"
  command -v vulkaninfo >/dev/null 2>&1 && set_status vulkaninfo present "" || set_status vulkaninfo skipped "not found"
  command -v gamemoded >/dev/null 2>&1 && set_status gamemoded present "" || set_status gamemoded skipped "not found"
  command -v wine >/dev/null 2>&1 && set_status wine present "" || set_status wine skipped "not found"
  command -v winetricks >/dev/null 2>&1 && set_status winetricks present "" || set_status winetricks skipped "not found"
  command -v obs >/dev/null 2>&1 && set_status obs present "" || set_status obs skipped "not found"
  # discord handled above
  command -v goverlay >/dev/null 2>&1 && set_status goverlay present "" || set_status goverlay skipped "not found"
}

install_core_fedora() {
  echo -e "${BLUE}==> Fedora: Refresh & core packages${RESET}"
  sudo dnf -y makecache || true
  sudo dnf -y install \
    steam lutris gamescope \
    gamemode mangohud \
    vulkan-tools \
    wine winetricks \
    obs-studio goverlay vkbasalt mesa-demos || true

  install_discord_native_first || true

  echo -e "${BLUE}==> Proton tools & Heroic (Flatpak user)${RESET}"
  ensure_flatpak_user_remote
  flatpak_present_user net.davidotek.pupgui2 || flatpak install -y --user flathub net.davidotek.pupgui2 || true
  flatpak_present_user com.vysp3r.ProtonPlus || flatpak install -y --user flathub com.vysp3r.ProtonPlus || true
  flatpak_present_user com.heroicgameslauncher.hgl || flatpak install -y --user flathub com.heroicgameslauncher.hgl || true
}

install_core_ubuntu() {
  echo -e "${BLUE}==> Ubuntu/Debian: Update & core packages${RESET}"
  sudo apt-get update -y || true
  sudo apt-get -y install \
    steam lutris gamescope \
    gamemode libgamemode0 \
    mangohud \
    vulkan-tools \
    wine winetricks \
    obs-studio vkbasalt mesa-utils || true

  install_discord_native_first || true

  echo -e "${BLUE}==> Proton tools & Heroic (Flatpak user)${RESET}"
  ensure_flatpak_user_remote
  flatpak_present_user net.davidotek.pupgui2 || flatpak install -y --user flathub net.davidotek.pupgui2 || true
  flatpak_present_user com.vysp3r.ProtonPlus || flatpak install -y --user flathub com.vysp3r.ProtonPlus || true
  flatpak_present_user com.heroicgameslauncher.hgl || flatpak install -y --user flathub com.heroicgameslauncher.hgl || true
}

install_core_arch() {
  echo -e "${BLUE}==> Arch: Sync & core packages${RESET}"
  sudo pacman -Sy --noconfirm \
    steam lutris gamescope \
    gamemode mangohud \
    vulkan-tools \
    wine winetricks \
    obs-studio vkbasalt mesa-demos || true

  install_discord_native_first || true

  echo -e "${BLUE}==> Proton tools & Heroic (Flatpak user)${RESET}"
  ensure_flatpak_user_remote
  flatpak_present_user net.davidotek.pupgui2 || flatpak install -y --user flathub net.davidotek.pupgui2 || true
  flatpak_present_user com.vysp3r.ProtonPlus || flatpak install -y --user flathub com.vysp3r.ProtonPlus || true
  flatpak_present_user com.heroicgameslauncher.hgl || flatpak install -y --user flathub com.heroicgameslauncher.hgl || true
}

############################
# Summary
############################
print_summary() {
  echo -e "${BLUE}----------------------------------------------------------${RESET}"
  echo -e "${BOLD} Install Status Summary${RESET}"
  echo -e "${BLUE}----------------------------------------------------------${RESET}"
  print_status_line steam       "Steam"
  print_status_line lutris      "Lutris"
  print_status_line gamescope   "Gamescope"
  print_status_line mangohud    "MangoHud"
  print_status_line vulkaninfo  "Vulkan tools"
  print_status_line gamemoded   "GameMode"
  print_status_line wine        "Wine"
  print_status_line winetricks  "Winetricks"
  print_status_line obs         "OBS Studio"
  print_status_line discord     "Discord"
  print_status_line goverlay    "GOverlay (native)"
  print_status_line pupgui2     "ProtonUp-Qt (Flatpak user)"
  print_status_line protonplus  "ProtonPlus (Flatpak user)"
  print_status_line heroic      "Heroic (Flatpak user)"
  echo -e "${BLUE}----------------------------------------------------------${RESET}"
}

############################
# Args
############################
BUNDLE="full"   # kept for compatibility
YES="false"
for arg in "$@"; do
  case "$arg" in
    -y|--assume-yes) YES="true" ;;
    --bundle=*) BUNDLE="${arg#*=}" ;;
  esac
done

############################
# Main
############################
print_banner
init_logging
ensure_sudo_once

ID="$(distro_id)"
case "$ID" in
  opensuse*|suse|tumbleweed) install_core_suse ;;
  fedora)                    install_core_fedora ;;
  ubuntu|debian|linuxmint)   install_core_ubuntu ;;
  arch|endeavouros|manjaro)  install_core_arch ;;
  *)
    echo -e "${YELLOW}Unknown distro ($ID). Attempting best-effort Flatpak installs only.${RESET}"
    ensure_flatpak_user_remote
    flatpak_present_user net.davidotek.pupgui2 || flatpak install -y --user flathub net.davidotek.pupgui2 || true
    flatpak_present_user com.vysp3r.ProtonPlus || flatpak install -y --user flathub com.vysp3r.ProtonPlus || true
    flatpak_present_user com.heroicgameslauncher.hgl || flatpak install -y --user flathub com.heroicgameslauncher.hgl || true
    set_status steam skipped "unknown distro"
    set_status lutris skipped "unknown distro"
    set_status gamescope skipped "unknown distro"
    set_status mangohud skipped "unknown distro"
    set_status vulkaninfo skipped "unknown distro"
    set_status gamemoded skipped "unknown distro"
    set_status wine skipped "unknown distro"
    set_status winetricks skipped "unknown distro"
    set_status obs skipped "unknown distro"
    set_status discord skipped "unknown distro"
    set_status goverlay skipped "unknown distro"
    set_status pupgui2 present "flatpak user (best-effort)"
    set_status protonplus present "flatpak user (best-effort)"
    set_status heroic present "flatpak user (best-effort)"
    ;;
esac

print_summary

echo -e "Tips:"
echo -e " - ProtonUp-Qt: flatpak run net.davidotek.pupgui2"
echo -e " - ProtonPlus : flatpak run com.vysp3r.ProtonPlus"
echo -e " - Heroic     : flatpak run com.heroicgameslauncher.hgl"
