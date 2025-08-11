#!/usr/bin/env bash
# =====================================================================================
# Team Nocturnal — Universal Gaming Setup Script
# Works on Fedora/RHEL, Ubuntu/Debian, Arch, and openSUSE
# =====================================================================================
set -euo pipefail

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

# ===== About ========================================================================
# Organized automation to install core Linux gaming tools and control overlays.
# Overlay modes:
#   --overlays=steam   → MangoHud/GameMode/VkBasalt for Steam only (wrapper + desktop override)
#   --overlays=system  → Enable overlays system-wide for all apps (via /etc/profile.d)
#   --overlays=none    → Disable overlays everywhere (removes wrapper & globals)
# The overlay switcher can be run alone and will NOT reinstall packages.

# ===== Helpers ======================================================================
msg()  { printf '%b\n' "${BOLD}==>${RESET} $*"; }
note() { printf '%b\n' " • $*\n"; }
warn() { printf '%b\n' "${RED}WARN:${RESET} $*\n"; }
have() { command -v "$1" >/dev/null 2>&1; }

require_sudo() { if [[ $EUID -ne 0 ]]; then sudo -v; fi; }

detect_pkgmgr() {
  if have dnf; then PKG="dnf"
  elif have apt; then PKG="apt"
  elif have pacman; then PKG="pacman"
  elif have zypper; then PKG="zypper"
  else warn "No known package manager found (dnf/apt/pacman/zypper). Some steps will be skipped."; PKG=""
  fi
}

LOG_DIR="$HOME/scripts/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/gaming_setup_$(date +'%Y%m%d_%H%M%S').log"

# ===== Paths & constants =============================================================
HOME_DIR="$HOME"
LOCAL_DESKTOP="$HOME_DIR/.local/share/applications"
SCRIPTS_DIR="$HOME_DIR/scripts"
WRAPPER="$SCRIPTS_DIR/steam_with_overlays.sh"

# ===== Overlay utilities =============================================================
backup_and_comment_envfile() {
  local f="$1"; [[ -f "$f" ]] || return 0
  require_sudo
  sudo cp -n "$f" "${f}.bak.$(date +%s)" || true
  sudo sed -i -E \
    -e 's/^(export[[:space:]]+)?(MANGOHUD|ENABLE_VKBASALT|VK_INSTANCE_LAYERS|VK_LAYER_PATH|DXVK_HUD|GAMEMODERUNEXEC|__GL_THREADED_OPTIMIZATIONS|WINE_FULLSCREEN_FSR)=.*/# \0 (disabled)/' \
    -e 's/^(MANGOHUD|ENABLE_VKBASALT|VK_INSTANCE_LAYERS|VK_LAYER_PATH|DXVK_HUD|GAMEMODERUNEXEC|__GL_THREADED_OPTIMIZATIONS|WINE_FULLSCREEN_FSR)=.*/# \0 (disabled)/' \
    "$f" || true
  note "Disabled overlay env in: $f"
}

disable_globals() {
  msg "Disabling any global/user overlay variables…"
  for f in \
    /etc/environment \
    /etc/profile \
    /etc/profile.d/tn-gaming-env.sh \
    /etc/profile.d/99-gaming-env.sh \
    "$HOME_DIR/.profile" \
    "$HOME_DIR/.bash_profile" \
    "$HOME_DIR/.bashrc" \
    "$HOME_DIR/.config/environment.d/90-gaming.conf"
  do
    backup_and_comment_envfile "$f"
  done
}

setup_overlays_systemwide() {
  msg "Setting overlays: SYSTEM‑WIDE"
  require_sudo
  sudo install -d -m 755 /etc/profile.d
  sudo bash -c 'cat > /etc/profile.d/tn-gaming-env.sh' <<'EOT'
# Team Nocturnal – Gaming overlays (system-wide)
export MANGOHUD=1
# Enable VkBasalt only if Vulkan implicit layer exists
if [ -d /usr/share/vulkan/implicit_layer.d ] || [ -d /etc/vulkan/implicit_layer.d ]; then
  export ENABLE_VKBASALT=1
fi
EOT
  note "Installed /etc/profile.d/tn-gaming-env.sh (new shells/apps will inherit)"
}

setup_steam_wrapper() {
  mkdir -p "$SCRIPTS_DIR" "$LOCAL_DESKTOP"
  msg "Creating Steam wrapper for overlays: $WRAPPER"
  cat > "$WRAPPER" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
GM=""
if command -v gamemoderun >/dev/null 2>&1; then GM="gamemoderun"; fi
VK_ENV=""
# Enable VkBasalt if any implicit layer dir exists
if [ -d /usr/share/vulkan/implicit_layer.d ] || [ -d /etc/vulkan/implicit_layer.d ] || command -v vkbasalt >/dev/null 2>&1; then
  VK_ENV="ENABLE_VKBASALT=1"
fi
exec env MANGOHUD=1 ${VK_ENV} ${GM} steam "$@"
WRAP
  chmod +x "$WRAPPER"

  # Desktop override
  local sys_desktop="/usr/share/applications/steam.desktop"
  if [[ -f "$sys_desktop" ]]; then
    cp "$sys_desktop" "$LOCAL_DESKTOP/steam.desktop"
  else
    cat > "$LOCAL_DESKTOP/steam.desktop" <<EOF
[Desktop Entry]
Name=Steam
Type=Application
TryExec=steam
Exec=$WRAPPER %U
Icon=steam
Categories=Game;
EOF
  fi
  sed -i -E "s|^Exec=.*|Exec=$WRAPPER %U|g" "$LOCAL_DESKTOP/steam.desktop" || true
  sed -i -E 's/%[Uuf]( +%[Uuf])+/ %U/g' "$LOCAL_DESKTOP/steam.desktop" || true
  update-desktop-database >/dev/null 2>&1 || true
  note "Installed desktop override: $LOCAL_DESKTOP/steam.desktop"
}

remove_steam_wrapper() {
  msg "Removing Steam wrapper & desktop override (if any)…"
  rm -f "$WRAPPER" 2>/dev/null || true
  rm -f "$LOCAL_DESKTOP/steam.desktop" 2>/dev/null || true
}

restart_steam_if_running() {
  if pgrep -x steam >/dev/null 2>&1; then
    msg "Restarting Steam to apply overlay changes…"
    pkill -x steam || true
    (nohup steam >/dev/null 2>&1 & disown) || true
  else
    note "Steam not running; changes will apply next launch."
  fi
}

# ===== Package ops ==================================================================
enable_repos_if_needed() {
  case "$PKG" in
    dnf)
      # RPM Fusion for Fedora
      if have rpm && [[ "$(rpm -E %fedora 2>/dev/null || echo '')" != "" ]]; then
        if ! dnf repolist --enabled 2>/dev/null | grep -qi 'rpmfusion.*free'; then
          msg "Enabling RPM Fusion (free + nonfree)…"
          require_sudo
          sudo dnf -y install \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || true
        fi
      fi
      ;;
    apt)
      require_sudo
      sudo dpkg --add-architecture i386 || true
      sudo apt update || true
      ;;
    pacman) : ;;
    zypper) : ;;
  esac
}

install_gaming_basics() {
  msg "Installing core gaming tooling… (Steam, Lutris, Heroic, MangoHud, GameMode, Wine, Vulkan, vkBasalt)"
  case "$PKG" in
    dnf)
      require_sudo
      sudo dnf -y install steam lutris heroic-games-launcher discord \
        mangohud gamemode vkbasalt wine winetricks \
        vulkan-loader vulkan-tools | tee -a "$LOG_FILE"
      ;;
    apt)
      require_sudo
      sudo apt -y install steam lutris heroic discord \
        mangohud gamemode vkbasalt wine winetricks vulkan-tools | tee -a "$LOG_FILE"
      ;;
    pacman)
      require_sudo
      sudo pacman -Sy --needed --noconfirm \
        steam lutris heroic-games-launcher-bin discord \
        mangohud gamemode vkbasalt wine winetricks vulkan-tools | tee -a "$LOG_FILE"
      ;;
    zypper)
      require_sudo
      sudo zypper -n install -y \
        steam lutris heroic-games-launcher discord \
        mangohud gamemode vkbasalt wine winetricks vulkan-tools | tee -a "$LOG_FILE"
      ;;
    *)
      warn "Skipping installs: unknown package manager."
      ;;
  esac
}

# ===== Arg parsing ==================================================================
print_banner
OVERLAYS_MODE=""     # steam | system | none
VERBOSE=0
NONINTERACTIVE=0

for arg in "$@"; do
  case "$arg" in
    --overlays=steam|--overlays=system|--overlays=none)
      OVERLAYS_MODE="${arg#*=}"
      ;;
    -y|--yes) NONINTERACTIVE=1 ;;
    --verbose) VERBOSE=1 ;;
    *) : ;; # ignore unknown flags (don’t fail)
  endsw
done 2>/dev/null || true

# Enable verbose tracing if requested
if [[ $VERBOSE -eq 1 ]]; then set -x; fi

# ===== Overlay switch path (no reinstall) ===========================================
if [[ -n "${OVERLAYS_MODE}" ]]; then
  case "$OVERLAYS_MODE" in
    steam)
      disable_globals
      setup_steam_wrapper
      restart_steam_if_running
      msg "Overlays set to: STEAM only."
      exit 0
      ;;
    system)
      remove_steam_wrapper
      setup_overlays_systemwide
      restart_steam_if_running
      msg "Overlays set to: SYSTEM‑WIDE."
      exit 0
      ;;
    none)
      disable_globals
      remove_steam_wrapper
      restart_steam_if_running
      msg "Overlays set to: NONE."
      exit 0
      ;;
  esac
fi

# ===== Full install path =============================================================
detect_pkgmgr
enable_repos_if_needed
install_gaming_basics

# Create a sane default MangoHud config for the user (optional)
MH_DIR="$HOME_DIR/.config/MangoHud"
MH_CONF="$MH_DIR/MangoHud.conf"
mkdir -p "$MH_DIR"
if [[ ! -s "$MH_CONF" ]]; then
  cat > "$MH_CONF" <<'EOF'
cpu_stats
gpu_stats
vram
ram
fps
frame_timing
frametime
font_size=24
background_alpha=0.6
position=top-left
EOF
  note "Created default MangoHud config at: $MH_CONF"
fi

msg "All done. Use overlay controls anytime:"
note "  • Steam only:  ${BOLD}$0 --overlays=steam${RESET}"
note "  • System-wide: ${BOLD}$0 --overlays=system${RESET}"
note "  • Disable:     ${BOLD}$0 --overlays=none${RESET}"
