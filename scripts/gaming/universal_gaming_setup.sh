#!/usr/bin/env bash
# =============================================================================
# Team Nocturnal — Universal Gaming Setup
# Author: XsMagical
# Repo: https://github.com/XsMagical/Linux-Tools
#
# Bundles:
#   --bundle=lite   : Core tools only (Wine, Winetricks, Vulkan tools, MangoHud, GameMode)
#   --bundle=normal : lite + Steam, Lutris, Heroic, Discord, Proton tools
#   --bundle=full   : normal + OBS, GOverlay, Gamescope, v4l2loopback
#   (alias: --bundle=gaming == normal)
#
# Changes:
# - Native-first Discord with repo refresh + one retry, Flatpak fallback.
# - Accurate Flatpak ID detection (Heroic, Discord, OBS, GOverlay, MangoHud layer).
# - End-of-run ✅/❌ summary for every app installed by this script.
# - Keeps flags simple: --bundle=..., -y/--assume-yes/--yes, --discord=native|flatpak, --verbose.
#   Legacy flags kept (no-ops if unused): --no-*, --protonplus, --protonupqt, --mangohud-defaults.
# =============================================================================

# ===== Colors & Banner =====
RED="\033[31m"; BLUE="\033[34m"; GREEN="\033[32m"; RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
CHECK="✅"; XMARK="❌"

print_banner() {
  printf '%b
' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b
' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b
' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b
' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b
' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b
' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b
' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b
' "${BLUE}   Team-Nocturnal.com Universal Gaming Setup by XsMagical${RESET}"
  printf '%b

' "${BLUE}----------------------------------------------------------${RESET}"
}

# ===== Defaults / Flags =====
ASSUME_YES=0
VERBOSE=0
DISCORD_MODE="native"       # native|flatpak
BUNDLE="normal"             # lite|normal|full (gaming alias -> normal)

# Derived toggles (bundle-driven; can be overridden by --no-*)
WANT_STEAM=0
WANT_WINE=1
WANT_LUTRIS=0
WANT_HEROIC=0
WANT_GAMEMODE=1
WANT_MANGOHUD=1
WANT_PROTON_TOOLS=0
WANT_OBS=0
WANT_GOVERLAY=0
WRITE_MANGOHUD_DEFAULTS=0
STEAM_CLEAN_CACHE=0
REFRESH_SHORTCUTS=0
WANT_GAMESCOPE=0
WANT_V4L2LOOPBACK=0

# Legacy/optional toggles (kept for compatibility; safe defaults)
WANT_PROTONPLUS=0
WANT_PROTONUPQT=0
WRITE_MANGOHUD_DEFAULTS=0

log() { printf '%b
' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
yesflag() { [ "$ASSUME_YES" -eq 1 ] && echo "-y" || echo ""; }

pm_detect() {
  if   have dnf5;    then PM="dnf5";   OSF="fedora"
  elif have dnf;     then PM="dnf";    OSF="fedora"
  elif have apt-get; then PM="apt";    OSF="debian"
  elif have pacman;  then PM="pacman"; OSF="arch"
  else
    log "${RED}Unsupported distro (need dnf/apt/pacman).${RESET}"
    exit 1
  fi
}

pkg_install() {
  case "$PM" in
    dnf5)   sudo dnf5 install -y "$@" ;;
    dnf)    sudo dnf install $(yesflag) -y "$@" ;;
    apt)    sudo apt-get update && sudo apt-get install $(yesflag) -y "$@" ;;
    pacman) sudo pacman -Sy --needed --noconfirm "$@" ;;
  esac
}

pkg_remove() {
  case "$PM" in
    dnf5)   sudo dnf5 remove -y "$@" ;;
    dnf)    sudo dnf remove $(yesflag) -y "$@" ;;
    apt)    sudo apt-get remove $(yesflag) -y "$@" ;;
    pacman) sudo pacman -Rns --noconfirm "$@" ;;
  esac
}

# ----- Flatpak helpers -----
flatpak_ensure() {
  if ! have flatpak; then pkg_install flatpak; fi
  if ! flatpak remotes | awk '{print $1}' | grep -qx Flathub; then
    sudo flatpak remote-add --if-not-exists Flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}
fp_installed() { flatpak list --app --columns=application | grep -qx "$1"; }
fp_install() { flatpak_ensure; sudo flatpak install -y Flathub "$1"; }
fp_remove_if_present() { flatpak_ensure; fp_installed "$1" && flatpak uninstall -y "$1" || true; }

# ----- Quick repo refresh (safe; no full upgrades) -----
refresh_repos_quick() {
  case "$PM" in
    dnf5)   sudo dnf5 clean metadata || true; sudo dnf5 clean all || true; sudo dnf5 --refresh makecache || true ;;
    dnf)    sudo dnf clean metadata || true;  sudo dnf clean all || true;  sudo dnf --refresh makecache || true ;;
    apt)    sudo apt-get update || true ;;
    pacman) sudo pacman -Sy || true ;;
  esac
}

# ===== Arg parse =====
while [ $# -gt 0 ]; do
  case "$1" in
    --verbose) VERBOSE=1 ;;
    -y|--assume-yes|--yes) ASSUME_YES=1 ;;
    --discord=*) DISCORD_MODE="${1#*=}" ;;
    --bundle=*) BUNDLE="${1#*=}" ;;
    --no-steam) WANT_STEAM=0 ;;
    --no-wine) WANT_WINE=0 ;;
    --no-lutris) WANT_LUTRIS=0 ;;
    --no-heroic) WANT_HEROIC=0 ;;
    --no-gamemode) WANT_GAMEMODE=0 ;;
    --no-mangohud) WANT_MANGOHUD=0 ;;
    --protonplus) WANT_PROTONPLUS=1 ;;
    --protonupqt) WANT_PROTONUPQT=1 ;;
    --mangohud-defaults) WRITE_MANGOHUD_DEFAULTS=1 ;;
    --steam-clean-cache) STEAM_CLEAN_CACHE=1 ;;
    --refresh-shortcuts) REFRESH_SHORTCUTS=1 ;;
    *) ;;
  esac
  shift
done

# Bundle mapping

# ---- Patch-only handler (runs before bundle switch) ----
if [ "$BUNDLE" = "none" ]; then
  log "Patch-only mode: applying maintenance fixes..."
  # Steam cache cleanup if requested
  [ "$STEAM_CLEAN_CACHE" -eq 1 ] && steam_clean_cache
  # Shortcut / MIME / icon cache refresh if requested
  [ "$REFRESH_SHORTCUTS" -eq 1 ] && refresh_shortcuts_all
  # Try to start GameMode if it is installed (no installs in patch-only)
  if systemctl --user list-unit-files 2>/dev/null | grep -q "^gamemoded\.service"; then
    systemctl --user enable --now gamemoded 2>/dev/null || true
  elif systemctl list-unit-files 2>/dev/null | grep -q "^gamemoded\.service"; then
    sudo systemctl enable --now gamemoded 2>/dev/null || true
  fi
  exit 0
fi

case "$BUNDLE" in
  gaming|normal)
    WANT_STEAM=1
    WANT_LUTRIS=1
    WANT_HEROIC=1
    WANT_PROTON_TOOLS=1
    WANT_OBS=0
    WANT_GOVERLAY=0
WRITE_MANGOHUD_DEFAULTS=0
STEAM_CLEAN_CACHE=0
REFRESH_SHORTCUTS=0
    WANT_GAMESCOPE=0
    WANT_V4L2LOOPBACK=0
    ;;
  lite)
    WANT_STEAM=0
    WANT_LUTRIS=0
    WANT_HEROIC=0
    WANT_PROTON_TOOLS=0
    WANT_OBS=0
    WANT_GOVERLAY=0
WRITE_MANGOHUD_DEFAULTS=0
STEAM_CLEAN_CACHE=0
REFRESH_SHORTCUTS=0
    WANT_GAMESCOPE=0
    WANT_V4L2LOOPBACK=0
    ;;
  full)
    WANT_STEAM=1
    WANT_LUTRIS=1
    WANT_HEROIC=1
    WANT_PROTON_TOOLS=1
    WANT_OBS=1
    WANT_GOVERLAY=1
    WANT_GAMESCOPE=1
    WANT_V4L2LOOPBACK=1
    ;;
  *) log "${RED}Unknown bundle:${RESET} $BUNDLE"; exit 1 ;;
esac

# ===== Installers =====
install_core_stack() {
  case "$OSF" in
    fedora)
      pkg_install wine winetricks vulkan-tools mangohud mangohud.i686 gamemode
      pkg_install vulkan-loader.i686 || true
      ;;
    debian)
      dpkg --print-foreign-architectures | grep -qx i386 || { sudo dpkg --add-architecture i386 && sudo apt-get update; }
      pkg_install wine winetricks vulkan-tools mesa-vulkan-drivers mesa-vulkan-drivers:i386 mangohud gamemode
      ;;
    arch)
      pkg_install wine winetricks vulkan-tools mangohud lib32-mangohud gamemode
      ;;
  esac
}

install_steam() {
  case "$OSF" in
    fedora) pkg_install steam ;;
    debian)
      dpkg --print-foreign-architectures | grep -qx i386 || { sudo dpkg --add-architecture i386 && sudo apt-get update; }
      pkg_install steam ;;
    arch)
      if uname -m | grep -qi 'arm'; then log "${DIM}Skipping Steam on ARM${RESET}"; else pkg_install steam; fi ;;
  esac
}

install_lutris() {
  case "$OSF" in
    fedora|arch|debian) pkg_install lutris || fp_install net.lutris.Lutris ;;
  esac
  if have lutris; then fp_remove_if_present net.lutris.Lutris || true; fi
}

install_heroic() {
  case "$OSF" in
    fedora) pkg_install heroic-games-launcher || fp_install com.heroicgameslauncher.hgl ;;
    arch)   pkg_install heroic-games-launcher-bin || fp_install com.heroicgameslauncher.hgl ;;
    debian) fp_install com.heroicgameslauncher.hgl ;;
  esac
  if have heroic; then fp_remove_if_present com.heroicgameslauncher.hgl || true; fi
}

install_proton_tools() {
  case "$OSF" in
    fedora)
      sudo dnf -y copr enable wehagy/protonplus || true
      pkg_install protonplus || true
      ;;
  esac
  fp_install net.davidotek.pupgui2 || true
}

discord_native_installed() {
  if have rpm; then rpm -q discord &>/dev/null && return 0; fi
  if have dpkg; then dpkg -s discord &>/dev/null && return 0; fi
  if have pacman; then pacman -Q discord &>/dev/null && return 0; fi
  return 1
}

install_discord_native_first() {
  if [ "$DISCORD_MODE" = "flatpak" ]; then
    fp_install com.discordapp.Discord
    pkg_remove discord || true
    return 0
  fi

  case "$OSF" in
    fedora)
      if pkg_install discord; then
        fp_remove_if_present com.discordapp.Discord || true
      else
        refresh_repos_quick
        if pkg_install discord; then
          fp_remove_if_present com.discordapp.Discord || true
        else
          fp_install com.discordapp.Discord
        fi
      fi
      ;;
    debian)
      if pkg_install discord; then
        fp_remove_if_present com.discordapp.Discord || true
      else
        refresh_repos_quick
        if pkg_install discord; then
          fp_remove_if_present com.discordapp.Discord || true
        else
          tmpd="$(mktemp -d)"
          ( cd "$tmpd" && wget -O discord.deb 'https://discord.com/api/download?platform=linux&format=deb' && sudo apt-get install -y ./discord.deb ) && {
            fp_remove_if_present com.discordapp.Discord || true
            rm -rf "$tmpd"
            return 0
          }
          rm -rf "$tmpd"
          fp_install com.discordapp.Discord
        fi
      fi
      ;;
    arch)
      refresh_repos_quick
      if pkg_install discord; then
        fp_remove_if_present com.discordapp.Discord || true
      else
        fp_install com.discordapp.Discord
      fi
      ;;
  esac
}

install_obs() {
  case "$OSF" in
    fedora|debian|arch) pkg_install obs-studio || fp_install com.obsproject.Studio ;;
  esac
}

install_goverlay() { fp_install com.github.gicmo.goverlay; }
install_gamescope() { case "$OSF" in fedora|arch|debian) pkg_install gamescope || true ;; esac }
install_v4l2loopback() {
  case "$OSF" in
    fedora) pkg_install akmod-v4l2loopback || pkg_install v4l2loopback || true ;;
    debian) pkg_install v4l2loopback-dkms || pkg_install v4l2loopback-utils || true ;;
    arch)   pkg_install v4l2loopback-dkms || true ;;
  esac
}

# Optional MangoHud defaults
write_mangohud_defaults() {
  mkdir -p "${HOME}/.config/MangoHud"
  cat > "${HOME}/.config/MangoHud/MangoHud.conf" <<'EOF'
# Team Nocturnal sane defaults
fps_limit=0
cpu_temp
gpu_temp
ram
vram
gamemode
gpu_load_change
frame_timing=1
# Add a sensible toggle so users can hide/show overlay
toggle_hud=Shift_R+F12
EOF
}


# ----- Fixes & Maintenance helpers -----
ensure_gamemode_service() {
  # Install GameMode if missing
  if ! rpm -q gamemode >/dev/null 2>&1; then
    log "Installing GameMode..."
    sudo dnf install -y gamemode gamemode.i686 || return 0
  fi

  # Prefer user service on Fedora
  if systemctl --user list-unit-files 2>/dev/null | grep -q "^gamemoded\.service"; then
    systemctl --user daemon-reload || true
    if systemctl --user enable --now gamemoded; then
      log "GameMode (user) running."
      return 0
    fi
  fi

  # Fallback: system service (for other distros/layouts)
  if systemctl list-unit-files 2>/dev/null | grep -q "^gamemoded\.service"; then
    sudo systemctl daemon-reload || true
    if sudo systemctl enable --now gamemoded; then
      log "GameMode (system) running."
      return 0
    fi
  fi

  log "${RED}Warning:${RESET} gamemoded.service not found (user or system)."
}

steam_clean_cache() {
  # optional destructive cleanup of Steam's package cache to fix update loops
  local S="${HOME}/.local/share/Steam"
  rm -rf "${S}/package" 2>/dev/null || true
  rm -f "${S}/config/update_hosts_cached.vdf" 2>/dev/null || true
  echo "Steam package cache cleared."
}

refresh_shortcuts_all() {
  # Rebuild desktop/menu caches for user and system; then rebuild KDE ksycoca
  update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
  sudo update-desktop-database /usr/share/applications 2>/dev/null || true
  update-mime-database "${HOME}/.local/share/mime" 2>/dev/null || true
  sudo update-mime-database /usr/share/mime 2>/dev/null || true
  gtk-update-icon-cache -f "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
  sudo gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
  # KDE/Plasma cache
  rm -f "${HOME}"/.cache/ksycoca6_* 2>/dev/null || true
  command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental 2>/dev/null || true
}
# ===== Status Summary =====
fp_has() { fp_installed "$1"; }
status_line() {
  local ok="$1"; local label="$2"; local detail="$3"
  if [ "$ok" -eq 0 ]; then echo -e "${CHECK} ${label}: ${detail}"; else echo -e "${XMARK} ${label}: ${detail}"; fi
}

print_status() {
  echo "----------------------------------------------------------"
  echo -e " ${BOLD}Install Status Summary${RESET}"
  echo "----------------------------------------------------------"

  have wine && status_line 0 "Wine" "Native" || status_line 1 "Wine" "Not installed"
  have winetricks && status_line 0 "Winetricks" "Native" || status_line 1 "Winetricks" "Not installed"

  if have vulkaninfo || have vkcube; then status_line 0 "Vulkan tools" "Present"; else status_line 1 "Vulkan tools" "Not installed"; fi

  if have mangohud; then status_line 0 "MangoHud" "Native"
  elif fp_has org.freedesktop.Platform.VulkanLayer.MangoHud; then status_line 0 "MangoHud" "Flatpak runtime"
  else status_line 1 "MangoHud" "Not installed"; fi

  have gamemoderun && status_line 0 "GameMode" "Present" || status_line 1 "GameMode" "Not installed"

  have steam && status_line 0 "Steam" "Native" || status_line 1 "Steam" "Not installed"

  if have lutris; then status_line 0 "Lutris" "Native"
  elif fp_has net.lutris.Lutris; then status_line 0 "Lutris" "Flatpak"
  else status_line 1 "Lutris" "Not installed"; fi

  if have heroic; then status_line 0 "Heroic" "Native"
  elif fp_has com.heroicgameslauncher.hgl; then status_line 0 "Heroic" "Flatpak"
  else status_line 1 "Heroic" "Not installed"; fi

  if have protonplus; then status_line 0 "ProtonPlus" "Native"; else status_line 1 "ProtonPlus" "Not installed"; fi
  if fp_has net.davidotek.pupgui2; then status_line 0 "ProtonUp-Qt" "Flatpak"; else status_line 1 "ProtonUp-Qt" "Not installed"; fi

  if discord_native_installed; then status_line 0 "Discord" "Native"
  elif fp_has com.discordapp.Discord; then status_line 0 "Discord" "Flatpak"
  else status_line 1 "Discord" "Not installed"; fi

  if have obs; then status_line 0 "OBS Studio" "Native"
  elif fp_has com.obsproject.Studio; then status_line 0 "OBS Studio" "Flatpak"
  else status_line 1 "OBS Studio" "Not installed"; fi

  if have goverlay || fp_has com.github.gicmo.goverlay; then
    if have goverlay; then status_line 0 "GOverlay" "Native"; else status_line 0 "GOverlay" "Flatpak"; fi
  else status_line 1 "GOverlay" "Not installed"; fi

  have gamescope && status_line 0 "Gamescope" "Native" || status_line 1 "Gamescope" "Not installed"

  if lsmod | grep -q '^v4l2loopback'; then status_line 0 "v4l2loopback" "Kernel module loaded"
  else
    if lsmod | grep -q v4l2loopback || [ -e "/lib/modules/$(uname -r)/extra/v4l2loopback.ko"* ] || [ -e "/lib/modules/$(uname -r)/updates/dkms/v4l2loopback.ko"* ]; then
      status_line 0 "v4l2loopback" "Installed (module not loaded)"
    else
      status_line 1 "v4l2loopback" "Not installed"
    fi
  fi

  echo "----------------------------------------------------------"
}

# ===== Main =====
main() {
  print_banner
  pm_detect
  [ "$VERBOSE" -eq 1 ] && set -x
  refresh_repos_quick

  # Core
  if [ "$WANT_WINE" -eq 1 ] || [ "$WANT_GAMEMODE" -eq 1 ] || [ "$WANT_MANGOHUD" -eq 1 ]; then
    install_core_stack
    ensure_gamemode_service
  fi

  # Normal / Full
  [ "$WANT_STEAM" -eq 1 ] && install_steam
  [ "$WANT_LUTRIS" -eq 1 ] && install_lutris
  [ "$WANT_HEROIC" -eq 1 ] && install_heroic
  [ "$WANT_PROTON_TOOLS" -eq 1 ] && install_proton_tools

  # Discord
  install_discord_native_first

  # Full extras
  [ "$WANT_OBS" -eq 1 ] && install_obs
  [ "$WANT_GOVERLAY" -eq 1 ] && install_goverlay
  [ "$WANT_GAMESCOPE" -eq 1 ] && install_gamescope
  [ "$WANT_V4L2LOOPBACK" -eq 1 ] && install_v4l2loopback

  # Optional MangoHud defaults
  [ "$WRITE_MANGOHUD_DEFAULTS" -eq 1 ] && write_mangohud_defaults
  [ "$STEAM_CLEAN_CACHE" -eq 1 ] && steam_clean_cache
  [ "$REFRESH_SHORTCUTS" -eq 1 ] && refresh_shortcuts_all

  print_status
}

main "$@"
