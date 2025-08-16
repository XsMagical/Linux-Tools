#!/usr/bin/env bash
# Universal Gaming Setup - Team-Nocturnal.com
# Cross-distro installer for Steam/Wine/Proton tools & QoL apps
# - Prompts for sudo ONCE and keeps it alive
# - Logs to invoking user's ~/scripts/logs regardless of sudo
# - Prefers native Discord, falls back to Flatpak (user)
# - Prints INLINE status with reasons for EVERY app (✅ Installed / 🟦 Already present / ❌ Skipped|Error)

set -euo pipefail

# ===== Colors & Symbols =====
RED="\033[31m"; BLUE="\033[34m"; RESET="\033[0m"
BOLD="\033[1m"; DIM="\033[2m"

INST_SYM="✅"      # Installed
PRESENT_SYM="🟦"   # Already present (blue checkbox look)
BAD_SYM="❌"       # Skipped/Error

# ===== Banner =====
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

# ===== Arg parsing =====
BUNDLE="full"
YES="false"
AGREE_PK="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle=*) BUNDLE="${1#*=}"; shift;;
    -y|--yes) YES="true"; shift;;
    --agree-pk) AGREE_PK="true"; shift;;
    *) echo "Unknown option: $1"; shift;;
  esac
done

# ===== Determine real user & user-scoped logging =====
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6 || echo "$HOME")"
LOG_DIR="${REAL_HOME}/scripts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/gaming_$(date +%Y%m%d_%H%M%S).log"

# Start logging (console + file)
echo "Logging to: ${LOG_FILE}" | tee -a "$LOG_FILE" >/dev/null
exec > >(tee -a "$LOG_FILE") 2>&1

# ===== Helpers =====
have() { command -v "$1" >/dev/null 2>&1; }

release_pkgkit_lock() {
  if have pkcon; then pkcon quit >/dev/null 2>&1 || true; fi
  sleep 1
}

require_sudo_once() {
  if ! sudo -n true 2>/dev/null; then
    echo "Requesting sudo to continue (one-time)..."
    sudo -v || { echo "ERROR: sudo authentication failed."; exit 1; }
  fi
  ( while true; do sleep 60; sudo -n true || exit; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT
}

pkg_id="unknown"
detect_pkg() {
  if have zypper; then pkg_id="zypper"; return; fi
  if have dnf; then pkg_id="dnf"; return; fi
  if have apt-get; then pkg_id="apt"; return; fi
  if have pacman; then pkg_id="pacman"; return; fi
  pkg_id="none"
}

pkg_install() {
  local packages=("$@")
  case "$pkg_id" in
    zypper)
      export ZYPP_LOCK_TIMEOUT=30
      [[ "$AGREE_PK" == "true" ]] && release_pkgkit_lock
      sudo zypper -n ref || true
      sudo zypper -n in -l "${packages[@]}"
      ;;
    dnf)
      sudo dnf -y install "${packages[@]}"
      ;;
    apt)
      sudo apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
      ;;
    pacman)
      sudo pacman -Sy --needed --noconfirm "${packages[@]}"
      ;;
    *)
      return 1
      ;;
  esac
}

# Status map + printer
declare -A STATUS_TEXT
declare -A STATUS_SYM

set_status() { # name, sym, text-reason
  local name="$1" sym="$2" msg="$3"
  STATUS_TEXT["$name"]="$msg"
  STATUS_SYM["$name"]="$sym"
  printf " %b %s — %s\n" "$sym" "$name" "$msg"
}

mark_installed()      { set_status "$1" "$INST_SYM"    "Installed ($2)"; }
mark_present()        { set_status "$1" "$PRESENT_SYM" "Already present ($2)"; }
mark_skipped()        { set_status "$1" "$BAD_SYM"     "Skipped ($2)"; }
mark_error()          { set_status "$1" "$BAD_SYM"     "Error ($2)"; }

# ===== Discord (native preferred, Flatpak fallback) =====
install_discord() {
  local name="Discord"
  if have discord; then
    mark_present "$name" "native detected in PATH"
    return
  fi

  # package name differs sometimes; try best-known name "discord"
  if pkg_install discord 2>/dev/null; then
    if have discord; then
      mark_installed "$name" "native via ${pkg_id}"
      return
    fi
  fi

  # Fallback to Flatpak (user)
  if ! have flatpak; then pkg_install flatpak || true; fi
  if ! flatpak remotes --user | grep -q '^flathub'; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi
  if flatpak info --user com.discordapp.Discord >/dev/null 2>&1 || \
     flatpak install -y --user flathub com.discordapp.Discord; then
    mark_installed "$name" "flatpak:user com.discordapp.Discord"
  else
    mark_error "$name" "native missing and flatpak install failed"
  fi
}

# ===== Core groups =====
install_core() {
  echo -e "${BLUE}==> Installing core gaming packages (Steam, Lutris, Wine, Vulkan, etc.)${RESET}"
  case "$pkg_id" in
    zypper)
      export ZYPP_LOCK_TIMEOUT=30
      [[ "$AGREE_PK" == "true" ]] && release_pkgkit_lock
      sudo zypper -n ref || true
      sudo zypper -n in -l \
        steam lutris gamescope \
        Mesa-libGL1-32bit libvulkan1-32bit vulkan-tools vulkan-validationlayers \
        gamemode libgamemode0 libgamemodeauto0-32bit \
        mangohud mangohud-32bit || true
      ;;
    dnf)
      sudo dnf -y install \
        steam lutris gamescope \
        vulkan-tools \
        gamemode mangohud || true
      ;;
    apt)
      sudo apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        steam lutris gamescope mangohud gamemode vulkan-tools || true
      ;;
    pacman)
      sudo pacman -Sy --needed --noconfirm \
        steam lutris gamescope mangohud gamemode vulkan-tools || true
      ;;
  esac

  have steam      && mark_present "Steam" "in PATH"        || mark_skipped "Steam" "not found after install attempt"
  have lutris     && mark_present "Lutris" "in PATH"       || mark_skipped "Lutris" "not found after install attempt"
  have gamescope  && mark_present "Gamescope" "in PATH"    || mark_skipped "Gamescope" "not found after install attempt"
  have mangohud   && mark_present "MangoHud" "in PATH"     || mark_skipped "MangoHud" "not found after install attempt"
  have vulkaninfo && mark_present "Vulkan tools" "vulkaninfo OK" || mark_skipped "Vulkan tools" "vulkaninfo missing"
  have gamemoded  && mark_present "GameMode" "daemon present"    || mark_skipped "GameMode" "gamemoded missing"
}

install_wine_stack() {
  echo -e "${BLUE}==> Installing Wine + Winetricks${RESET}"
  case "$pkg_id" in
    zypper)  sudo zypper -n in -l wine wine-32bit winetricks || true ;;
    dnf)     sudo dnf -y install wine winetricks || true ;;
    apt)     sudo apt-get update -y; sudo apt-get install -y wine winetricks || true ;;
    pacman)  sudo pacman -Sy --needed --noconfirm wine winetricks || true ;;
  esac
  have wine && mark_present "Wine" "in PATH" || mark_skipped "Wine" "not found after install attempt"
  have winetricks && mark_present "Winetricks" "in PATH" || mark_skipped "Winetricks" "not found after install attempt"
}

install_qol_native() {
  echo -e "${BLUE}==> Installing QoL apps (Discord preferred native, OBS, GOverlay)${RESET}"
  # OBS + GOverlay + vkbasalt best-effort native
  case "$pkg_id" in
    zypper)  sudo zypper -n in -l obs-studio goverlay vkbasalt Mesa-demo || true ;;
    dnf)     sudo dnf -y install obs-studio goverlay vkbasalt || true ;;
    apt)     sudo apt-get update -y; sudo apt-get install -y obs-studio || true ;;
    pacman)  sudo pacman -Sy --needed --noconfirm obs-studio goverlay vkbasalt || true ;;
  esac
  have obs && mark_present "OBS Studio" "in PATH" || mark_skipped "OBS Studio" "not found after install attempt"
  have goverlay && mark_present "GOverlay" "in PATH" || mark_skipped "GOverlay" "not found after install attempt"

  # Discord with preferred logic
  install_discord
}

install_proton_tools_flatpak() {
  echo -e "${BLUE}==> Installing Proton tools & Heroic via Flatpak (user scope)${RESET}"
  if ! have flatpak; then pkg_install flatpak || true; fi
  if ! flatpak remotes --user | grep -q '^flathub'; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi

  if flatpak info --user net.davidotek.pupgui2 >/dev/null 2>&1 || \
     flatpak install -y --user flathub net.davidotek.pupgui2; then
    mark_present "ProtonUp-Qt" "flatpak:user net.davidotek.pupgui2"
  else
    mark_error "ProtonUp-Qt" "flatpak install failed"
  fi

  if flatpak info --user com.vysp3r.ProtonPlus >/dev/null 2>&1 || \
     flatpak install -y --user flathub com.vysp3r.ProtonPlus; then
    mark_present "ProtonPlus" "flatpak:user com.vysp3r.ProtonPlus"
  else
    mark_error "ProtonPlus" "flatpak install failed"
  fi

  if flatpak info --user com.heroicgameslauncher.hgl >/dev/null 2>&1 || \
     flatpak install -y --user flathub com.heroicgameslauncher.hgl; then
    mark_present "Heroic" "flatpak:user com.heroicgameslauncher.hgl"
  else
    mark_error "Heroic" "flatpak install failed"
  fi
}

install_kernel_extras() {
  echo -e "${BLUE}==> Installing optional kernel extras (v4l2loopback on SUSE)${RESET}"
  if [[ "$pkg_id" == "zypper" ]]; then
    sudo zypper -n in -l kernel-default-devel v4l2loopback-kmp-default || true
    if modinfo v4l2loopback >/dev/null 2>&1; then
      if sudo modprobe v4l2loopback exclusive_caps=1 max_buffers=2 card_label="Loopback" 2>/dev/null; then
        mark_present "v4l2loopback" "module loaded"
      else
        mark_error "v4l2loopback" "installed but modprobe failed"
      fi
    else
      mark_error "v4l2loopback" "installed but no module for running kernel yet"
    fi
  else
    mark_skipped "v4l2loopback" "not applicable for this distro"
  fi
}

# ===== Main =====
print_banner
require_sudo_once
detect_pkg

# openSUSE: Ensure Packman
if [[ "$pkg_id" == "zypper" ]]; then
  echo -e "${BLUE}==> openSUSE: Ensuring Packman & refreshing repositories${RESET}"
  [[ "$AGREE_PK" == "true" ]] && release_pkgkit_lock
  if ! zypper lr | grep -q '^packman'; then
    sudo zypper -n ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
  fi
  sudo zypper -n ref || true
fi

case "$BUNDLE" in
  full)
    install_core
    install_qol_native
    install_wine_stack
    install_proton_tools_flatpak
    install_kernel_extras
    ;;
  *)
    install_core
    install_qol_native
    ;;
esac

# ===== Summary =====
echo -e "${BLUE}----------------------------------------------------------${RESET}"
echo -e "${BLUE} Install Status Summary${RESET}"
echo -e "${BLUE}----------------------------------------------------------${RESET}"

# Desired display order
ordered=(
  "Steam" "Lutris" "Gamescope" "MangoHud" "Vulkan tools" "GameMode"
  "Wine" "Winetricks" "OBS Studio" "Discord"
  "ProtonUp-Qt" "ProtonPlus" "Heroic" "GOverlay" "v4l2loopback"
)

printed=()
for name in "${ordered[@]}"; do
  if [[ -n "${STATUS_SYM[$name]+x}" ]]; then
    printf " %b %-14s %s\n" "${STATUS_SYM[$name]}" "$name" "${STATUS_TEXT[$name]}"
    printed+=("$name")
  fi
done

# Any extra keys that slipped in
for name in "${!STATUS_SYM[@]}"; do
  skip="false"
  for p in "${printed[@]}"; do [[ "$p" == "$name" ]] && skip="true"; done
  [[ "$skip" == "true" ]] && continue
  printf " %b %-14s %s\n" "${STATUS_SYM[$name]}" "$name" "${STATUS_TEXT[$name]}"
done

echo -e "${BLUE}----------------------------------------------------------${RESET}"
echo "Tips:"
echo "- ProtonUp-Qt: flatpak run net.davidotek.pupgui2"
echo "- ProtonPlus : flatpak run com.vysp3r.ProtonPlus"
echo "- Heroic     : flatpak run com.heroicgameslauncher.hgl"
echo -e "${BLUE}----------------------------------------------------------${RESET}"
echo "Log saved to: ${LOG_FILE}"
echo "Done."
