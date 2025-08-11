#!/usr/bin/env bash
#
# Fedora Gaming Setup Script (Universal) - by XsMagical
# ------------------------------------------------------
# This script automatically installs and configures a complete
# gaming environment on Fedora Linux (native-first approach).
#
# It will:
#   • Enable RPM Fusion repositories (Free + Nonfree).
#   • Enable COPR repositories for ProtonPlus & Heroic Games Launcher.
#   • Install core gaming tools: Steam, Lutris, Heroic, Discord, MangoHud, GameMode, Wine, Vulkan tools, etc.
#   • Prioritize native packages over Flatpak; Flatpaks will be removed if a native version is installed.
#   • Install Proton tools: ProtonPlus (dnf) + ProtonUp-Qt (Flatpak user fallback).
#   • Configure MangoHud globally and create a default config for all games.
#   • Clean up any duplicate apps to avoid conflicts.
#
# Notes:
#   • Requires sudo privileges.
#   • Safe to run multiple times; it will skip already-installed packages and re-install missing ones.
#   • Designed for ALL Fedora spins (GNOME, KDE, etc.).
#
# Usage:
#   mkdir -p ~/scripts
#   nano ~/scripts/fedora_gaming_setup.sh
#   chmod +x ~/scripts/fedora_gaming_setup.sh
#   sudo ~/scripts/fedora_gaming_setup.sh
#
# GitHub: https://github.com/XsMagical/
# ------------------------------------------------------

set -euo pipefail

# -------- Flags --------
NATIVE_ONLY=0; FLATPAK_ONLY=0
INSTALL_DISCORD=1; INSTALL_HEROIC=1; INSTALL_STEAM=1; INSTALL_LUTRIS=1
INSTALL_PROTONPLUS=1; INSTALL_PROTONUPQT=1
KEEP_FLATPAK=0; CLEAN_DUPES=1

for arg in "$@"; do
  case "$arg" in
    --native-only) NATIVE_ONLY=1 ;;
    --flatpak-only) FLATPAK_ONLY=1 ;;
    --no-discord) INSTALL_DISCORD=0 ;;
    --no-heroic) INSTALL_HEROIC=0 ;;
    --no-steam) INSTALL_STEAM=0 ;;
    --no-lutris) INSTALL_LUTRIS=0 ;;
    --no-protonplus) INSTALL_PROTONPLUS=0 ;;
    --no-protonupqt) INSTALL_PROTONUPQT=0 ;;
    --keep-flatpak) KEEP_FLATPAK=1 ;;
    --no-clean) CLEAN_DUPES=0 ;;
    *) echo "Unknown flag: $arg"; exit 2;;
  esac
done
[[ $NATIVE_ONLY -eq 1 && $FLATPAK_ONLY -eq 1 ]] && { echo "Cannot use --native-only and --flatpak-only together."; exit 2; }

# -------- Banner --------
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

# -------- Detect distro / user --------
if [[ -r /etc/os-release ]]; then . /etc/os-release; else ID="unknown"; ID_LIKE=""; fi
REAL_USER="${SUDO_USER:-$USER}"; REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"; REAL_UID="$(id -u "$REAL_USER")"
cmd_exists() { command -v "$1" &>/dev/null; }

# Pkg DB check
has_pkg() {
  local pkg="$1"
  case "$ID" in
    fedora|rhel|rocky|almalinux|opensuse*|sles) rpm -q "$pkg" &>/dev/null ;;
    ubuntu|linuxmint|pop|zorin|elementary|debian) dpkg -s "$pkg" &>/dev/null ;;
    arch|manjaro|endeavouros) pacman -Q "$pkg" &>/dev/null ;;
    *) return 1 ;;
  esac
}

# -------- Flatpak (user scope) --------
fp_user() {
  env -i HOME="$REAL_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" SHELL="/bin/bash" \
    XDG_RUNTIME_DIR="/run/user/$REAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$REAL_UID/bus" \
    runuser -u "$REAL_USER" -- flatpak --user "$@"
}
ensure_flatpak_user() {
  [[ $NATIVE_ONLY -eq 1 ]] && return 0
  if ! cmd_exists flatpak; then
    case "$ID" in
      fedora|rhel|rocky|almalinux) sudo dnf install -y flatpak ;;
      arch|manjaro|endeavouros)    sudo pacman -Sy --needed --noconfirm flatpak ;;
      ubuntu|linuxmint|pop|zorin|elementary|debian) sudo apt update && sudo apt install -y flatpak ;;
      opensuse*|sles)              sudo zypper -n install -y flatpak ;;
      *) echo "Flatpak not found; skipping Flatpak fallback."; return 1 ;;
    esac
  fi
  fp_user remote-list | grep -q '^flathub' || fp_user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}
pkg_installed_flatpak() { fp_user list --app | awk '{print $1}' | grep -qx "$1"; }
flatpak_install_user() { ensure_flatpak_user || return 0; pkg_installed_flatpak "$1" && fp_user update -y "$1" || fp_user install -y flathub "$1"; }
flatpak_uninstall_user() { pkg_installed_flatpak "$1" && fp_user uninstall -y --delete-data "$1" || true; }
fix_flatpak_xdg_env() {
  [[ $NATIVE_ONLY -eq 1 ]] && return 0
  runuser -u "$REAL_USER" -- mkdir -p "$REAL_HOME/.config/environment.d"
  cat << 'EOF' | runuser -u "$REAL_USER" -- tee "$REAL_HOME/.config/environment.d/flatpak-xdg.conf" >/dev/null
XDG_DATA_DIRS=$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS
EOF
  runuser -u "$REAL_USER" -- systemctl --user import-environment XDG_DATA_DIRS 2>/dev/null || true
}

# -------- Helper: native install command per distro --------
native_install() {
  case "$ID" in
    fedora|rhel|rocky|almalinux) sudo dnf install -y --skip-unavailable "$@" ;;
    arch|manjaro|endeavouros)    sudo pacman -Sy --needed --noconfirm "$@" ;;
    ubuntu|linuxmint|pop|zorin|elementary|debian) sudo apt install -y "$@" ;;
    opensuse*|sles)              sudo zypper -n install -y "$@" ;;
    *) return 1 ;;
  esac
}

# -------- Smart manager: prefer native; uninstall Flatpak if native OK --------
ensure_app() {
  # args: <name> <bin> <flatpak_id> <native_pkg1> [native_pkg2...]
  local name="$1" bin="$2" fpid="$3"; shift 3
  local pkgs=("$@")

  [[ "${name}" == "Steam"  && $INSTALL_STEAM  -eq 0 ]] && return 0
  [[ "${name}" == "Discord"&& $INSTALL_DISCORD -eq 0 ]] && return 0
  [[ "${name}" == "Heroic" && $INSTALL_HEROIC -eq 0 ]] && return 0
  [[ "${name}" == "Lutris" && $INSTALL_LUTRIS -eq 0 ]] && return 0

  local native_present=1
  for p in "${pkgs[@]}"; do has_pkg "$p" && { native_present=0; break; }; done
  cmd_exists "$bin" && native_present=0

  if [[ $FLATPAK_ONLY -eq 0 && $native_present -ne 0 ]]; then
    echo "[Native] Installing $name…"
    native_install "${pkgs[@]}" || true
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

# -------- System update --------
echo "[0/8] Preparing system…"
if [[ $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in
    fedora|rhel|rocky|almalinux) sudo dnf upgrade --refresh -y ;;
    arch|manjaro|endeavouros)    sudo pacman -Syu --noconfirm ;;
    ubuntu|linuxmint|pop|zorin|elementary|debian) sudo apt update && sudo apt -y full-upgrade ;;
    opensuse*|sles)              sudo zypper -n refresh && sudo zypper -n update -y ;;
    *) echo "Unknown distro — relying on Flatpak when needed." ;;
  esac
fi

# -------- Repos --------
echo "[1/8] Enabling repositories…"
if [[ $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in
    fedora|rhel|rocky|almalinux)
      if [[ "$ID" == "fedora" ]]; then
        sudo dnf install -y \
          "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
          "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || true
        [[ $INSTALL_PROTONPLUS -eq 1 ]] && sudo dnf copr enable -y wehagy/protonplus || true
        [[ $INSTALL_HEROIC -eq 1 ]] && sudo dnf copr enable -y atim/heroic-games-launcher || true
      else
        sudo dnf install -y epel-release || true
      fi
      ;;
    ubuntu|linuxmint|pop|zorin|elementary)
      sudo apt -y install software-properties-common || true
      sudo add-apt-repository -y universe || true
      sudo add-apt-repository -y multiverse || true
      sudo add-apt-repository -y restricted || true
      sudo dpkg --add-architecture i386 || true
      sudo apt update
      ;;
    debian)
      sudo dpkg --add-architecture i386 || true
      if [[ "${VERSION_CODENAME:-}" == "bookworm" ]]; then
        sudo install -d -m 0755 /etc/apt/keyrings
        echo -e "Types: deb\nURIs: https://download.opensuse.org/repositories/home:/strycore/Debian_12/\nSuites: ./\nComponents: \nSigned-By: /etc/apt/keyrings/lutris.gpg" | sudo tee /etc/apt/sources.list.d/lutris.sources >/dev/null
        wget -q -O- https://download.opensuse.org/repositories/home:/strycore/Debian_12/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/lutris.gpg
      fi
      sudo apt update
      ;;
    opensuse*|sles)
      if ! zypper lr | grep -qi "non-oss"; then
        sudo zypper -n ar -f https://download.opensuse.org/tumbleweed/repo/non-oss/ repo-non-oss || true
        sudo zypper -n ref || true
      fi
      ;;
  esac
fi

# -------- Native base stack --------
echo "[2/8] Installing/updating base gaming stack (native)…"
if [[ $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in
    fedora|rhel|rocky|almalinux)
      native_install gamemode mangohud wine wine-mono cabextract p7zip p7zip-plugins unzip curl tar vulkan-tools || true
      ;;
    arch|manjaro|endeavouros)
      if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        sudo sed -i 's/^#\[multilib\]/[multilib]/; s|^#Include = /etc/pacman.d/mirrorlist|Include = /etc/pacman.d/mirrorlist|' /etc/pacman.conf
        sudo pacman -Sy
      fi
      native_install gamemode mangohud wine cabextract p7zip unzip curl tar vulkan-tools || true
      ;;
    ubuntu|linuxmint|pop|zorin|elementary)
      native_install gamemode mangohud wine winetricks cabextract p7zip-full unzip curl tar vulkan-tools || true
      ;;
    debian)
      native_install gamemode mangohud wine winetricks cabextract p7zip-full unzip curl tar || true
      ;;
    opensuse*|sles)
      native_install gamemode mangohud wine cabextract p7zip unzip curl tar vulkan-tools || true
      ;;
  esac
fi

# -------- Frontends (smart native>flatpak) --------
echo "[3/8] Ensuring launchers…"
[[ $INSTALL_STEAM  -eq 1 && $FLATPAK_ONLY -eq 0 ]] && native_install steam || true
[[ $INSTALL_LUTRIS -eq 1 && $FLATPAK_ONLY -eq 0 ]] && native_install lutris || true
[[ $INSTALL_DISCORD -eq 1 && $FLATPAK_ONLY -eq 0 ]] && native_install discord || true
if [[ $INSTALL_HEROIC -eq 1 && $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in fedora) native_install heroic || true ;; arch|manjaro|endeavouros) native_install heroic-games-launcher || true ;; esac
fi

ensure_app "Steam"   "steam"   "com.valvesoftware.Steam"            steam
ensure_app "Discord" "discord" "com.discordapp.Discord"             discord
# Heroic has multiple native names across distros
ensure_app "Heroic"  "heroic"  "com.heroicgameslauncher.hgl"        heroic heroic-games-launcher heroic-games-launcher-bin
ensure_app "Lutris"  "lutris"  "net.lutris.Lutris"                  lutris

# -------- Proton tools --------
echo "[4/8] Proton tools…"
if [[ $INSTALL_PROTONPLUS -eq 1 && $FLATPAK_ONLY -eq 0 ]]; then
  case "$ID" in fedora) native_install protonplus || true ;; esac
fi
[[ $INSTALL_PROTONUPQT -eq 1 ]] && flatpak_install_user net.davidotek.pupgui2 || true

# -------- MangoHud + env --------
echo "[5/8] Configuring MangoHud + global env…"
ENV_FILE="/etc/environment"; grep -q '^MANGOHUD=1' "$ENV_FILE" || echo "MANGOHUD=1" | sudo tee -a "$ENV_FILE" >/dev/null
MH_DIR="$REAL_HOME/.config/MangoHud"; MH_CONF="$MH_DIR/MangoHud.conf"
runuser -u "$REAL_USER" -- mkdir -p "$MH_DIR"
cat << 'EOF' | runuser -u "$REAL_USER" -- tee "$MH_CONF" >/dev/null
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

# -------- XDG fix --------
echo "[6/8] Ensuring Flatpak apps show in menus…"; fix_flatpak_xdg_env

# -------- Optional duplicate sweep (safety: only removes Flatpak if native confirmed) --------
if [[ $CLEAN_DUPES -eq 1 && $KEEP_FLATPAK -eq 0 ]]; then
  echo "[7/8] Cleaning duplicate installs (keep native, drop Flatpak)…"
  has_pkg steam   && flatpak_uninstall_user com.valvesoftware.Steam || true
  has_pkg discord && flatpak_uninstall_user com.discordapp.Discord || true
  (has_pkg heroic || has_pkg heroic-games-launcher || has_pkg heroic-games-launcher-bin) && flatpak_uninstall_user com.heroicgameslauncher.hgl || true
  has_pkg lutris  && flatpak_uninstall_user net.lutris.Lutris || true
fi

# -------- Verify --------
echo "[8/8] Verifying key commands…"
for c in steam lutris mangohud wine; do
  [[ ${c} == "steam" && $INSTALL_STEAM -eq 0 ]] && continue
  [[ ${c} == "lutris" && $INSTALL_LUTRIS -eq 0 ]] && continue
  if cmd_exists "$c"; then echo "  ✓ $c"; else echo "  ✗ $c (may be Flatpak-only or skipped)"; fi
done
cmd_exists gamemoderun && echo "  ✓ gamemode (gamemoderun)" || echo "  ✗ gamemode missing"

echo
echo "------------------------------------------------------------"
echo "✅ Done! Native-first gaming stack is ready."
echo "Flags: NATIVE_ONLY=$NATIVE_ONLY FLATPAK_ONLY=$FLATPAK_ONLY DISCORD=$INSTALL_DISCORD HEROIC=$INSTALL_HEROIC STEAM=$INSTALL_STEAM LUTRIS=$INSTALL_LUTRIS PPLUS=$INSTALL_PROTONPLUS PUPQT=$INSTALL_PROTONUPQT CLEAN=$CLEAN_DUPES KEEP_FLATPAK=$KEEP_FLATPAK"
echo "------------------------------------------------------------"
