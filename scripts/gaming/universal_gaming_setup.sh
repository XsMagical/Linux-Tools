#!/usr/bin/env bash
# ==============================================================================
# Team Nocturnal — Universal Gaming Setup Script
# Author: XsMagical
# Version: Native Steam Only + Full App List + Safe Launcher + Fedora42 Fixes
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

print_banner
set -u

# Logging setup
LOG_DIR="${HOME}/scripts/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/gaming_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

# Flags
YES_FLAG=0
DISCORD_MODE="auto"
CLEANUP_DUPES=1
WRITE_MANGOHUD_DEFAULTS=0
WANT_PROTONPLUS=0
WANT_PROTONUPQT=0
SKIP_STEAM=0

# Helper functions
have() { command -v "$1" >/dev/null 2>&1; }
log() { printf '%b\n' "${BOLD}==>${RESET} $*"; }
warn(){ printf '%b\n' "${RED}[!]${RESET} $*"; }

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --discord=*) DISCORD_MODE="${1#*=}";;
    --no-cleanup-flatpak-dupes) CLEANUP_DUPES=0;;
    --mangohud-defaults) WRITE_MANGOHUD_DEFAULTS=1;;
    --protonplus) WANT_PROTONPLUS=1;;
    --protonupqt) WANT_PROTONUPQT=1;;
    --skip-steam) SKIP_STEAM=1;;
    -y|--yes) YES_FLAG=1;;
  esac
  shift
done

SUDO="sudo"
[ $YES_FLAG -eq 1 ] && DNF_Y="-y" || DNF_Y=""
[ $YES_FLAG -eq 1 ] && APT_Y="-y" || APT_Y=""
[ $YES_FLAG -eq 1 ] && PAC_Y="--noconfirm" || PAC_Y=""
ARCH="$(uname -m)"
IS_ARM=0
[ "${ARCH}" = "aarch64" ] && IS_ARM=1

# Detect PM
if have dnf5; then PM="dnf5"
elif have dnf; then PM="dnf"
elif have apt; then PM="apt"
elif have pacman; then PM="pacman"
else warn "Unsupported distro (no dnf/apt/pacman)."; exit 1
fi

$SUDO -v 2>/dev/null || true

# Package helper functions
install_native() {
  case "$PM" in
    dnf5) $SUDO dnf5 install $DNF_Y -y "$@" || true ;;
    dnf) $SUDO dnf install $DNF_Y -y "$@" || true ;;
    apt) $SUDO apt update || true; $SUDO apt install $APT_Y "$@" || true ;;
    pacman) $SUDO pacman -Sy $PAC_Y "$@" || true ;;
  esac
}

remove_native() {
  case "$PM" in
    dnf5) $SUDO dnf5 remove -y "$@" || true ;;
    dnf) $SUDO dnf remove -y "$@" || true ;;
    apt) $SUDO apt purge -y "$@" || true ;;
    pacman) $SUDO pacman -Rs $PAC_Y "$@" || true ;;
  esac
}

fp_install() {
  have flatpak || install_native flatpak
  flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install --system -y --noninteractive flathub "$1" || true
}

fp_remove_if_present() {
  if have flatpak && flatpak info "$1" >/dev/null 2>&1; then
    flatpak uninstall --system -y "$1" || true
  fi
}

# Enable repos
case "$PM" in
  dnf5)
    log "Enabling multilib and RPM Fusion (dnf5)…"
    $SUDO dnf5 install -y dnf5-plugins
    $SUDO dnf5 config enable fedora-multilib || true
    $SUDO dnf5 install $DNF_Y -y       https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm       https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    ;;
  dnf)
    log "Enabling multilib and RPM Fusion (dnf)…"
    $SUDO dnf install -y dnf-plugins-core
    $SUDO dnf config-manager --set-enabled fedora-multilib || true
    $SUDO dnf install $DNF_Y -y       https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm       https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    ;;
  apt)
    $SUDO add-apt-repository -y multiverse || true
    $SUDO apt update || true
    ;;
  pacman)
    $SUDO pacman -Sy || true
    ;;
esac

# Core apps
case "$PM" in
  dnf5|dnf)
    install_native gamemode mangohud mangohud.i686                    wine wine-mono                    vulkan-loader vulkan-loader.i686                    mesa-dri-drivers mesa-dri-drivers.i686                    mesa-vulkan-drivers mesa-vulkan-drivers.i686                    lutris obs-studio
    ;;
  apt)
    install_native gamemode mangohud                    wine wine64 winetricks                    vulkan-tools mesa-vulkan-drivers                    lutris obs-studio
    ;;
  pacman)
    install_native gamemode mangohud wine winetricks vulkan-tools vulkan-icd-loader lutris obs-studio
    ;;
esac

# Flatpak fallback apps
fp_install com.heroicgameslauncher.hgl
fp_install com.github.gicmo.goverlay
fp_install com.obsproject.Studio
fp_install com.discordapp.Discord

# Proton tools
[ $WANT_PROTONUPQT -eq 1 ] && fp_install net.davidotek.pupgui2
[ $WANT_PROTONPLUS -eq 1 ] && [ "$PM" = "dnf5" -o "$PM" = "dnf" ] && $SUDO $PM -y copr enable wehagy/protonplus && install_native protonplus

# Discord cleanup
if [ "$DISCORD_MODE" = "native" ] || { [ "$DISCORD_MODE" = "auto" ] && [ "$PM" != "apt" ]; }; then
  install_native discord || fp_install com.discordapp.Discord
  [ $CLEANUP_DUPES -eq 1 ] && fp_remove_if_present com.discordapp.Discord
else
  fp_install com.discordapp.Discord
  [ $CLEANUP_DUPES -eq 1 ] && remove_native discord
fi

# Steam (native only, no steam-selinux)
if [ $SKIP_STEAM -eq 0 ]; then
  if [ $IS_ARM -eq 1 ]; then
    warn "ARM architecture — native Steam not available."; exit 1
  fi
  case "$PM" in
    dnf5|dnf) install_native steam steam-devices ;;
    apt) install_native steam-installer || install_native steam-launcher ;;
    pacman) install_native steam ;;
  esac
  have steam || { warn "Native Steam installation failed — aborting."; exit 1; }
fi

# Safe launcher
USER_APPS="${HOME}/.local/share/applications"
SCRIPTS_DIR="${HOME}/scripts"
WRAPPER="${SCRIPTS_DIR}/steam_safe.sh"
mkdir -p "${SCRIPTS_DIR}" "${USER_APPS}"
cat > "${WRAPPER}" <<'EOF'
#!/usr/bin/env bash
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
