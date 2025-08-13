#!/usr/bin/env bash
# ==============================================================================
# Team Nocturnal — Universal Gaming Setup Script
# Author: XsMagical
# Version: Native Steam Only + Full App List + Safe Launcher
# ==============================================================================
# This script sets up a complete Linux gaming and streaming environment.
# It is designed to work across Fedora/RHEL, Ubuntu/Debian, and Arch/Manjaro.
#
# Key Features:
#   • Installs ONLY native Steam (no Flatpak fallback) and fails if unavailable.
#   • Installs all original gaming/streaming/utility apps from the legacy script.
#   • Installs native packages first, falls back to Flatpak for non-Steam apps.
#   • Removes system-wide overlay envs (uses GOverlay for per-game overlays).
#   • Patches Steam with a safe launcher to fix Wayland/SELinux CEF crashes.
#   • Cleans up Flatpak duplicates when native version is installed.
#
# Usage:
#   Run this script after a clean OS install to bootstrap a complete gaming
#   environment with safe defaults.
# ==============================================================================

# ===== Colors for output =====
RED="\033[31m"; BLUE="\033[34m"; RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"

print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   Team-Nocturnal.com \"Universal Gaming Setup\" by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# -----------------------------------------------------------------------------
#  Initialize and configure logging
# -----------------------------------------------------------------------------
print_banner
set -u
LOG_DIR="${HOME}/scripts/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/gaming_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

# Default flags and configuration
YES_FLAG=0
DISCORD_MODE="auto"
CLEANUP_DUPES=1
WRITE_MANGOHUD_DEFAULTS=0
WANT_PROTONPLUS=0
WANT_PROTONUPQT=0
SKIP_STEAM=0

# Helper functions for logging and package checks
have() { command -v "$1" >/dev/null 2>&1; }
log() { printf '%b\n' "${BOLD}==>${RESET} $*"; }
info(){ printf '%b\n' "${DIM} ->${RESET} $*"; }
warn(){ printf '%b\n' "${RED}[!]${RESET} $*"; }

# -----------------------------------------------------------------------------
#  Parse command-line arguments
# -----------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    --discord=*) DISCORD_MODE="${1#*=}";;
    --no-cleanup-flatpak-dupes) CLEANUP_DUPES=0;;
    --mangohud-defaults) WRITE_MANGOHUD_DEFAULTS=1;;
    --protonplus) WANT_PROTONPLUS=1;;
    --protonupqt) WANT_PROTONUPQT=1;;
    --skip-steam) SKIP_STEAM=1;;
    -y|--yes) YES_FLAG=1;;
    *) warn "Unknown flag: $1";;
  esac
  shift
done

# -----------------------------------------------------------------------------
#  Configure sudo and architecture detection
# -----------------------------------------------------------------------------
SUDO="sudo"
[ $YES_FLAG -eq 1 ] && DNF_Y="-y" || DNF_Y=""
[ $YES_FLAG -eq 1 ] && APT_Y="-y" || APT_Y=""
[ $YES_FLAG -eq 1 ] && PAC_Y="--noconfirm" || PAC_Y=""
ARCH="$(uname -m)"
IS_ARM=0
[ "${ARCH}" = "aarch64" ] && IS_ARM=1

# Detect package manager
if have dnf; then PM="dnf"
elif have apt; then PM="apt"
elif have pacman; then PM="pacman"
else warn "Unsupported distro (no dnf/apt/pacman)."; exit 1
fi

# Validate sudo privileges
$SUDO -v 2>/dev/null || true

# -----------------------------------------------------------------------------
#  Package management helper functions
# -----------------------------------------------------------------------------
install_native() {
  case "$PM" in
    dnf) $SUDO dnf install $DNF_Y -y "$@" || true ;;
    apt) $SUDO apt update || true; $SUDO apt install $APT_Y "$@" || true ;;
    pacman) $SUDO pacman -Sy $PAC_Y "$@" || true ;;
  esac
}

remove_native() {
  case "$PM" in
    dnf) $SUDO dnf remove -y "$@" || true ;;
    apt) $SUDO apt purge -y "$@" || true ;;
    pacman) $SUDO pacman -Rs $PAC_Y "$@" || true ;;
  esac
}

# Flatpak helper functions
fp_install() {
  have flatpak || install_native flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y --noninteractive flathub "$1" || true
}

fp_remove_if_present() {
  if have flatpak && flatpak info "$1" >/dev/null 2>&1; then
    flatpak uninstall -y "$1" || true
  fi
}

# -----------------------------------------------------------------------------
#  Enable repos for each supported distro
# -----------------------------------------------------------------------------
case "$PM" in
  dnf)
    log "Enabling multilib and RPM Fusion…"
    $SUDO dnf install -y dnf-plugins-core
    $SUDO dnf config-manager --set-enabled fedora-multilib updates-testing updates-testing-modular fedora
    $SUDO dnf install $DNF_Y -y       https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm       https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    ;;
  apt)
    log "Ensuring multiverse is enabled…"
    $SUDO add-apt-repository -y multiverse || true
    $SUDO apt update || true
    ;;
  pacman)
    log "Refreshing pacman databases…"
    $SUDO pacman -Sy || true
    ;;
esac

# -----------------------------------------------------------------------------
#  Install core gaming and streaming applications
# -----------------------------------------------------------------------------
log "Installing core tools (GameMode, MangoHud, Wine, Vulkan, Lutris, OBS, etc.)…"
case "$PM" in
  dnf)
    install_native gamemode mangohud mangohud.i686                    wine wine-mono wine-gecko                    vulkan-loader vulkan-loader.i686                    mesa-dri-drivers mesa-dri-drivers.i686                    mesa-vulkan-drivers mesa-vulkan-drivers.i686                    lutris obs-studio
    ;;
  apt)
    install_native gamemode mangohud                    wine wine64 winetricks                    vulkan-tools mesa-vulkan-drivers                    lutris obs-studio
    ;;
  pacman)
    install_native gamemode mangohud wine winetricks vulkan-tools vulkan-icd-loader lutris obs-studio
    ;;
esac

# Flatpak fallback installs
fp_install com.heroicgameslauncher.hgl
fp_install com.github.gicmo.goverlay
fp_install com.obsproject.Studio
fp_install com.discordapp.Discord

# Proton tools
[ $WANT_PROTONUPQT -eq 1 ] && fp_install net.davidotek.pupgui2
[ $WANT_PROTONPLUS -eq 1 ] && [ "$PM" = "dnf" ] && $SUDO dnf -y copr enable wehagy/protonplus && install_native protonplus

# Discord handling
if [ "$DISCORD_MODE" = "native" ] || { [ "$DISCORD_MODE" = "auto" ] && [ "$PM" = "dnf" ]; }; then
  install_native discord || fp_install com.discordapp.Discord
  [ $CLEANUP_DUPES -eq 1 ] && fp_remove_if_present com.discordapp.Discord
else
  fp_install com.discordapp.Discord
  [ $CLEANUP_DUPES -eq 1 ] && remove_native discord
fi

# -----------------------------------------------------------------------------
#  Install Steam (native only)
# -----------------------------------------------------------------------------
if [ $SKIP_STEAM -eq 0 ]; then
  if [ $IS_ARM -eq 1 ]; then
    warn "ARM architecture — native Steam not available."; exit 1
  fi
  log "Installing Steam (native-only)…"
  case "$PM" in
    dnf) install_native steam steam-devices steam-selinux ;;
    apt) install_native steam-installer || install_native steam-launcher ;;
    pacman) install_native steam ;;
  esac
  have steam || { warn "Native Steam installation failed — aborting."; exit 1; }
fi

# -----------------------------------------------------------------------------
#  Create Steam safe launcher
# -----------------------------------------------------------------------------
log "Creating Steam safe UI launcher…"
USER_APPS="${HOME}/.local/share/applications"
SCRIPTS_DIR="${HOME}/scripts"
WRAPPER="${SCRIPTS_DIR}/steam_safe.sh"
mkdir -p "${SCRIPTS_DIR}" "${USER_APPS}"

cat > "${WRAPPER}" <<'EOF'
#!/usr/bin/env bash
# Steam Safe Launcher
# Unsets overlay variables for the UI, forces X11 for CEF stability, and runs Steam with safe flags.
unset MANGOHUD MANGOHUD_DLSYM ENABLE_VKBASALT VKBASALT_CONFIG_FILE VKBASALT_LOG_FILE
unset LD_PRELOAD DXVK_HUD __GL_THREADED_OPTIMIZATIONS VK_INSTANCE_LAYERS VK_LAYER_PATH
unset ENABLE_GAMESCOPE GAMESCOPE GAMESCOPE_* GAMEDEBUG
export QT_QPA_PLATFORM=xcb
export SDL_VIDEODRIVER=x11
[ -f "$HOME/.config/team-nocturnal/overlay.env" ] && . "$HOME/.config/team-nocturnal/overlay.env" || true
exec steam -no-cef-sandbox -cef-disable-gpu "$@"
EOF
chmod +x "${WRAPPER}"

cat > "${USER_APPS}/steam.desktop" <<EOF
[Desktop Entry]
Name=Steam
Comment=Steam (safe UI launch)
Exec=/home/${USER}/scripts/steam_safe.sh %U
Terminal=false
Type=Application
Icon=steam
Categories=Game;
MimeType=x-scheme-handler/steam;
StartupNotify=false
EOF
xdg-mime default steam.desktop x-scheme-handler/steam 2>/dev/null || true
update-desktop-database "${USER_APPS}" 2>/dev/null || true
rm -rf ~/.steam/steam/{appcache,package,config/htmlcache,steamui}
rm -rf ~/.local/share/Steam/{appcache,package,config/htmlcache,steamui}

# -----------------------------------------------------------------------------
#  Write MangoHud default configuration (optional)
# -----------------------------------------------------------------------------
if [ $WRITE_MANGOHUD_DEFAULTS -eq 1 ]; then
  log "Writing MangoHud default config…"
  mkdir -p "${HOME}/.config/MangoHud"
  cat > "${HOME}/.config/MangoHud/MangoHud.conf" <<'EOF'
fps_limit=0
toggle_hud=RShift+F12
position=top-left
font_size=20
gpu_stats=1
gpu_temp=1
vram=1
fps=1
frametime=1
background_alpha=0.3
EOF
fi

# -----------------------------------------------------------------------------
#  Completion message
# -----------------------------------------------------------------------------
log "All done. Log: ${LOG_FILE}"
info "Steam installed natively and safe launcher is default."
info "Use GOverlay for per-game overlays."
