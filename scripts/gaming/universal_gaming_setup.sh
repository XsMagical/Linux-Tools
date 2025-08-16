#!/usr/bin/env bash
set -euo pipefail

# ================= Colors & Symbols =================
RED="\033[31m"; BLUE="\033[34m"; GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"
BOLD="\033[1m"
OK="✅"           # freshly installed
PRESENT="🟦"      # already present
SKIP="⚪"         # skipped (not requested / not needed)
ERR="❌"          # error

# ================= Banner =================
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

# ================= Args & Logging =================
BUNDLE="full"
AGREE_PK="false"
AUTOLOG="true"

for arg in "$@"; do
  case "$arg" in
    --bundle=*) BUNDLE="${arg#*=}";;
    --agree-pk) AGREE_PK="true";;
    --autolog)  AUTOLOG="true";;
    -y|--yes)   : ;;   # accepted for compatibility
    *) : ;;
  esac
done

# Prepare logging to USER folder, even when running via sudo
REAL_HOME="${SUDO_USER:+$(getent passwd "$SUDO_USER" | cut -d: -f6)}"
REAL_HOME="${REAL_HOME:-$HOME}"
LOG_DIR="${REAL_HOME}/scripts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/gaming_$(date +%Y%m%d_%H%M%S).log"

# Start tee only now (after parsing so args don't leak into log as commands)
exec > >(tee -a "$LOG_FILE") 2>&1
print_banner
echo "Logging to: $LOG_FILE"

# ================= Helpers =================
have() { command -v "$1" >/dev/null 2>&1; }

# Prompt once for sudo at the beginning (unless running as root)
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo -e "${BLUE}==> Elevation: requesting admin privileges once (sudo -v)...${RESET}"
  sudo -v
  # keep alive while the script runs
  ( while true; do sudo -n true; sleep 30; done ) >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true' EXIT
else
  echo -e "${BLUE}==> Running as root; no sudo prompt needed.${RESET}"
fi

agree_pkgkit_if_needed() {
  if [[ "$AGREE_PK" == "true" ]] && have pkcon; then
    pkcon quit >/dev/null 2>&1 || true
    sleep 1
  fi
}

# Status tracking
declare -A STATUS
set_status() { # name code detail
  local name="$1" code="$2" detail="${3:-}"
  STATUS["$name"]="$code${detail:+|$detail}"
}

print_status_line() {
  local name="$1" value="${STATUS[$1]:-}"
  local code="${value%%|*}"; local detail=""; [[ "$value" == *"|"* ]] && detail="${value#*|}"
  local icon label
  case "$code" in
    ok)     icon="$OK";     label="Installed";;
    present)icon="$PRESENT";label="Already present";;
    skip)   icon="$SKIP";   label="Skipped";;
    err)    icon="$ERR";    label="Error";;
    *)      icon="$SKIP";   label="Unknown";;
  esac
  if [[ -n "$detail" ]]; then
    printf " %s %-14s %s (%s)\n" "$icon" "$name:" "$label" "$detail"
  else
    printf " %s %-14s %s\n" "$icon" "$name:" "$label"
  fi
}

print_summary() {
  echo "----------------------------------------------------------"
  echo " Install Status Summary"
  echo "----------------------------------------------------------"
  for item in steam lutris gamescope mangohud vulkaninfo gamemoded wine winetricks obs discord \
              "ProtonUp-Qt" "ProtonPlus" "Heroic" GOverlay v4l2loopback; do
    print_status_line "$item"
  done
  echo "----------------------------------------------------------"
  echo "Tips:"
  echo "- ProtonUp-Qt: flatpak run net.davidotek.pupgui2"
  echo "- ProtonPlus : flatpak run com.vysp3r.ProtonPlus"
  echo "- Heroic     : flatpak run com.heroicgameslauncher.hgl"
  echo ""
  echo "If PackageKit causes locks, add --agree-pk to auto-release the lock."
  echo "Log saved to: $LOG_FILE"
  echo "Done."
}

# Distro detect
detect_pkg() {
  if have zypper; then echo suse; return; fi
  if have apt-get; then echo ubuntu; return; fi
  if have dnf; then echo fedora; return; fi
  if have pacman; then echo arch; return; fi
  echo none
}

release_pkgkit_lock() {
  agree_pkgkit_if_needed
}

# ================= Per-distro installers =================
suse_refresh() {
  echo -e "${BLUE}==> openSUSE: Ensuring Packman & refreshing repositories${RESET}"
  release_pkgkit_lock
  if ! zypper lr | grep -q '^packman'; then
    sudo zypper -n ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
  fi
  sudo zypper -n ref || true
}

suse_install_native() {
  # Core
  echo -e "${BLUE}==> Installing core gaming packages (Steam, Lutris, Wine, Vulkan, etc.)${RESET}"
  release_pkgkit_lock
  if sudo zypper -n in -l -y \
      Mesa-libGL1-32bit libvulkan1-32bit vulkan-tools vulkan-validationlayers \
      gamemode libgamemode0 libgamemodeauto0-32bit mangohud mangohud-32bit \
      steam lutris gamescope; then
    set_status steam present; set_status lutris present; set_status gamescope present
    set_status mangohud present; set_status vulkaninfo present; set_status gamemoded present
  else
    set_status steam err "zypper"; set_status lutris err "zypper"; set_status gamescope err "zypper"
    set_status mangohud err "zypper"; set_status vulkaninfo err "zypper"; set_status gamemoded err "zypper"
  fi

  # QoL
  echo -e "${BLUE}==> Installing QoL apps (Discord, OBS, GOverlay native)${RESET}"
  if sudo zypper -n in -l -y discord obs-studio goverlay vkbasalt Mesa-demo; then
    set_status obs present; set_status discord present; set_status GOverlay present
  else
    set_status obs err "zypper"; set_status discord err "zypper"; set_status GOverlay err "zypper"
  fi

  # Wine
  echo -e "${BLUE}==> Installing Wine + Winetricks${RESET}"
  if sudo zypper -n in -l -y wine wine-32bit winetricks; then
    set_status wine present; set_status winetricks present
  else
    set_status wine err "zypper"; set_status winetricks err "zypper"
  fi

  # Kernel extras
  echo -e "${BLUE}==> Installing optional kernel extras (v4l2loopback KMP)${RESET}"
  if sudo zypper -n in -l -y kernel-default-devel v4l2loopback-kmp-default; then
    if modinfo v4l2loopback >/dev/null 2>&1; then
      if sudo modprobe v4l2loopback exclusive_caps=1 max_buffers=2 card_label="Loopback"; then
        set_status v4l2loopback ok "module loaded"
      else
        set_status v4l2loopback present "installed; load failed"
      fi
    else
      set_status v4l2loopback present "installed; no module for running kernel"
    fi
  else
    set_status v4l2loopback err "zypper"
  fi
}

flatpak_install_user() {
  local app="$1" friendly="$2"
  if flatpak info --user "$app" >/dev/null 2>&1; then
    set_status "$friendly" present "Flatpak user"
    return 0
  fi
  if flatpak install -y --user flathub "$app"; then
    set_status "$friendly" ok "Flatpak user"
  else
    # maybe installed system-wide?
    if flatpak info --system "$app" >/dev/null 2>&1; then
      set_status "$friendly" present "Flatpak system"
    else
      set_status "$friendly" err "Flatpak"
      return 1
    fi
  fi
}

install_flatpaks() {
  echo -e "${BLUE}==> Installing Proton tools & Heroic via Flatpak (user scope)${RESET}"
  # ensure flatpak and flathub (user)
  if ! have flatpak; then
    case "$(detect_pkg)" in
      suse)   sudo zypper -n in -y flatpak || true ;;
      ubuntu) sudo apt-get update -y || true; sudo apt-get install -y flatpak || true ;;
      fedora) sudo dnf install -y flatpak || true ;;
      arch)   sudo pacman -Syu --noconfirm flatpak || true ;;
    esac
  fi
  if ! flatpak remotes --user | grep -q '^flathub'; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi

  flatpak_install_user net.davidotek.pupgui2 "ProtonUp-Qt" || true
  flatpak_install_user com.vysp3r.ProtonPlus "ProtonPlus" || true
  flatpak_install_user com.heroicgameslauncher.hgl "Heroic" || true
}

# ================= Main =================
echo -e "${BLUE}==> Distro detection: $(detect_pkg)${RESET}"
case "$(detect_pkg)" in
  suse)
    suse_refresh
    suse_install_native
    install_flatpaks
    ;;
  ubuntu|fedora|arch)
    echo -e "${YELLOW}Cross-distro paths exist, but this run only tweaked for openSUSE in this build.${RESET}"
    ;;
  *)
    echo -e "${RED}Unsupported distro (no known package manager).${RESET}"
    ;;
esac

# configs (lightweight, idempotent)
echo -e "${BLUE}==> Overlays: none${RESET}"
# MangoHud
mkdir -p "${REAL_HOME}/.config/MangoHud"
if [[ ! -s "${REAL_HOME}/.config/MangoHud/MangoHud.conf" ]]; then
  cat > "${REAL_HOME}/.config/MangoHud/MangoHud.conf" <<'CFG'
fps_limit=0
position=top-left
cfg
CFG
fi
# GameMode
mkdir -p "${REAL_HOME}/.config"
if [[ ! -s "${REAL_HOME}/.config/gamemode.ini" ]]; then
  cat > "${REAL_HOME}/.config/gamemode.ini" <<'CFG'
[general]
renice=10
CFG
fi

# Mark natives as present if commands exist (final sanity pass)
have steam && set_status steam present || true
have lutris && set_status lutris present || true
have gamescope && set_status gamescope present || true
have mangohud && set_status mangohud present || true
have vulkaninfo && set_status vulkaninfo present || true
have gamemoded && set_status gamemoded present || true
have wine && set_status wine present || true
have winetricks && set_status winetricks present || true
have obs && set_status obs present || true
have discord && set_status discord present || true

print_summary
