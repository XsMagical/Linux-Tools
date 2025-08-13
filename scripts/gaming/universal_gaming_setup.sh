#!/usr/bin/env bash
# Team Nocturnal — Universal Gaming Setup Script by XsMagical

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
  printf '%b\n' "${BLUE}   Team-Nocturnal.com \"Universal Gaming Setup\" by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# -----------------------------------------------------------------------------
# Purpose:
#   Cross‑distro gaming setup with native-first installs and safe defaults.
#   • Removes system‑wide overlay exports (we use GOverlay instead).
#   • Installs Steam (native if supported), Lutris, Heroic, GameMode, MangoHud, Wine, Vulkan tools.
#   • Installs GOverlay (GUI to toggle MangoHud/vkBasalt per game).
#   • Creates a Steam “safe UI” launcher to avoid CEF 0x3035 issues on Wayland/SELinux.
#   • Optionally cleans Flatpak duplicates if a native app is installed.
#
# Distros:
#   Fedora/RHEL (dnf), Ubuntu/Debian (apt), Arch/Manjaro (pacman).
#
# Flags:
#   --discord=auto|native|flatpak     (default: auto)
#   --no-cleanup-flatpak-dupes        (default is to clean duplicates if native exists)
#   --mangohud-defaults               (write a sensible ~/.config/MangoHud/MangoHud.conf)
#   --protonplus                      (Fedora COPR native ProtonPlus if available; otherwise ignored)
#   --protonupqt                      (Install ProtonUp‑Qt via Flatpak)
#   --skip-steam                      (don’t install Steam; still writes safe launcher if Steam present)
#   -y | --yes                        (assume yes for package installs)
#   -v | --verbose                    (more logging)
#
# Notes:
#   • We DO NOT set MangoHud/vkBasalt system‑wide. Use GOverlay or per‑game Steam launch options.
#   • ARM (aarch64): skip native Steam automatically.
# -----------------------------------------------------------------------------

print_banner
set -u

# -------- Globals & helpers --------
LOG_DIR="${HOME}/scripts/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/gaming_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

YES_FLAG=0
VERBOSE=0
DISCORD_MODE="auto"
CLEANUP_DUPES=1
WRITE_MANGOHUD_DEFAULTS=0
WANT_PROTONPLUS=0
WANT_PROTONUPQT=0
SKIP_STEAM=0

have() { command -v "$1" >/dev/null 2>&1; }
log() { printf '%b\n' "${BOLD}==>${RESET} $*"; }
info(){ printf '%b\n' "${DIM} ->${RESET} $*"; }
warn(){ printf '%b\n' "${RED}[!]${RESET} $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --discord=*) DISCORD_MODE="${1#*=}";;
    --no-cleanup-flatpak-dupes) CLEANUP_DUPES=0;;
    --mangohud-defaults) WRITE_MANGOHUD_DEFAULTS=1;;
    --protonplus) WANT_PROTONPLUS=1;;
    --protonupqt) WANT_PROTONUPQT=1;;
    --skip-steam) SKIP_STEAM=1;;
    -y|--yes) YES_FLAG=1;;
    -v|--verbose) VERBOSE=1;;
    -h|--help)
      cat <<EOF
Usage: $0 [options]
  --discord=auto|native|flatpak   (default: auto)
  --no-cleanup-flatpak-dupes      (don’t remove Flatpak duplicates when native exists)
  --mangohud-defaults             (write MangoHud default config)
  --protonplus                    (Fedora: try COPR protonplus)
  --protonupqt                    (install ProtonUp-Qt via Flatpak)
  --skip-steam                    (don’t install Steam)
  -y | --yes                      (assume yes)
  -v | --verbose                  (verbose logs)
EOF
      exit 0;;
    *) warn "Unknown flag: $1";;
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
PM=""
if have dnf; then PM="dnf"
elif have apt; then PM="apt"
elif have pacman; then PM="pacman"
else warn "Unsupported distro (no dnf/apt/pacman)."; exit 1
fi

# Pre-auth sudo
$SUDO -v 2>/dev/null || true

# -------- Flatpak helpers --------
ensure_flatpak() {
  if have flatpak; then return 0; fi
  log "Installing Flatpak runtime…"
  case "$PM" in
    dnf) $SUDO dnf install $DNF_Y -y flatpak || true ;;
    apt) $SUDO apt update || true; $SUDO apt install $APT_Y flatpak || true ;;
    pacman) $SUDO pacman -S $PAC_Y flatpak || true ;;
  esac
}

ensure_flathub() {
  ensure_flatpak
  if flatpak remote-list | awk '{print $1}' | grep -q '^flathub$'; then
    return 0
  fi
  log "Adding Flathub…"
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
}

fp_install() {
  local app="$1"
  ensure_flathub
  info "Flatpak install: ${app}"
  flatpak install -y --noninteractive flathub "${app}" || true
}

fp_remove_if_present() {
  local app="$1"
  if have flatpak && flatpak info "${app}" >/dev/null 2>&1; then
    info "Removing Flatpak duplicate: ${app}"
    flatpak uninstall -y "${app}" || true
  fi
}

# -------- Package installs --------
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

# -------- Enable repos / basics --------
case "$PM" in
  dnf)
    log "Ensuring RPM Fusion (free & nonfree)…"
    if ! rpm -qa | grep -q rpmfusion-free-release; then
      $SUDO dnf install $DNF_Y -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm || true
    fi
    if ! rpm -qa | grep -q rpmfusion-nonfree-release; then
      $SUDO dnf install $DNF_Y -y \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm || true
    fi
    ;;
  apt)
    log "Updating APT metadata…"
    $SUDO apt update || true
    ;;
  pacman)
    log "Refreshing pacman databases…"
    $SUDO pacman -Sy || true
    ;;
esac

# -------- Core gaming stack (native-first) --------
log "Installing core tools (GameMode, MangoHud, Wine, Vulkan)…"
case "$PM" in
  dnf)
    install_native gamemode mangohud mangohud.i686 \
                   wine wine-mono wine-gecko \
                   vulkan-loader vulkan-loader.i686 \
                   mesa-dri-drivers mesa-dri-drivers.i686 \
                   mesa-vulkan-drivers mesa-vulkan-drivers.i686 \
                   lutris
    ;;
  apt)
    install_native gamemode mangohud \
                   wine wine64 winetricks \
                   vulkan-tools mesa-vulkan-drivers \
                   lutris
    ;;
  pacman)
    install_native gamemode mangohud wine winetricks vulkan-tools vulkan-icd-loader lutris
    ;;
esac

# Heroic (Flatpak is simplest/universal)
log "Installing Heroic (Flatpak)…"
fp_install com.heroicgameslauncher.hgl

# GOverlay (Flatpak universal)
log "Installing GOverlay (Flatpak)…"
fp_install com.github.gicmo.goverlay

# Proton managers
if [ $WANT_PROTONUPQT -eq 1 ]; then
  log "Installing ProtonUp‑Qt (Flatpak)…"
  fp_install net.davidotek.pupgui2
fi
if [ $WANT_PROTONPLUS -eq 1 ] && [ "$PM" = "dnf" ]; then
  if have dnf; then
    log "Attempting native ProtonPlus (Fedora COPR)…"
    $SUDO dnf -y copr enable wehagy/protonplus || true
    install_native protonplus
  fi
fi

# Discord
install_discord_native=0
case "$DISCORD_MODE" in
  native) install_discord_native=1 ;;
  flatpak) install_discord_native=0 ;;
  auto)
    if [ "$PM" = "dnf" ]; then install_discord_native=1; else install_discord_native=0; fi
    ;;
esac

if [ $install_discord_native -eq 1 ]; then
  log "Installing Discord (native‑first)…"
  case "$PM" in
    dnf) install_native discord ;;
    apt) warn "No reliable ‘discord’ in Ubuntu/Debian repos — using Flatpak instead."; fp_install com.discordapp.Discord ;;
    pacman) install_native discord || fp_install com.discordapp.Discord ;;
  esac
  if [ $CLEANUP_DUPES -eq 1 ]; then fp_remove_if_present com.discordapp.Discord; fi
else
  log "Installing Discord (Flatpak)…"
  fp_install com.discordapp.Discord
  if [ $CLEANUP_DUPES -eq 1 ]; then remove_native discord; fi
fi

# Steam
if [ $SKIP_STEAM -eq 1 ]; then
  log "Skipping Steam install as requested."
else
  if [ $IS_ARM -eq 1 ]; then
    warn "ARM64 detected — skipping native Steam."
    # Flatpak Steam works on ARM (for Remote Play, etc.)
    log "Installing Steam (Flatpak, ARM)…"
    fp_install com.valvesoftware.Steam
  else
    log "Installing Steam (native‑first)…"
    case "$PM" in
      dnf)
        install_native steam steam-devices steam-selinux
        if [ $CLEANUP_DUPES -eq 1 ]; then fp_remove_if_present com.valvesoftware.Steam; fi
        ;;
      apt)
        # On Ubuntu/Debian the ‘steam-installer’ may exist; fallback to Flatpak if unavailable
        install_native steam-installer || install_native steam-launcher || true
        if ! have steam; then
          warn "Native Steam not found via APT — installing Flatpak Steam."
          fp_install com.valvesoftware.Steam
        else
          [ $CLEANUP_DUPES -eq 1 ] && fp_remove_if_present com.valvesoftware.Steam
        fi
        ;;
      pacman)
        install_native steam || true
        if ! have steam; then
          warn "Native Steam not available — installing Flatpak Steam."
          fp_install com.valvesoftware.Steam
        else
          [ $CLEANUP_DUPES -eq 1 ] && fp_remove_if_present com.valvesoftware.Steam
        fi
        ;;
    esac
  fi
fi

# -------- Steam SAFE LAUNCHER (universal) --------
steam_safe_launcher() {
  log "Creating Steam safe UI launcher (Wayland/SELinux/CEF‑friendly)…"
  local USER_APPS="${HOME}/.local/share/applications"
  local SCRIPTS_DIR="${HOME}/scripts"
  local WRAPPER="${SCRIPTS_DIR}/steam_safe.sh"
  mkdir -p "${SCRIPTS_DIR}" "${USER_APPS}"

  # Wrapper: clears overlay env for UI, forces X11 for CEF, adds stable flags
  cat > "${WRAPPER}" <<'EOF'
#!/usr/bin/env bash
# Steam safe UI launcher — clears overlays, forces X11 for CEF, adds stable flags

# Unset overlay/injection variables so steamwebhelper won't preload them
unset MANGOHUD MANGOHUD_DLSYM ENABLE_VKBASALT VKBASALT_CONFIG_FILE VKBASALT_LOG_FILE
unset LD_PRELOAD DXVK_HUD __GL_THREADED_OPTIMIZATIONS VK_INSTANCE_LAYERS VK_LAYER_PATH
unset ENABLE_GAMESCOPE GAMESCOPE GAMESCOPE_* GAMEDEBUG

export QT_QPA_PLATFORM=xcb
export SDL_VIDEODRIVER=x11

# Optional per‑game overlay env file (not applied to UI because of unsets)
[ -f "$HOME/.config/team-nocturnal/overlay.env" ] && . "$HOME/.config/team-nocturnal/overlay.env" || true

if command -v /usr/bin/steam >/dev/null 2>&1 || command -v /usr/games/steam >/dev/null 2>&1; then
  exec steam -no-cef-sandbox -cef-disable-gpu "$@"
elif command -v flatpak >/dev/null 2>&1 && flatpak info com.valvesoftware.Steam >/dev/null 2>&1; then
  exec flatpak run --env=QT_QPA_PLATFORM=xcb --env=SDL_VIDEODRIVER=x11 \
    com.valvesoftware.Steam -- -no-cef-sandbox -cef-disable-gpu "$@"
else
  echo "Steam not found (native/flatpak)."
  exit 1
fi
EOF
  chmod +x "${WRAPPER}"

  # .desktop entry (prefer native name if present; else distinct Flatpak name)
  if have steam; then
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
    info "Wrote ${USER_APPS}/steam.desktop"
  else
    cat > "${USER_APPS}/steam-flatpak-safe.desktop" <<EOF
[Desktop Entry]
Name=Steam (Flatpak Safe)
Comment=Steam (Flatpak) with safe UI flags
Exec=/home/${USER}/scripts/steam_safe.sh %U
Terminal=false
Type=Application
Icon=steam
Categories=Game;
MimeType=x-scheme-handler/steam;
StartupNotify=false
EOF
    xdg-mime default steam-flatpak-safe.desktop x-scheme-handler/steam 2>/dev/null || true
    info "Wrote ${USER_APPS}/steam-flatpak-safe.desktop"
  fi

  update-desktop-database "${USER_APPS}" 2>/dev/null || true

  # Clean problematic caches once (keeps games)
  rm -rf ~/.steam/steam/{appcache,package,config/htmlcache,steamui} 2>/dev/null || true
  rm -rf ~/.local/share/Steam/{appcache,package,config/htmlcache,steamui} 2>/dev/null || true
}
steam_safe_launcher

# -------- MangoHud defaults (optional) --------
if [ $WRITE_MANGOHUD_DEFAULTS -eq 1 ]; then
  log "Writing MangoHud default config (~/.config/MangoHud/MangoHud.conf)…"
  mkdir -p "${HOME}/.config/MangoHud"
  cat > "${HOME}/.config/MangoHud/MangoHud.conf" <<'EOF'
# Team Nocturnal — sensible MangoHud defaults (tweak with GOverlay)
# Minimal overlay: FPS + frametime; toggle with RShift+F12
fps_limit=0
toggle_hud=RShift+F12
position=top-left
font_size=20
cpu_stats=0
gpu_stats=1
gpu_temp=1
vram=1
fps=1
frametime=1
background_alpha=0.3
EOF
fi

# -------- Duplicate cleanup (Flatpak vs native) --------
if [ $CLEANUP_DUPES -eq 1 ]; then
  # If native present, remove Flatpak duplicates to avoid confusion
  if have steam; then fp_remove_if_present com.valvesoftware.Steam; fi
  case "$PM" in
    dnf|pacman) if have discord; then fp_remove_if_present com.discordapp.Discord; fi ;;
    apt) : ;; # native discord not reliable; we installed Flatpak earlier
  esac
fi

log "All done. Log: ${LOG_FILE}"
info "Launch Steam from your menu (safe launcher is now the default)."
info "Use GOverlay to toggle MangoHud/vkBasalt per game (no system‑wide overlays)."
