#!/usr/bin/env bash
# ==============================================================================
# Team Nocturnal — Universal Gaming Setup Script
# Author: XsMagical
# Version: Native Discord
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
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal Gaming Setup by XsMagical${RESET}"
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
DISCORD_MODE="native"
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
else
  warn "No supported package manager found (dnf5/dnf/apt/pacman)."
  exit 1
fi

# Basic install helpers
install_native() {
  case "$PM" in
    dnf5) $SUDO dnf5 install -y "$@" ;;
    dnf)  $SUDO dnf install $DNF_Y -y "$@" ;;
    apt)  $SUDO apt update && $SUDO apt install $APT_Y -y "$@" ;;
    pacman) $SUDO pacman -Sy $PAC_Y --needed "$@" ;;
  esac
}

remove_native() {
  case "$PM" in
    dnf5) $SUDO dnf5 remove -y "$@" ;;
    dnf)  $SUDO dnf remove $DNF_Y -y "$@" ;;
    apt)  $SUDO apt remove $APT_Y -y "$@" ;;
    pacman) $SUDO pacman -Rns $PAC_Y "$@" ;;
  esac
}

ensure_flatpak() {
  if ! have flatpak; then
    install_native flatpak
  fi
  if ! flatpak remotes | awk '{print $1}' | grep -qx Flathub; then
    $SUDO flatpak remote-add --if-not-exists Flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}

fp_install() {
  ensure_flatpak
  if ! flatpak list --app | awk '{print $1}' | grep -qx "$1"; then
    $SUDO flatpak install -y Flathub "$1"
  fi
}

fp_remove_if_present() {
  ensure_flatpak
  if flatpak list --app | awk '{print $1}' | grep -qx "$1"; then
    flatpak uninstall --user -y "$1" || true
    flatpak uninstall --system -y "$1" || true
  fi
}

# Enable repos
case "$PM" in
  dnf5)
    log "Enabling multilib and RPM Fusion (dnf5)…"
    $SUDO dnf5 install -y dnf5-plugins
    $SUDO dnf5 config enable fedora-multilib || true
    $SUDO dnf5 install $DNF_Y -y       https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    $SUDO dnf5 install $DNF_Y -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
    ;;
  dnf)
    log "Enabling multilib and RPM Fusion (dnf)…"
    $SUDO dnf install -y dnf-plugins-core
    $SUDO dnf config-manager --set-enabled fedora-modular updates-modular || true
    $SUDO dnf install $DNF_Y -y       https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    $SUDO dnf install $DNF_Y -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
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
    install_native gamemode mangohud mangohud.i686 \
      wine winetricks vulkan-tools vulkan-loader.i686 \
      lutris obs-studio
    ;;
  apt)
    install_native gamemode mangohud wine winetricks vulkan-tools \
      mesa-vulkan-drivers mesa-vulkan-drivers:i386 lutris obs-studio
    ;;
  pacman)
    install_native gamemode mangohud lib32-mangohud \
      wine winetricks vulkan-tools lutris obs-studio
    ;;
esac

# Flatpak fallback apps
fp_install com.heroicgameslauncher.hgl
fp_install com.github.gicmo.goverlay
fp_install com.obsproject.Studio
# (Discord handled below with native-first logic)

# Proton tools
[ $WANT_PROTONUPQT -eq 1 ] && fp_install net.davidotek.pupgui2
[ $WANT_PROTONPLUS -eq 1 ] && { [ "$PM" = "dnf5" ] || [ "$PM" = "dnf" ]; } && $SUDO dnf copr enable -y wehagy/protonplus && install_native protonplus || true

# Discord install (native-first by default; flatpak fallback)
if [ "$DISCORD_MODE" = "flatpak" ]; then
  fp_install com.discordapp.Discord
  [ $CLEANUP_DUPES -eq 1 ] && remove_native discord || true
else
  if install_native discord; then
    [ $CLEANUP_DUPES -eq 1 ] && fp_remove_if_present com.discordapp.Discord || true
  else
    fp_install com.discordapp.Discord
  fi
fi

# Steam (native only, no steam-selinux)
if [ $SKIP_STEAM -eq 0 ]; then
  if [ $IS_ARM -eq 1 ]; then
    warn "ARM detected — skipping Steam."
  else
    case "$PM" in
      dnf5|dnf)
        install_native steam
        ;;
      apt)
        dpkg --print-foreign-architectures | grep -qx i386 || { $SUDO dpkg --add-architecture i386 && $SUDO apt update; }
        install_native steam
        ;;
      pacman)
        install_native steam
        ;;
    esac
  fi
else
  log "Skipping Steam per flag."
fi

# Optional MangoHud defaults
if [ $WRITE_MANGOHUD_DEFAULTS -eq 1 ]; then
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
fi

# Create a safe Steam launcher wrapper (forces X11, disables CEF GPU)
USER="${USER:-$(id -un)}"
mkdir -p "/home/${USER}/scripts" "/home/${USER}/.local/share/applications"
WRAPPER="/home/${USER}/scripts/steam_safe.sh"
USER_APPS="/home/${USER}/.local/share/applications"

cat > "${WRAPPER}" <<'EOF'
#!/usr/bin/env bash
# Steam "safe" launcher for systems where CEF GPU / Wayland causes issues
export __GL_SHADER_DISK_CACHE=1
export __GL_THREADED_OPTIMIZATIONS=1
export __GL_GSYNC_ALLOWED=0
export __GL_VRR_ALLOWED=0
export MANGOHUD_DIR="${HOME}/.config/MangoHud"

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
Comment=Application for managing and playing games
Exec=/home/${USER}/scripts/steam_safe.sh %U
Terminal=false
Type=Application
Icon=steam
Categories=Game;
MimeType=x-scheme-handler/steam;
StartupNotify=false
EOF
