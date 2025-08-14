#!/usr/bin/env bash
# Team Nocturnal — Universal Gaming Setup (native Discord by default) by XsMagical
# Repo: https://github.com/XsMagical/Linux-Tools
#
# Summary:
# - Cross‑distro gaming bootstrap for Fedora/RHEL, Ubuntu/Debian, and Arch/Manjaro.
# - Prioritizes NATIVE packages over Flatpak (and removes duplicates).
# - Installs Steam, Proton tooling, Wine + Vulkan bits, MangoHud, GameMode, Lutris, Heroic, etc.
# - **Discord defaults to native (RPM/DEB/pacman) and only falls back to Flatpak if native is unavailable.**
# - Safe to re‑run; idempotent installers; detects package manager automatically.
#
# Usage (examples):
#   sudo ~/scripts/universal_gaming_setup.sh
#   sudo ~/scripts/universal_gaming_setup.sh --overlays=none
#   sudo ~/scripts/universal_gaming_setup.sh --discord=flatpak     # force Flatpak Discord
#   sudo ~/scripts/universal_gaming_setup.sh --discord=native      # force native Discord (default)
#   sudo ~/scripts/universal_gaming_setup.sh --no-heroic --no-lutris
#
# Flags:
#   --discord=native|flatpak     Choose Discord source (default: native; auto-fallback to Flatpak if needed)
#   --overlays=none|steam|game   Overlay presets: none (default), Steam-only, or per‑game template
#   --no-steam|--no-wine|--no-lutris|--no-heroic|--no-gamemode|--no-mangohud
#   --verbose                    Show commands being run
#   -y|--assume-yes              Assume yes to package prompts
#
# Notes:
# - Fedora: enables RPM Fusion (free+nonfree) automatically.
# - Ubuntu/Debian: ensures universe/multiverse (Ubuntu) and contrib/non-free(/non-free-firmware) (Debian) when possible.
# - Arch: uses pacman; skips Steam on ARM.
# - Flatpak is used as a fallback when native isn’t available (e.g., Discord on some Debian/Ubuntu setups).

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
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal Gaming Setup by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# ===== Defaults & Globals =====
ASSUME_YES=0
VERBOSE=0
DISCORD_MODE="native"   # native | flatpak
OVERLAYS_MODE="none"    # none | steam | game

# Feature toggles (on by default)
WANT_STEAM=1
WANT_WINE=1
WANT_LUTRIS=1
WANT_HEROIC=1
WANT_GAMEMODE=1
WANT_MANGOHUD=1

PM=""; OS_FAMILY=""; OS_ID=""; OS_VER_ID=""

log() { printf '%b\n' "$*"; }
run() { if [ "$VERBOSE" -eq 1 ]; then set -x; fi; "$@"; local rc=$?; if [ "$VERBOSE" -eq 1 ]; then set +x; fi; return $rc; }
yesflag() { [ "$ASSUME_YES" -eq 1 ] && echo "-y" || echo ""; }

# ===== Arg Parse =====
while [ $# -gt 0 ]; do
  case "$1" in
    --verbose) VERBOSE=1 ;;
    -y|--assume-yes) ASSUME_YES=1 ;;
    --discord=*) DISCORD_MODE="${1#*=}" ;;
    --overlays=*) OVERLAYS_MODE="${1#*=}" ;;
    --no-steam) WANT_STEAM=0 ;;
    --no-wine) WANT_WINE=0 ;;
    --no-lutris) WANT_LUTRIS=0 ;;
    --no-heroic) WANT_HEROIC=0 ;;
    --no-gamemode) WANT_GAMEMODE=0 ;;
    --no-mangohud) WANT_MANGOHUD=0 ;;
    *) log "${RED}Unknown flag:${RESET} $1"; exit 1 ;;
  esac
  shift
done

# ===== Distro Detect =====
detect_distro() {
  if command -v rpm &>/dev/null && command -v dnf &>/dev/null; then
    PM="dnf"; OS_FAMILY="fedora"
    OS_ID=$(source /etc/os-release && echo "$ID")
    OS_VER_ID=$(source /etc/os-release && echo "$VERSION_ID")
  elif command -v apt-get &>/dev/null; then
    PM="apt"; OS_FAMILY="debian"
    OS_ID=$(source /etc/os-release && echo "$ID")
    OS_VER_ID=$(source /etc/os-release && echo "$VERSION_ID")
  elif command -v pacman &>/dev/null; then
    PM="pacman"; OS_FAMILY="arch"
    OS_ID="arch"; OS_VER_ID=""
  else
    log "${RED}Unsupported distro: need dnf/apt/pacman${RESET}"; exit 1
  fi
}

# ===== Helpers: PM install/remove/query =====
have_cmd() { command -v "$1" &>/dev/null; }
is_installed_pkg() {
  case "$PM" in
    dnf) rpm -q "$1" &>/dev/null ;;
    apt) dpkg -s "$1" &>/dev/null ;;
    pacman) pacman -Q "$1" &>/dev/null ;;
  esac
}
pkg_install() {
  case "$PM" in
    dnf) run sudo dnf install $(yesflag) "$@" ;;
    apt) run sudo apt-get update && run sudo apt-get install $(yesflag) "$@" ;;
    pacman) run sudo pacman -Sy --needed --noconfirm "$@" ;;
  esac
}
pkg_remove() {
  case "$PM" in
    dnf) run sudo dnf remove $(yesflag) "$@" ;;
    apt) run sudo apt-get remove $(yesflag) "$@" ;;
    pacman) run sudo pacman -Rns --noconfirm "$@" ;;
  esac
}

# ===== Repos =====
enable_repos_fedora() {
  # RPM Fusion free + nonfree
  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    run sudo dnf install $(yesflag) \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${OS_VER_ID}.noarch.rpm"
  fi
  if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    run sudo dnf install $(yesflag) \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${OS_VER_ID}.noarch.rpm"
  fi
  run sudo dnf makecache
}

enable_repos_debian_like() {
  # Try to ensure common sections where applicable
  if have_cmd add-apt-repository; then
    # Ubuntu
    run sudo add-apt-repository -y universe || true
    run sudo add-apt-repository -y multiverse || true
  else
    # Debian: attempt to enable contrib & non-free components
    if [ -f /etc/apt/sources.list ]; then
      if ! grep -Eqi 'non-free|contrib' /etc/apt/sources.list; then
        run sudo sed -i 's/^deb \(.* main\)$/deb \1 main contrib non-free non-free-firmware/g' /etc/apt/sources.list || true
      fi
    fi
  fi
  run sudo apt-get update || true
}

ensure_flatpak() {
  if ! have_cmd flatpak; then
    case "$PM" in
      dnf) pkg_install flatpak ;;
      apt) pkg_install flatpak ;;
      pacman) pkg_install flatpak ;;
    esac
  fi
  # Flathub remote
  if ! flatpak remotes | awk '{print $1}' | grep -qx Flathub; then
    run sudo flatpak remote-add --if-not-exists Flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

flatpak_installed() { flatpak list --app | awk '{print $1}' | grep -qx "$1"; }
flatpak_install() { ensure_flatpak; run sudo flatpak install -y Flathub "$1"; }
flatpak_remove_if_present() { if flatpak_installed "$1"; then run sudo flatpak uninstall -y "$1"; fi }

# ===== Core Components =====
install_steam() {
  case "$OS_FAMILY" in
    fedora)
      pkg_install steam
      ;;
    debian)
      # i386 multi-arch for Steam
      if ! dpkg --print-foreign-architectures | grep -qx i386; then
        run sudo dpkg --add-architecture i386
      fi
      run sudo apt-get update
      pkg_install steam
      ;;
    arch)
      # Skip on ARM
      if uname -m | grep -qi 'arm'; then
        log "${DIM}Skipping Steam on ARM${RESET}"
      else
        pkg_install steam
      fi
      ;;
  esac
}

install_wine_vulkan_gamemode_mangohud() {
  case "$OS_FAMILY" in
    fedora)
      pkg_install wine winetricks vulkan vulkan-tools gamemode mangohud mangohud.i686
      ;;
    debian)
      # Wine, Vulkan loader, tools; i386 where needed
      if ! dpkg --print-foreign-architectures | grep -qx i386; then
        run sudo dpkg --add-architecture i386
        run sudo apt-get update
      fi
      pkg_install wine winetricks vulkan-tools mesa-vulkan-drivers mesa-vulkan-drivers:i386 gamemode mangohud
      ;;
    arch)
      pkg_install wine winetricks vulkan-tools gamemode mangohud lib32-mangohud
      ;;
  esac
}

install_lutris() {
  case "$OS_FAMILY" in
    fedora|debian|arch) pkg_install lutris || flatpak_install net.lutris.Lutris ;;
  esac
  # Remove duplicate if both present: prefer native
  flatpak_remove_if_present net.lutris.Lutris || true
}

install_heroic() {
  case "$OS_FAMILY" in
    fedora) pkg_install heroic-games-launcher || flatpak_install com.heroicgameslauncher.hgl ;;
    debian) flatpak_install com.heroicgameslauncher.hgl ;;   # native deb is not always reliable
    arch)   pkg_install heroic-games-launcher-bin || flatpak_install com.heroicgameslauncher.hgl ;;
  esac
  # Prefer native if available
  if is_installed_pkg heroic-games-launcher || is_installed_pkg heroic-games-launcher-bin; then
    flatpak_remove_if_present com.heroicgameslauncher.hgl || true
  fi
}

# ===== Discord (NATIVE by default with Flatpak fallback) =====
install_discord_native_or_flatpak() {
  case "$DISCORD_MODE" in
    native) _install_discord_native || { log "${DIM}Native Discord not available; falling back to Flatpak...${RESET}"; _install_discord_flatpak; } ;;
    flatpak) _install_discord_flatpak ;;
    *) log "${RED}Invalid --discord mode:${RESET} $DISCORD_MODE"; exit 1 ;;
  esac

  # If native ended up installed, remove Flatpak duplicate; else keep Flatpak.
  if _discord_native_installed; then
    flatpak_remove_if_present com.discordapp.Discord || true
  fi
}

_discord_native_installed() {
  case "$OS_FAMILY" in
    fedora) is_installed_pkg discord ;;
    debian) is_installed_pkg discord || dpkg -s discord 2>/dev/null | grep -q '^Status: install' ;;
    arch)   is_installed_pkg discord ;;
    *) return 1 ;;
  esac
}

_install_discord_native() {
  case "$OS_FAMILY" in
    fedora)
      # Requires RPM Fusion nonfree (already enabled earlier)
      pkg_install discord
      ;;
    debian)
      # Try apt first
      if pkg_install discord; then
        :
      else
        # Fallback: official .deb
        TMPD=$(mktemp -d)
        run bash -c "cd '$TMPD' && wget -O discord.deb 'https://discord.com/api/download?platform=linux&format=deb'"
        run sudo apt-get install $(yesflag) "./$TMPD/discord.deb" || run sudo apt -y install "./$TMPD/discord.deb"
        rm -rf "$TMPD"
      fi
      ;;
    arch)
      pkg_install discord
      ;;
    *)
      return 1
      ;;
  esac
}

_install_discord_flatpak() {
  flatpak_install com.discordapp.Discord
}

# ===== Overlays Presets =====
configure_overlays() {
  case "$OVERLAYS_MODE" in
    none)
      log "${DIM}Overlay preset: none (no system-wide changes)${RESET}"
      ;;
    steam)
      # Steam-only: Ship a MangoHud config and advise user to toggle per-game in Steam Launch Options
      _deploy_mangohud_config
      log "${DIM}Overlay preset: Steam-only (use MANGOHUD=1 in Steam launch options)${RESET}"
      ;;
    game)
      _deploy_mangohud_config
      _write_per_game_overlay_template
      ;;
    *)
      log "${RED}Invalid --overlays preset:${RESET} $OVERLAYS_MODE"; exit 1
      ;;
  esac
}

_deploy_mangohud_config() {
  mkdir -p "${HOME}/.config/MangoHud"
  cat > "${HOME}/.config/MangoHud/MangoHud.conf" <<'EOF'
fps_limit=0
cpu_temp
gpu_temp
ram
vram
gamemode
gpu_load_change
frame_timing=1
EOF
  chown "$(id -u):$(id -g)" "${HOME}/.config/MangoHud/MangoHud.conf" 2>/dev/null || true
}

_write_per_game_overlay_template() {
  mkdir -p "${HOME}/Games/Overlay-Templates"
  cat > "${HOME}/Games/Overlay-Templates/README.txt" <<'EOF'
Per-game overlay template:

Steam (Properties → Launch Options):
  MANGOHUD=1 %command%

Non-Steam game launcher (shell):
  MANGOHUD=1 gamemoderun <your_game_cmd>

Adjust MangoHud config at:
  ~/.config/MangoHud/MangoHud.conf
EOF
}

# ===== Duplicate Cleanup (prefer native) =====
remove_flatpak_duplicates_if_native() {
  # Discord
  if _discord_native_installed; then
    flatpak_remove_if_present com.discordapp.Discord || true
  fi
  # Lutris
  if is_installed_pkg lutris; then
    flatpak_remove_if_present net.lutris.Lutris || true
  fi
  # Heroic
  if is_installed_pkg heroic-games-launcher || is_installed_pkg heroic-games-launcher-bin; then
    flatpak_remove_if_present com.heroicgameslauncher.hgl || true
  fi
}

# ===== Main =====
main() {
  print_banner
  detect_distro
  log "Detected: ${BOLD}${OS_FAMILY}${RESET} (${OS_ID} ${OS_VER_ID})  PM=${PM}"
  [ "$PM" = "dnf" ] && enable_repos_fedora
  [ "$PM" = "apt" ] && enable_repos_debian_like

  # Core stack
  [ "$WANT_STEAM" -eq 1 ] && install_steam
  [ "$WANT_WINE" -eq 1 ] && install_wine_vulkan_gamemode_mangohud
  [ "$WANT_LUTRIS" -eq 1 ] && install_lutris
  [ "$WANT_HEROIC" -eq 1 ] && install_heroic

  # GameMode & MangoHud are part of Wine/Vulkan group above; ensure present if toggled back on
  if [ "$WANT_GAMEMODE" -eq 1 ]; then
    case "$OS_FAMILY" in
      fedora|debian) is_installed_pkg gamemode || pkg_install gamemode ;;
      arch) is_installed_pkg gamemode || pkg_install gamemode ;;
    esac
  fi
  if [ "$WANT_MANGOHUD" -eq 1 ]; then
    case "$OS_FAMILY" in
      fedora) is_installed_pkg mangohud || pkg_install mangohud mangohud.i686 ;;
      debian) is_installed_pkg mangohud || pkg_install mangohud ;;
      arch) is_installed_pkg mangohud || pkg_install mangohud lib32-mangohud ;;
    esac
  fi

  # Discord (native default with Flatpak fallback)
  install_discord_native_or_flatpak

  # Overlays preset
  configure_overlays

  # Remove Flatpak duplicates when native is installed
  remove_flatpak_duplicates_if_native

  log ""
  log "${BOLD}Done.${RESET} Reboot is not required, but recommended after large updates."
}

main "$@"
