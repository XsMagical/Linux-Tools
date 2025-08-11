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
