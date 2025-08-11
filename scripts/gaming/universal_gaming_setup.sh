#!/usr/bin/env bash
#
# Team Nocturnal — Universal Gaming Setup (Cross-Distro)
# ------------------------------------------------------
# Sets up a native-first Linux gaming stack with safe fallbacks.
# Works on Fedora/RHEL, Ubuntu/Debian, Arch, and openSUSE.
#
# What it does
# • Ensures needed repos (RPM Fusion / COPR on Fedora; i386 + components on Debian/Ubuntu)
# • Installs core tools: Steam, Lutris, Heroic, Discord, MangoHud, GameMode, Wine, Vulkan tools
# • Installs Proton helpers: ProtonPlus (native on Fedora) and ProtonUp-Qt (Flatpak user fallback)
# • Creates a sane user MangoHud config
# • Prefers native packages; removes Flatpak duplicates if native exists (optional)
#
# Notes
# • Requires sudo; safe to re-run (idempotent behavior)
# • Flatpak is used for apps not available natively on your distro
# • On ARM/ARM64, Steam is skipped (no native package); Heroic/Lutris/Flatpak paths still work
#
# GitHub: https://github.com/XsMagical/Linux-Tools
# ------------------------------------------------------

set -euo pipefail

# ---------- Flags ----------
NATIVE_ONLY=0; FLATPAK_ONLY=0
INSTALL_DISCORD=1; INSTALL_HEROIC=1; INSTALL_STEAM=1; INSTALL_LUTRIS=1
INSTALL_PROTONPLUS=1; INSTALL_PROTONUPQT=1
KEEP_FLATPAK=0; CLEAN_DUPES=1
BUNDLE=""                     # lite | normal | full
OVERLAYS_MODE=""              # steam | system | none | status | repair
OVERLAYS_ONLY=0               # if set, perform overlay action then exit before installs

for arg in "$@"; do
  case "$arg" in
    --native-only)      NATIVE_ONLY=1 ;;
    --flatpak-only)     FLATPAK_ONLY=1 ;;
    --no-discord)       INSTALL_DISCORD=0 ;;
    --no-heroic)        INSTALL_HEROIC=0 ;;
    --no-steam)         INSTALL_STEAM=0 ;;
    --no-lutris)        INSTALL_LUTRIS=0 ;;
    --no-protonplus)    INSTALL_PROTONPLUS=0 ;;
    --no-protonupqt)    INSTALL_PROTONUPQT=0 ;;
    --keep-flatpak)     KEEP_FLATPAK=1 ;;
    --no-clean)         CLEAN_DUPES=0 ;;
    --bundle=lite)      BUNDLE="lite" ;;
    --bundle=normal)    BUNDLE="normal" ;;
    --bundle=full)      BUNDLE="full" ;;
    --overlays=steam)   OVERLAYS_MODE="steam" ;;   # Steam-only overlays
    --overlays=system)  OVERLAYS_MODE="system" ;;  # System-wide overlays
    --overlays=none)    OVERLAYS_MODE="none"  ;;   # Disable overlays
    --overlays=status)  OVERLAYS_MODE="status" ;;  # Show current overlay status
    --overlays=repair)  OVERLAYS_MODE="repair" ;;  # Aggressive cleanup, no install
    --overlay-only)     OVERLAYS_ONLY=1 ;;
    *) echo "Unknown flag: $arg"; exit 2 ;;
  esac
done
[[ $NATIVE_ONLY -eq 1 && $FLATPAK_ONLY -eq 1 ]] && { echo "Cannot use --native-only and --flatpak-only together."; exit 2; }

# ---------- Apply bundle presets (users can still override with individual --no-* flags) ----------
case "$BUNDLE" in
  lite)
    INSTALL_DISCORD=0
    INSTALL_HEROIC=0
    INSTALL_LUTRIS=0
    INSTALL_STEAM=${INSTALL_STEAM:-1}
    INSTALL_PROTONPLUS=0
    INSTALL_PROTONUPQT=1
    ;;
  normal|"")
    # keep defaults (everything enabled)
    ;;
  full)
    # same as normal for now (all features on). Reserved for future extras.
    ;;
esac

# ---------- Banner ----------
RED="\033[31m"; BLUE="\033[34m"; RESET="\033[0m"
print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   https://github.com/XsMagical/${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}
print_banner

# ---------- Detect distro / user ----------
if [[ -r /etc/os-release ]]; then . /etc/os-release; else ID="unknown"; ID_LIKE=""; fi

# Arch guard: skip Steam on ARM
ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|armv7*|armhf|arm64) INSTALL_STEAM=0 ;;
esac

# Ensure sbin is available in PATH (Debian/Ubuntu often need this for runuser)
case ":$PATH:" in *:/usr/sbin:*) :;; *) PATH="/usr/sbin:/sbin:$PATH";; esac

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
REAL_UID="$(id -u "$REAL_USER")"

cmd_exists() { command -v "$1" &>/dev/null; }

# Is a native package installed?
has_pkg() {
  local pkg="$1"
  case "$ID" in
    fedora|rhel|rocky|almalinux|opensuse*|sles) rpm -q "$pkg" &>/dev/null ;;
    ubuntu|linuxmint|pop|zorin|elementary|debian) dpkg -s "$pkg" &>/dev/null ;;
    arch|manjaro|endeavouros) pacman -Q "$pkg" &>/dev/null ;;
    *) return 1 ;;
  esac
}

# ---------- Run as the desktop user (fallback if runuser missing) ----------
run_as_user() {
  local u="${REAL_USER}"
  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$u" -- "$@"
  else
    sudo -u "$u" -- "$@"
  fi
}

# ---------- Flatpak (user scope) ----------
fp_user() {
  local cmd=(flatpak --user "$@")
  if command -v runuser >/dev/null 2>&1; then
    env -i PATH="/usr/sbin:/usr/bin:/bin:/sbin" \
      HOME="$REAL_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" SHELL="/bin/bash" \
      XDG_RUNTIME_DIR="/run/user/$REAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" \
      runuser -u "$REAL_USER" -- "${cmd[@]}"
  else
    env -i PATH="/usr/sbin:/usr/bin:/bin:/sbin" \
      HOME="$REAL_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" SHELL="/bin/bash" \
      XDG_RUNTIME_DIR="/run/user/$REAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" \
      sudo -u "$REAL_USER" -- "${cmd[@]}"
  fi
}

ensure_flatpak_user() {
  [[ $NATIVE_ONLY -eq 1 ]] && return 0
  if ! cmd_exists flatpak; then
    case "$ID" in
      fedora|rhel|rocky|almalinux)       sudo dnf install -y flatpak || true ;;
      arch|manjaro|endeavouros)          sudo pacman -Sy --needed --noconfirm flatpak || true ;;
      ubuntu|linuxmint|pop|zorin|elementary|debian)
                                         sudo apt update && sudo apt install -y flatpak || true ;;
      opensuse*|sles)                    sudo zypper -n install -y flatpak || true ;;
      *) echo "Flatpak not found; skipping Flatpak fallback."; return 1 ;;
    esac
  fi
  fp_user remote-list | grep -q '^flathub' || fp_user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}
pkg_installed_flatpak() { fp_user list --app | awk '{print $1}' | grep -qx "$1"; }
flatpak_install_user()  { ensure_flatpak_user || return 0; pkg_installed_flatpak "$1" && fp_user update -y "$1" || fp_user install -y flathub "$1"; }
flatpak_uninstall_user(){ pkg_installed_flatpak "$1" && fp_user uninstall -y --delete-data "$1" || true; }

fix_flatpak_xdg_env() {
  [[ $NATIVE_ONLY -eq 1 ]] && return 0
  run_as_user mkdir -p "$REAL_HOME/.config/environment.d"
  cat << 'EOF' | run_as_user tee "$REAL_HOME/.config/environment.d/flatpak-xdg.conf" >/dev/null
XDG_DATA_DIRS=$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS
EOF
  run_as_user systemctl --user import-environment XDG_DATA_DIRS 2>/dev/null || true
}

# ---------- Native install (per-package, so one miss doesn't block others) ----------
native_install() {
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0
  case "$ID" in
    fedora|rhel|rocky|almalinux)
      for p in "${pkgs[@]}"; do sudo dnf install -y --skip-unavailable "$p" || true; done
      ;;
    arch|manjaro|endeavouros)
      for p in "${pkgs[@]}"; do sudo pacman -S --needed --noconfirm "$p" || true; done
      ;;
    ubuntu|linuxmint|pop|zorin|elementary|debian)
      for p in "${pkgs[@]}"; do sudo apt install -y "$p" || true; done
      ;;
    opensuse*|sles)
      for p in "${pkgs[@]}"; do sudo zypper -n install -y "$p" || true; done
      ;;
    *)
      return 1 ;;
  esac
}

# ---------- Smart manager: prefer native; uninstall Flatpak if native OK ----------
ensure_app() {
  # usage: ensure_app "Name" "binary" "flatpak.app.id" [native_pkg1 native_pkg2 ...]
  local name="$1" bin="$2" fpid="$3"; shift 3
  local pkgs=("$@")
  # honor feature toggles
  [[ "$name" == "Steam"   && $INSTALL_STEAM   -eq 0 ]] && { echo "[Skip] Steam disabled."; return 0; }
  [[ "$name" == "Discord" && $INSTALL_DISCORD -eq 0 ]] && return 0
  [[ "$name" == "Heroic"  && $INSTALL_HEROIC  -eq 0 ]] && return 0
  [[ "$name" == "Lutris"  && $INSTALL_LUTRIS  -eq 0 ]] && return 0

  local native_present=1
  for p in "${pkgs[@]}"; do has_pkg "$p" && { native_present=0; break; }; done
  cmd_exists "$bin" && native_present=0

  if [[ $FLATPAK_ONLY -eq 0 && $native_present -ne 0 ]]; then
    echo "[Native] Installing $name…"
    native_install "${pkgs[@]}"
    native_present=1
    for p in "${pkgs[@]}"; do has_pkg "$p" && { native_present=0; break; }; done
    cmd_exists "$bin" && native_present=0
  fi

  if [[ $native_present -eq 0 ]]; then
    echo "[Native] $name present."
    if [[ $CLEAN_DUPES -eq 1 && $KEEP_FLATPAK -eq 0 ]]; then
      flatpak_uninstall_user "$fpid" || true
    fi
  else
    [[ $NATIVE_ONLY -eq 1 ]] && { echo "[Skip] $name Flatpak (native-only mode)."; return 0; }
    echo "[Flatpak] Installing $name…"
    flatpak_install_user "$fpid"
  fi
}

# ---------- Debian helpers: enable contrib/non-free and basics ----------
ensure_debian_components() {
  case "${ID_LIKE:-$ID}" in
    *debian*)
      if ! grep -Eq '^\s*deb .* (contrib|non-free)' /etc/apt/sources.list; then
        echo "[Debian] Enabling contrib non-free non-free-firmware…"
        sudo sed -i -E 's/^(deb\s+[^#]*\s+main)(\s|$)/\1 contrib non-free non-free-firmware\2/' /etc/apt/sources.list || true
        sudo apt update -y || true
      fi
      sudo apt install -y util-linux flatpak || true
      ;;
  esac
}

# ======================= Overlay helpers (Steam/system/none) ========================
ov_log() { printf '[Overlays] %s\n' "$*"; }

ov_rm_system_env() {
  sudo rm -f /etc/profile.d/tn-gaming-env.sh /etc/environment.d/tn-gaming-env.conf 2>/dev/null || true
  sudo sed -i '/^MANGOHUD=/d;/^ENABLE_VKBASALT=/d;/^VK_INSTANCE_LAYERS=/d;/^VK_LAYER_PATH=/d' /etc/environment 2>/dev/null || true
}

ov_disable_globals() {
  ov_log "Disabling user & system overlay env…"
  ov_rm_system_env
  sed -i '/MANGOHUD/d;/MANGOHUD_CONFIGFILE/d;/ENABLE_VKBASALT/d;/VK_INSTANCE_LAYERS/d;/VK_LAYER_PATH/d' \
    ~/.profile ~/.bashrc ~/.bash_profile 2>/dev/null || true
  rm -f ~/.config/environment.d/90-gaming.conf ~/.config/environment.d/tn-gaming.conf 2>/dev/null || true
  systemctl --user unset-environment MANGOHUD MANGOHUD_CONFIGFILE ENABLE_VKBASALT VK_INSTANCE_LAYERS VK_LAYER_PATH 2>/dev/null || true
  export -n MANGOHUD MANGOHUD_CONFIGFILE ENABLE_VKBASALT VK_INSTANCE_LAYERS VK_LAYER_PATH 2>/dev/null || true
}

ov_setup_systemwide() {
  ov_log "Enabling system‑wide overlays via /etc/profile.d…"
  sudo install -d -m 755 /etc/profile.d
  sudo bash -c 'cat > /etc/profile.d/tn-gaming-env.sh' <<'EOT'
# Team Nocturnal — Gaming overlays (system-wide)
export MANGOHUD=1
# Enable VkBasalt if Vulkan implicit layer exists
if [ -d /usr/share/vulkan/implicit_layer.d ] || [ -d /etc/vulkan/implicit_layer.d ]; then
  export ENABLE_VKBASALT=1
fi
EOT
}

ov_setup_steam_wrapper() {
  local scripts_dir="$HOME/scripts"
  local wrapper="$scripts_dir/steam_with_overlays.sh"
  local local_desktop="$HOME/.local/share/applications"
  mkdir -p "$scripts_dir" "$local_desktop"
  cat > "$wrapper" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
GM=""
if command -v gamemoderun >/dev/null 2>&1; then GM="gamemoderun"; fi
VK_ENV=""
if command -v vkbasalt >/dev/null 2>&1 || [ -d /usr/share/vulkan/implicit_layer.d ] || [ -d /etc/vulkan/implicit_layer.d ]; then
  VK_ENV="ENABLE_VKBASALT=1"
fi
exec env MANGOHUD=1 ${VK_ENV} ${GM} steam "$@"
WRAP
  chmod +x "$wrapper"

  if [[ -f /usr/share/applications/steam.desktop ]]; then
    cp /usr/share/applications/steam.desktop "$local_desktop/steam.desktop"
  else
    cat > "$local_desktop/steam.desktop" <<EOF
[Desktop Entry]
Name=Steam (TN Overlays)
Type=Application
TryExec=steam
Exec=$wrapper %U
Icon=steam
Categories=Game;
EOF
  fi
  sed -i -E "s|^Exec=.*|Exec=$wrapper %U|g" "$local_desktop/steam.desktop" || true
  sed -i -E 's/%[Uuf]( +%[Uuf])+/ %U/g' "$local_desktop/steam.desktop" || true
  update-desktop-database ~/.local/share/applications >/dev/null 2>&1 || true
}

ov_rm_steam_wrapper() {
  rm -f "$HOME/scripts/steam_with_overlays.sh" "$HOME/.local/share/applications/steam.desktop" 2>/dev/null || true
  update-desktop-database ~/.local/share/applications >/dev/null 2>&1 || true
}

ov_restart_steam_if_running() {
  if pgrep -x steam >/dev/null 2>&1; then
    ov_log "Restarting Steam to apply overlay changes…"
    pkill -x steam || true
    (nohup steam >/dev/null 2>&1 & disown) || true
  fi
}

ov_status() {
  echo "[Overlays] Status:"
  [[ -f /etc/profile.d/tn-gaming-env.sh ]] && echo "  • System‑wide env: /etc/profile.d/tn-gaming-env.sh" || echo "  • No system‑wide env"
  [[ -f "$HOME/scripts/steam_with_overlays.sh" ]] && echo "  • Steam wrapper: ~/scripts/steam_with_overlays.sh" || echo "  • No Steam wrapper"
  systemctl --user show-environment | grep -E 'MANGOHUD|ENABLE_VKBASALT|VK_INSTANCE_LAYERS|VK_LAYER_PATH' || echo "  • No overlay vars in user-manager env"
}

# ===== Overlay‑only path: run and exit before installers when requested ==============
if [[ -n "${OVERLAYS_MODE}" ]]; then
  case "$OVERLAYS_MODE" in
    steam)
      ov_disable_globals
      ov_setup_steam_wrapper
      ov_restart_steam_if_running
      ov_log "Mode set to: STEAM‑ONLY"
      ;;
    system)
      ov_rm_steam_wrapper
      ov_setup_systemwide()
      # ensure current session doesn’t hold on to stale vars
      systemctl --user unset-environment MANGOHUD ENABLE_VKBASALT VK_INSTANCE_LAYERS VK_LAYER_PATH 2>/dev/null || true
      ov_restart_steam_if_running
      ov_log "Mode set to: SYSTEM‑WIDE"
      ;;
    none)
      ov_disable_globals
      ov_rm_steam_wrapper
      ov_restart_steam_if_running
      ov_log "Mode set to: NONE (disabled)"
      ;;
    status)
      ov_status
      ;;
    repair)
      ov_disable_globals
      ov_rm_steam_wrapper
      ov_status
      ;;
  esac
  # If user sent only an overlays command or explicitly asked overlay-only, exit now.
  if [[ $OVERLAYS_ONLY -eq 1 || $# -eq 1 ]]; then
    exit 0
  fi
fi

# ============================ System update & repos =================================
echo "[0/8] Preparing system…"
if [[ $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in
    fedora|rhel|rocky|almalinux)                 sudo dnf upgrade --refresh -y || true ;;
    arch|manjaro|endeavouros)                    sudo pacman -Syu --noconfirm || true ;;
    ubuntu|linuxmint|pop|zorin|elementary|debian) sudo apt update && sudo apt -y full-upgrade || true ;;
    opensuse*|sles)                              sudo zypper -n refresh && sudo zypper -n update -y || true ;;
    *) echo "Unknown distro — relying on Flatpak when needed." ;;
  esac
fi

echo "[1/8] Enabling repositories…"
if [[ $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in
    fedora|rhel|rocky|almalinux)
      if [[ "$ID" == "fedora" ]]; then
        sudo dnf install -y \
          "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
          "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || true
        [[ $INSTALL_PROTONPLUS -eq 1 ]] && sudo dnf copr enable -y wehagy/protonplus || true
        [[ $INSTALL_HEROIC -eq 1     ]] && sudo dnf copr enable -y atim/heroic-games-launcher || true
      else
        sudo dnf install -y epel-release || true
      fi
      ;;
    ubuntu|linuxmint|pop|zorin|elementary)
      sudo apt -y install software-properties-common || true
      sudo add-apt-repository -y universe   || true
      sudo add-apt-repository -y multiverse || true
      sudo add-apt-repository -y restricted || true
      sudo dpkg --add-architecture i386     || true
      sudo apt update || true
      ;;
    debian)
      ensure_debian_components
      sudo dpkg --add-architecture i386 || true
      # Optional Lutris repo on Debian 12 (bookworm).
      if [[ "${VERSION_CODENAME:-}" == "bookworm" ]]; then
        sudo install -d -m 0755 /etc/apt/keyrings
        cat > /tmp/lutris.sources <<'SRC'
Types: deb
URIs: https://download.opensuse.org/repositories/home:/strycore/Debian_12/
Suites: ./
Components:
Signed-By: /etc/apt/keyrings/lutris.gpg
SRC
        sudo mv /tmp/lutris.sources /etc/apt/sources.list.d/lutris.sources
        wget -q -O- https://download.opensuse.org/repositories/home:/strycore/Debian_12/Release.key \
          | sudo gpg --dearmor -o /etc/apt/keyrings/lutris.gpg
      fi
      sudo apt update || true
      ;;
    opensuse*|sles)
      if ! zypper lr | grep -qi "non-oss"; then
        sudo zypper -n ar -f https://download.opensuse.org/tumbleweed/repo/non-oss/ repo-non-oss || true
        sudo zypper -n ref || true
      fi
      ;;
  esac
fi

# ============================= Native base stack ====================================
echo "[2/8] Installing/updating base gaming stack (native)…"
if [[ $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in
    fedora|rhel|rocky|almalinux)
      native_install gamemode mangohud wine wine-mono cabextract p7zip p7zip-plugins unzip curl tar vulkan-tools
      ;;
    arch|manjaro|endeavouros)
      if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        sudo sed -i 's/^#\[multilib\]/[multilib]/; s|^#Include = /etc/pacman.d/mirrorlist|Include = /etc/pacman.d/mirrorlist|' /etc/pacman.conf
        sudo pacman -Sy || true
      fi
      native_install gamemode mangohud wine cabextract p7zip unzip curl tar vulkan-tools
      ;;
    ubuntu|linuxmint|pop|zorin|elementary)
      native_install gamemode mangohud wine winetricks cabextract p7zip-full unzip curl tar vulkan-tools
      ;;
    debian)
      native_install gamemode mangohud wine winetricks cabextract p7zip-full unzip curl tar
      ;;
    opensuse*|sles)
      native_install gamemode mangohud wine cabextract p7zip unzip curl tar vulkan-tools
      ;;
  esac
fi

# ============================= Frontends (smart) ====================================
echo "[3/8] Ensuring launchers…"
ensure_app "Steam"   "steam"   "com.valvesoftware.Steam"         steam steam-installer
ensure_app "Discord" "discord" "com.discordapp.Discord"          discord
ensure_app "Heroic"  "heroic"  "com.heroicgameslauncher.hgl"     heroic heroic-games-launcher heroic-games-launcher-bin
ensure_app "Lutris"  "lutris"  "net.lutris.Lutris"               lutris

# ============================= Proton tools =========================================
echo "[4/8] Proton tools…"
if [[ $INSTALL_PROTONPLUS -eq 1 && $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in fedora) native_install protonplus ;; esac
fi
[[ $INSTALL_PROTONUPQT -eq 1 ]] && flatpak_install_user net.davidotek.pupgui2 || true

# ===================== MangoHud user config + overlay scope (if provided) ===========
echo "[5/8] Configuring MangoHud user defaults…"
MH_DIR="$REAL_HOME/.config/MangoHud"
MH_CONF="$MH_DIR/MangoHud.conf"
run_as_user mkdir -p "$MH_DIR"
cat << 'EOF' | run_as_user tee "$MH_CONF" >/dev/null
cpu_stats
gpu_stats
io_read
io_write
vram
ram
fps
engine_version
frametime
media_player
frame_timing
legacy_layout
font_size=24
background_alpha=0.6
position=top-left
EOF

# If user also passed an overlay mode alongside installs, apply it here.
if [[ -n "${OVERLAYS_MODE}" ]]; then
  case "$OVERLAYS_MODE" in
    steam)
      ov_disable_globals
      ov_setup_steam_wrapper
      ov_restart_steam_if_running
      ;;
    system)
      ov_rm_steam_wrapper
      ov_setup_systemwide
      systemctl --user unset-environment MANGOHUD ENABLE_VKBASALT VK_INSTANCE_LAYERS VK_LAYER_PATH 2>/dev/null || true
      ov_restart_steam_if_running
      ;;
    none)
      ov_disable_globals
      ov_rm_steam_wrapper
      ov_restart_steam_if_running
      ;;
    status|repair) : ;;
  esac
fi

# ============================= XDG fix ==============================================
echo "[6/8] Ensuring Flatpak apps show in menus…"
fix_flatpak_xdg_env

# =========================== Optional duplicate sweep ===============================
if [[ $CLEAN_DUPES -eq 1 && $KEEP_FLATPAK -eq 0 ]]; then
  echo "[7/8] Cleaning duplicate installs (keep native, drop Flatpak)…"
  has_pkg steam  && flatpak_uninstall_user com.valvesoftware.Steam        || true
  has_pkg discord && flatpak_uninstall_user com.discordapp.Discord        || true
  (has_pkg heroic || has_pkg heroic-games-launcher || has_pkg heroic-games-launcher-bin) \
                  && flatpak_uninstall_user com.heroicgameslauncher.hgl   || true
  has_pkg lutris && flatpak_uninstall_user net.lutris.Lutris              || true
fi

# ================================ Verify ============================================
echo "[8/8] Verifying key commands…"
for c in steam lutris mangohud wine; do
  [[ ${c} == "steam"  && $INSTALL_STEAM  -eq 0 ]] && continue
  [[ ${c} == "lutris" && $INSTALL_LUTRIS -eq 0 ]] && continue
  if cmd_exists "$c"; then echo "  ✓ $c"; else echo "  ✗ $c (may be Flatpak-only or skipped)"; fi
done
cmd_exists gamemoderun && echo "  ✓ gamemode (gamemoderun)" || echo "  ✗ gamemode missing"
echo
echo "------------------------------------------------------------"
echo "✅ Done! Native-first gaming stack is ready."
echo "Overlay mode (if set this run): ${OVERLAYS_MODE:-(unchanged)}"
echo "Bundle: ${BUNDLE:-normal}"
echo "Flags: NATIVE_ONLY=$NATIVE_ONLY FLATPAK_ONLY=$FLATPAK_ONLY DISCORD=$INSTALL_DISCORD HEROIC=$INSTALL_HEROIC STEAM=$INSTALL_STEAM LUTRIS=$INSTALL_LUTRIS PPLUS=$INSTALL_PROTONPLUS PUPQT=$INSTALL_PROTONUPQT CLEAN=$CLEAN_DUPES KEEP_FLATPAK=$KEEP_FLATPAK"
echo
echo "Overlay controls (no installs):"
echo "  • Steam only:  $0 --overlays=steam --overlay-only"
echo "  • System-wide: $0 --overlays=system --overlay-only"
echo "  • Disable:     $0 --overlays=none --overlay-only"
echo "  • Status:      $0 --overlays=status --overlay-only"
echo "  • Repair:      $0 --overlays=repair --overlay-only"
echo "------------------------------------------------------------"
