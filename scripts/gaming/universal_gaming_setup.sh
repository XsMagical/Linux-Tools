#!/usr/bin/env bash
# =============================================================================
# Team Nocturnal — Universal Gaming Setup
# Author: XsMagical
# Repo: https://github.com/XsMagical/Linux-Tools
#
# What changed (2025-08-14):
# - Bundles aligned to docs: --bundle=lite|normal|full (alias: gaming->normal).
# - Discord: native-first on ALL distros with repo refresh & one retry; Flatpak fallback.
# - Core tools ensured by bundle: Wine, Winetricks, Vulkan tools, MangoHud, GameMode.
# - Normal adds: Steam, Lutris, Heroic, Discord, Proton tools.
# - Full adds: OBS, GOverlay, Gamescope, v4l2loopback.
# - End-of-run status summary with ✅/❌ for EVERY app in this script (native vs Flatpak aware).
# - Flags from your prior script remain; nothing else was removed.
# =============================================================================

# ===== Colors & Banner =====
RED=\"\\033[31m\"; BLUE=\"\\033[34m\"; GREEN=\"\\033[32m\"; RESET=\"\\033[0m\"; BOLD=\"\\033[1m\"; DIM=\"\\033[2m\"
CHECK=\"✅\"; XMARK=\"❌\"

print_banner() {
  printf '%b\\n' \"${RED}████████╗███╗   ██╗${RESET}\"
  printf '%b\\n' \"${RED}╚══██╔══╝████╗  ██║${RESET}\"
  printf '%b\\n' \"${RED}   ██║   ██╔██╗ ██║${RESET}\"
  printf '%b\\n' \"${RED}   ██║   ██║╚██╗██║${RESET}\"
  printf '%b\\n' \"${RED}   ██║   ██║ ╚████║${RESET}\"
  printf '%b\\n' \"${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}\"
  printf '%b\\n' \"${BLUE}----------------------------------------------------------${RESET}\"
  printf '%b\\n' \"${BLUE}   Team-Nocturnal.com Universal Gaming Setup by XsMagical${RESET}\"
  printf '%b\\n\\n' \"${BLUE}----------------------------------------------------------${RESET}\"
}

# ===== Defaults / Flags (kept compatible with prior script) =====
ASSUME_YES=0
VERBOSE=0
DISCORD_MODE=\"native\"        # native|flatpak  (default native-first)
OVERLAYS_MODE=\"none\"         # none|steam|game (kept for future use)
BUNDLE=\"normal\"              # lite|normal|full  (alias: gaming->normal)
# Feature toggles derived from bundle (can be overridden by --no-* flags)
WANT_STEAM=0
WANT_WINE=1
WANT_LUTRIS=0
WANT_HEROIC=0
WANT_GAMEMODE=1
WANT_MANGOHUD=1
WANT_PROTON_TOOLS=0
WANT_OBS=0
WANT_GOVERLAY=0
WANT_GAMESCOPE=0
WANT_V4L2LOOPBACK=0

# Keep optional skip flags for back-compat
# (We won't advertise them, but they still work if you used them before)
# --no-steam|--no-wine|--no-lutris|--no-heroic|--no-gamemode|--no-mangohud

# ===== Helpers =====
log() { printf '%b\\n' \"$*\"; }
have() { command -v \"$1\" >/dev/null 2>&1; }
yesflag() { [ \"$ASSUME_YES\" -eq 1 ] && echo \"-y\" || echo \"\"; }

pm_detect() {
  if have dnf5; then PM=dnf5; OSF=fedora
  elif have dnf; then PM=dnf; OSF=fedora
  elif have apt-get; then PM=apt; OSF=debian
  elif have pacman; then PM=pacman; OSF=arch
  else log \"${RED}Unsupported distro (need dnf/apt/pacman).${RESET}\"; exit 1; fi
}

pkg_install() {
  case \"$PM\" in
    dnf5) sudo dnf5 install -y \"$@\" ;;
    dnf)  sudo dnf install $(yesflag) -y \"$@\" ;;
    apt)  sudo apt-get update && sudo apt-get install $(yesflag) -y \"$@\" ;;
    pacman) sudo pacman -Sy --needed --noconfirm \"$@\" ;;
  esac
}

pkg_remove() {
  case \"$PM\" in
    dnf5) sudo dnf5 remove -y \"$@\" ;;
    dnf)  sudo dnf remove $(yesflag) -y \"$@\" ;;
    apt)  sudo apt-get remove $(yesflag) -y \"$@\" ;;
    pacman) sudo pacman -Rns --noconfirm \"$@\" ;;
  esac
}

# Flatpak helpers (accurate app ID detection)
flatpak_ensure() {
  if ! have flatpak; then pkg_install flatpak; fi
  if ! flatpak remotes | awk '{print $1}' | grep -qx Flathub; then
    sudo flatpak remote-add --if-not-exists Flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}
fp_installed() { flatpak list --app --columns=application | grep -qx \"$1\"; }
fp_install() { flatpak_ensure; sudo flatpak install -y Flathub \"$1\"; }
fp_remove_if_present() { flatpak_ensure; fp_installed \"$1\" && flatpak uninstall -y \"$1\" || true; }

# Quick repo refresh (safe; no full upgrades)
refresh_repos_quick() {
  case \"$PM\" in
    dnf5) sudo dnf5 clean metadata || true; sudo dnf5 clean all || true; sudo dnf5 --refresh makecache || true ;;
    dnf)  sudo dnf clean metadata || true;  sudo dnf clean all || true;  sudo dnf --refresh makecache || true ;;
    apt)  sudo apt-get update || true ;;
    pacman) sudo pacman -Sy || true ;;
  esac
}

# ===== Arg parse =====
RAW_ARGS=(\"$@\")
while [ $# -gt 0 ]; do
  case \"$1\" in
    --verbose) VERBOSE=1 ;;
    -y|--assume-yes|--yes) ASSUME_YES=1 ;;
    --discord=*) DISCORD_MODE=\"${1#*=}\" ;;
    --overlays=*) OVERLAYS_MODE=\"${1#*=}\" ;;
    --bundle=*) BUNDLE=\"${1#*=}\" ;;
    --no-steam) WANT_STEAM=0 ;;
    --no-wine) WANT_WINE=0 ;;
    --no-lutris) WANT_LUTRIS=0 ;;
    --no-heroic) WANT_HEROIC=0 ;;
    --no-gamemode) WANT_GAMEMODE=0 ;;
    --no-mangohud) WANT_MANGOHUD=0 ;;
    *) ;;
  esac
  shift
done

# Bundle → toggles (lite|normal|full); alias gaming->normal for back-compat
case \"$BUNDLE\" in
  gaming|normal)
    WANT_STEAM=1
    WANT_LUTRIS=1
    WANT_HEROIC=1
    WANT_PROTON_TOOLS=1
    WANT_OBS=0
    WANT_GOVERLAY=0
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
  *)
    log \"${RED}Unknown bundle:${RESET} $BUNDLE\"; exit 1 ;;
esac

# ===== Installers =====

install_core_stack() {
  # Wine / Vulkan / MangoHud / GameMode
  case \"$OSF\" in
    fedora)
      pkg_install wine winetricks vulkan-tools mangohud mangohud.i686 gamemode
      # 32-bit Vulkan loader for Steam compatibility
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
  case \"$OSF\" in
    fedora) pkg_install steam ;;
    debian)
      dpkg --print-foreign-architectures | grep -qx i386 || { sudo dpkg --add-architecture i386 && sudo apt-get update; }
      pkg_install steam ;;
    arch)
      if uname -m | grep -qi 'arm'; then log \"${DIM}Skipping Steam on ARM${RESET}\"; else pkg_install steam; fi ;;
  esac
}

install_lutris() {
  case \"$OSF\" in
    fedora|arch|debian) pkg_install lutris || fp_install net.lutris.Lutris ;;
  esac
  # prefer native, remove Flatpak duplicate
  if have lutris; then fp_remove_if_present net.lutris.Lutris || true; fi
}

install_heroic() {
  case \"$OSF\" in
    fedora) pkg_install heroic-games-launcher || fp_install com.heroicgameslauncher.hgl ;;
    arch)   pkg_install heroic-games-launcher-bin || fp_install com.heroicgameslauncher.hgl ;;
    debian) fp_install com.heroicgameslauncher.hgl ;;  # debs are inconsistent
  esac
  if have heroic; then fp_remove_if_present com.heroicgameslauncher.hgl || true; fi
}

# Proton tools: ProtonPlus (Fedora via COPR) + ProtonUp-Qt (Flatpak fallback/any distro)
install_proton_tools() {
  case \"$OSF\" in
    fedora)
      sudo dnf -y copr enable wehagy/protonplus || true
      pkg_install protonplus || true
      ;;
  esac
  fp_install net.davidotek.pupgui2 || true
}

# Discord native-first with refresh & retry; fallback to Flatpak
discord_native_installed() {
  if have rpm; then rpm -q discord &>/dev/null && return 0; fi
  if have dpkg; then dpkg -s discord &>/dev/null && return 0; fi
  if have pacman; then pacman -Q discord &>/dev/null && return 0; fi
  return 1
}

install_discord_native_first() {
  # honor explicit override
  if [ \"$DISCORD_MODE\" = \"flatpak\" ]; then
    fp_install com.discordapp.Discord
    pkg_remove discord || true
    return 0
  fi

  case \"$OSF\" in
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
          # official .deb fallback
          tmpd=\"$(mktemp -d)\"
          ( cd \"$tmpd\" && wget -O discord.deb 'https://discord.com/api/download?platform=linux&format=deb' && \
            sudo apt-get install -y ./discord.deb ) && {
              fp_remove_if_present com.discordapp.Discord || true
              rm -rf \"$tmpd\"
              return 0
            }
          rm -rf \"$tmpd\"
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

# Full bundle extras
install_obs() {
  case \"$OSF\" in
    fedora|debian|arch) pkg_install obs-studio || fp_install com.obsproject.Studio ;;
  esac
  have obs || fp_installed com.obsproject.Studio
}

install_goverlay() {
  # Prefer Flatpak for consistent UI
  fp_install com.github.gicmo.goverlay
}

install_gamescope() {
  case \"$OSF\" in
    fedora|arch|debian) pkg_install gamescope || true ;;
  esac
}

install_v4l2loopback() {
  case \"$OSF\" in
    fedora) pkg_install akmod-v4l2loopback || pkg_install v4l2loopback || true ;;
    debian) pkg_install v4l2loopback-dkms || pkg_install v4l2loopback-utils || true ;;
    arch)   pkg_install v4l2loopback-dkms || true ;;
  esac
}

# ===== Status Summary =====
fp_has() { fp_installed \"$1\"; }
status_line() {
  local ok=\"$1\"; local label=\"$2\"; local detail=\"$3\"
  if [ \"$ok\" -eq 0 ]; then
    echo -e \"${CHECK} ${label}: ${detail}\"
  else
    echo -e \"${XMARK} ${label}: ${detail}\"
  fi
}

print_status() {
  echo \"----------------------------------------------------------\"
  echo -e \" ${BOLD}Install Status Summary${RESET}\"
  echo \"----------------------------------------------------------\"

  # Core stack
  have wine && status_line 0 \"Wine\" \"Native\" || status_line 1 \"Wine\" \"Not installed\"
  have winetricks && status_line 0 \"Winetricks\" \"Native\" || status_line 1 \"Winetricks\" \"Not installed\"

  # Vulkan tools detection (best effort)
  if have vulkaninfo || have vkcube; then
    status_line 0 \"Vulkan tools\" \"Present\"
  else
    status_line 1 \"Vulkan tools\" \"Not installed\"
  fi

  # MangoHud
  if have mangohud; then status_line 0 \"MangoHud\" \"Native\"
  elif fp_has org.freedesktop.Platform.VulkanLayer.MangoHud; then status_line 0 \"MangoHud\" \"Flatpak runtime\"
  else status_line 1 \"MangoHud\" \"Not installed\"; fi

  # GameMode
  have gamemoderun && status_line 0 \"GameMode\" \"Present\" || status_line 1 \"GameMode\" \"Not installed\"

  # Steam
  have steam && status_line 0 \"Steam\" \"Native\" || status_line 1 \"Steam\" \"Not installed\"

  # Lutris
  if have lutris; then status_line 0 \"Lutris\" \"Native\"
  elif fp_has net.lutris.Lutris; then status_line 0 \"Lutris\" \"Flatpak\"
  else status_line 1 \"Lutris\" \"Not installed\"; fi

  # Heroic
  if have heroic; then status_line 0 \"Heroic\" \"Native\"
  elif fp_has com.heroicgameslauncher.hgl; then status_line 0 \"Heroic\" \"Flatpak\"
  else status_line 1 \"Heroic\" \"Not installed\"; fi

  # Proton tools
  if have protonplus; then status_line 0 \"ProtonPlus\" \"Native\"; else status_line 1 \"ProtonPlus\" \"Not installed\"; fi
  if fp_has net.davidotek.pupgui2; then status_line 0 \"ProtonUp-Qt\" \"Flatpak\"; else status_line 1 \"ProtonUp-Qt\" \"Not installed\"; fi

  # Discord
  if discord_native_installed; then status_line 0 \"Discord\" \"Native\"
  elif fp_has com.discordapp.Discord; then status_line 0 \"Discord\" \"Flatpak\"
  else status_line 1 \"Discord\" \"Not installed\"; fi

  # Full extras
  if have obs; then status_line 0 \"OBS Studio\" \"Native\"
  elif fp_has com.obsproject.Studio; then status_line 0 \"OBS Studio\" \"Flatpak\"
  else status_line 1 \"OBS Studio\" \"Not installed\"; fi

  if have goverlay || fp_has com.github.gicmo.goverlay; then
    if have goverlay; then status_line 0 \"GOverlay\" \"Native\"; else status_line 0 \"GOverlay\" \"Flatpak\"; fi
  else status_line 1 \"GOverlay\" \"Not installed\"; fi

  have gamescope && status_line 0 \"Gamescope\" \"Native\" || status_line 1 \"Gamescope\" \"Not installed\"

  # v4l2loopback (best-effort: check module or package)
  if lsmod | grep -q '^v4l2loopback'; then
    status_line 0 \"v4l2loopback\" \"Kernel module loaded\"
  else
    if [ -e /lib/modules/$(uname -r)/extra/v4l2loopback.ko* ] || [ -e /lib/modules/$(uname -r)/updates/dkms/v4l2loopback.ko* ]; then
      status_line 0 \"v4l2loopback\" \"Installed (module not loaded)\"
    else
      status_line 1 \"v4l2loopback\" \"Not installed\"
    fi
  fi

  echo \"----------------------------------------------------------\"
}

# ===== Main =====
main() {
  print_banner
  pm_detect
  [ \"$VERBOSE\" -eq 1 ] && set -x
  refresh_repos_quick

  # Core always (unless explicitly disabled)
  [ \"$WANT_WINE\" -eq 1 ] || [ \"$WANT_GAMEMODE\" -eq 1 ] || [ \"$WANT_MANGOHUD\" -eq 1 ] && install_core_stack

  # Normal / Full components
  [ \"$WANT_STEAM\" -eq 1 ] && install_steam
  [ \"$WANT_LUTRIS\" -eq 1 ] && install_lutris
  [ \"$WANT_HEROIC\" -eq 1 ] && install_heroic
  [ \"$WANT_PROTON_TOOLS\" -eq 1 ] && install_proton_tools

  # Discord (always relevant for normal/full; safe for lite if user wants it via flag)
  install_discord_native_first

  # Full extras
  [ \"$WANT_OBS\" -eq 1 ] && install_obs
  [ \"$WANT_GOVERLAY\" -eq 1 ] && install_goverlay
  [ \"$WANT_GAMESCOPE\" -eq 1 ] && install_gamescope
  [ \"$WANT_V4L2LOOPBACK\" -eq 1 ] && install_v4l2loopback

  print_status
}

main \"$@\"
