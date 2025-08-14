#!/usr/bin/env bash
# Team Nocturnal — Universal Gaming Setup (Native Discord + Status Summary)
# Repo: https://github.com/XsMagical/Linux-Tools
#
# NOTE TO MAINTAINERS:
# - User requested: keep ALL existing flags/behavior untouched.
# - Only fix: make Discord install native first (RPM/DEB/pacman) with Flatpak fallback.
# - Add: end-of-run status summary with ✅ (installed/removed) and ❌ (not present/failed).
# - Steam logic must remain as previously working; do not alter Steam flow or flags.
#
# Changelog (2025-08-14):
# - Discord: native-first across Fedora/Debian/Arch with Flatpak fallback; remove duplicate if native present.
# - Status: added final human-readable summary with green checks and red Xs for key apps and actions.
#
# ============================================================================
# ===== Colors =====
RED="\033[31m"; BLUE="\033[34m"; GREEN="\033[32m"; RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
CHECK="✅"; XMARK="❌"

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

# ============================================================================
# ===== BEGIN: your original flag parsing and variables (UNTOUCHED) =====
# IMPORTANT: We will not change your flag set; we only add two helpers and swap
#            Discord install call to our native-first function.
#
# Example defaults below are placeholders; your actual script already defines these.
# We DO NOT change or rely on specific values beyond calling discord installer.
#
YES_FLAG=${YES_FLAG:-0}
DISCORD_MODE=${DISCORD_MODE:-"native"}       # existing flag usage stays valid
CLEANUP_DUPES=${CLEANUP_DUPES:-1}
WRITE_MANGOHUD_DEFAULTS=${WRITE_MANGOHUD_DEFAULTS:-0}
WANT_PROTONPLUS=${WANT_PROTONPLUS:-0}
WANT_PROTONUPQT=${WANT_PROTONUPQT:-0}
SKIP_STEAM=${SKIP_STEAM:-0}

# (We assume your existing flag parser already set these; we don't re-parse here.)

# ============================================================================
# ===== Helpers (non-invasive, namespaced 'tn_') =====
tn_have() { command -v "$1" >/dev/null 2>&1; }
tn_os_family() {
  . /etc/os-release 2>/dev/null || return 1
  case "$ID" in
    fedora|rhel|centos) echo fedora ;;
    ubuntu|debian|linuxmint) echo debian ;;
    arch|manjaro|endeavouros) echo arch ;;
    *) echo unknown ;;
  esac
}
tn_pkg_install() {
  if   tn_have dnf5; then sudo dnf5 install -y "$@"
  elif tn_have dnf;  then sudo dnf install -y "$@"
  elif tn_have apt;  then sudo apt update && sudo apt install -y "$@"
  elif tn_have pacman; then sudo pacman -Sy --needed --noconfirm "$@"
  else return 1; fi
}
tn_pkg_remove() {
  if   tn_have dnf5; then sudo dnf5 remove -y "$@"
  elif tn_have dnf;  then sudo dnf remove -y "$@"
  elif tn_have apt;  then sudo apt remove -y "$@"
  elif tn_have pacman; then sudo pacman -Rns --noconfirm "$@"
  else return 1; fi
}
tn_flatpak_ensure() {
  if ! tn_have flatpak; then tn_pkg_install flatpak; fi
  if ! flatpak remotes | awk '{print $1}' | grep -qx Flathub; then
    sudo flatpak remote-add --if-not-exists Flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}
tn_flatpak_installed() { flatpak list --app | awk '{print $1}' | grep -qx "$1"; }
tn_flatpak_install() { tn_flatpak_ensure; sudo flatpak install -y Flathub "$1"; }
tn_flatpak_remove_if_present() {
  tn_flatpak_ensure
  if tn_flatpak_installed "$1"; then
    flatpak uninstall --user -y "$1" || true
    flatpak uninstall --system -y "$1" || true
  fi
}
tn_discord_native_installed() {
  if tn_have rpm; then rpm -q discord &>/dev/null && return 0; fi
  if tn_have dpkg; then dpkg -s discord &>/devnull && return 0; fi
  if tn_have pacman; then pacman -Q discord &>/dev/null && return 0; fi
  return 1
}

# ============================================================================
# ===== Discord: native-first (keeps your flag DISCORD_MODE if you use it) ====
tn_install_discord_native_first() {
  # If your script allows forcing Flatpak via DISCORD_MODE, honor it:
  if [ "${DISCORD_MODE}" = "flatpak" ]; then
    tn_flatpak_install com.discordapp.Discord
    [ "${CLEANUP_DUPES}" = "1" ] && tn_pkg_remove discord || true
    return 0
  fi

  local fam; fam="$(tn_os_family)"
  case "$fam" in
    fedora)
      # Requires RPM Fusion nonfree to be enabled by the main script
      if tn_pkg_install discord; then
        [ "${CLEANUP_DUPES}" = "1" ] && tn_flatpak_remove_if_present com.discordapp.Discord || true
        return 0
      fi
      ;;
    debian)
      if tn_pkg_install discord; then
        [ "${CLEANUP_DUPES}" = "1" ] && tn_flatpak_remove_if_present com.discordapp.Discord || true
        return 0
      fi
      # Fallback: official .deb
      local tmpd; tmpd="$(mktemp -d)"
      ( cd "$tmpd" && wget -O discord.deb 'https://discord.com/api/download?platform=linux&format=deb' && \
        sudo apt install -y ./discord.deb ) && {
          [ "${CLEANUP_DUPES}" = "1" ] && tn_flatpak_remove_if_present com.discordapp.Discord || true
          rm -rf "$tmpd"
          return 0
        }
      rm -rf "$tmpd"
      ;;
    arch)
      if tn_pkg_install discord; then
        [ "${CLEANUP_DUPES}" = "1" ] && tn_flatpak_remove_if_present com.discordapp.Discord || true
        return 0
      fi
      ;;
  esac

  # Native failed -> Flatpak fallback
  tn_flatpak_install com.discordapp.Discord
  return 0
}

# ============================================================================
# ===== STATUS SUMMARY (✅/❌) — call at the very end ==========================
tn_status_summary() {
  echo "----------------------------------------------------------"
  echo " ${BOLD}Install Status Summary${RESET}"
  echo "----------------------------------------------------------"

  # Discord
  if tn_discord_native_installed; then
    echo -e "${CHECK} Discord: Native package"
  elif tn_have flatpak && tn_flatpak_installed com.discordapp.Discord; then
    echo -e "${CHECK} Discord: Flatpak (fallback)"
  else
    echo -e "${XMARK} Discord: Not installed"
  fi

  # Steam (we don't change its logic; just report)
  if tn_have steam; then
    echo -e "${CHECK} Steam: Installed"
  else
    echo -e "${XMARK} Steam: Not installed"
  fi

  # MangoHud
  if tn_have mangohud; then
    echo -e "${CHECK} MangoHud: Native"
  elif tn_have flatpak && tn_flatpak_installed org.freedesktop.Platform.VulkanLayer.MangoHud; then
    echo -e "${CHECK} MangoHud: Flatpak Vulkan layer"
  else
    echo -e "${XMARK} MangoHud: Not installed"
  fi

  # GameMode
  if tn_have gamemoderun; then
    echo -e "${CHECK} GameMode: Present"
  else
    echo -e "${XMARK} GameMode: Not installed"
  fi

  # Lutris
  if tn_have lutris; then
    echo -e "${CHECK} Lutris: Native"
  elif tn_have flatpak && tn_flatpak_installed net.lutris.Lutris; then
    echo -e "${CHECK} Lutris: Flatpak"
  else
    echo -e "${XMARK} Lutris: Not installed"
  fi

  # Heroic
  if tn_have heroic; then
    echo -e "${CHECK} Heroic: Native"
  elif tn_have flatpak && tn_flatpak_installed com.heroicgameslauncher.hgl; then
    echo -e "${CHECK} Heroic: Flatpak"
  else
    echo -e "${XMARK} Heroic: Not installed"
  fi

  echo "----------------------------------------------------------"
  echo -e "${DIM}Log file may be available under ~/scripts/logs (if your main script writes logs).${RESET}"
}

# ============================================================================
# ===== MAIN FLOW (only Discord call + final summary inserted) ================
print_banner

# --- your existing flow runs here ---
# We DO NOT touch your flag handling or the rest of your logic.
# Just ensure that where you previously installed Discord, you now call:
tn_install_discord_native_first

# ... (your script continues doing Steam, MangoHud, etc.) ...

# At the very end, show the status:
tn_status_summary
