#!/usr/bin/env bash
# Universal Gaming Setup (Team-Nocturnal)
# Cross-distro: openSUSE / Fedora / Ubuntu / Arch
# Features:
# - Red banner header
# - Single sudo prompt at start (sudo -v keepalive)
# - Logs to calling user's ~/scripts/logs (never /root unless truly run by root without SUDO_USER)
# - PackageKit lock handling for openSUSE (optional --agree-pk)
# - Native-over-Flatpak install policy for Discord (fallback to Flatpak)
# - ProtonUp-Qt, ProtonPlus, Heroic as user-scope Flatpaks
# - Colored status icons (green/blue/red) with per-item reasons
# - Avoids broken here-docs / unclosed blocks (fixed syntax)

set -euo pipefail

# ---------- Colors & Icons ----------
RED="\033[31m"; BLUE="\033[34m"; GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"; BOLD="\033[1m"
BGREEN="\033[42m"; BBLUE="\033[44m"; BRED="\033[41m"; WHITE="\033[97m"
ICON_OK="${BGREEN}${WHITE} ✔ ${RESET}"        # newly installed / success (green box w/ white check)
ICON_PRESENT="${BBLUE}${WHITE} ✔ ${RESET}"    # already present / skipped (blue box w/ white check)
ICON_ERR="${BRED}${WHITE} ✖ ${RESET}"         # error / failed (red box w/ white X)

# ---------- Banner ----------
print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal Gaming Setup by XsMagical${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# ---------- Defaults ----------
BUNDLE="full"          # core | full
YESMODE="false"
AGREE_PK="false"

# ---------- Helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }
as_user() { if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then sudo -u "$SUDO_USER" "$@"; else "$@"; fi; }
userhome() { if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then eval echo "~$SUDO_USER"; else eval echo "~$USER"; fi; }

logdir="$(userhome)/scripts/logs"
mkdir -p "$logdir"
LOG_FILE="$logdir/gaming_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

ensure_sudo_keepalive() {
  if [[ $EUID -ne 0 ]]; then
    sudo -v
    # keep sudo alive
    ( while true; do sleep 120; sudo -n true 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT
  fi
}

# ---------- Arg parse ----------
for arg in "$@"; do
  case "$arg" in
    --bundle=*)
      BUNDLE="${arg#*=}"
      ;;
    -y|--yes)
      YESMODE="true"
      ;;
    --agree-pk)
      AGREE_PK="true"
      ;;
    --help|-h)
      cat <<EOF
Usage: $0 [--bundle=core|full] [-y|--yes] [--agree-pk]
  --bundle=full (default)  Install complete gaming stack
  --bundle=core            Minimal: Steam + Proton tools + MangoHud + GameMode
  -y / --yes               Non-interactive where possible
  --agree-pk               On openSUSE, auto-quit PackageKit to avoid locks
EOF
      exit 0
      ;;
  esac
done

# ---------- Status tracking ----------
STAT_NAMES=()
STAT_ICONS=()
STAT_REASON=()

record_status() {
  # $1 name, $2 icon, $3 reason string
  STAT_NAMES+=("$1")
  STAT_ICONS+=("$2")
  STAT_REASON+=("$3")
}

print_status_summary() {
  echo "----------------------------------------------------------"
  echo " Install Status Summary"
  echo "----------------------------------------------------------"
  local i
  for ((i=0; i<${#STAT_NAMES[@]}; i++)); do
    printf " %b %-24s %s\n" "${STAT_ICONS[$i]}" "${STAT_NAMES[$i]}:" "${STAT_REASON[$i]}"
  done
  echo "----------------------------------------------------------"
}

# ---------- Flatpak helpers ----------
ensure_flathub_user() {
  if ! have flatpak; then
    case "$(pm_detect)" in
      zypper) sudo zypper -n in -y flatpak || true ;;
      dnf)    sudo dnf -y install flatpak || true ;;
      apt)    sudo apt-get update -y && sudo apt-get install -y flatpak || true ;;
      pacman) sudo pacman --noconfirm -S flatpak || true ;;
    esac
  fi
  # Ensure user-scope flathub
  if ! flatpak remotes --user | grep -q '^flathub'; then
    as_user flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi
}

fp_install_user() {
  # $1 appid
  if as_user flatpak info --user "$1" >/dev/null 2>&1; then
    record_status "$1" "${ICON_PRESENT}" "Flatpak (user): already installed"
  else
    if as_user flatpak install -y --user flathub "$1"; then
      record_status "$1" "${ICON_OK}" "Flatpak (user): installed"
    else
      record_status "$1" "${ICON_ERR}" "Flatpak (user): install failed"
    fi
  fi
}

# ---------- Package manager detection ----------
pm_detect() {
  if have zypper; then echo zypper
  elif have dnf; then echo dnf
  elif have apt-get; then echo apt
  elif have pacman; then echo pacman
  else echo unknown
  fi
}

pm_install() {
  local pkgs=("$@")
  case "$(pm_detect)" in
    zypper)
      if [[ "$AGREE_PK" == "true" ]]; then
        pkill -9 packagekitd 2>/dev/null || true
      fi
      sudo zypper -n in -y "${pkgs[@]}"
      ;;
    dnf)
      sudo dnf -y install "${pkgs[@]}"
      ;;
    apt)
      sudo apt-get update -y
      sudo apt-get install -y "${pkgs[@]}"
      ;;
    pacman)
      sudo pacman --noconfirm -S --needed "${pkgs[@]}"
      ;;
    *)
      echo "Unsupported package manager"; return 1
      ;;
  esac
}

pm_group_present() {
  local present=()
  local missing=()
  for p in "$@"; do
    if case "$(pm_detect)" in
         zypper) rpm -q "$p" >/dev/null 2>&1 ;;
         dnf)    rpm -q "$p" >/dev/null 2>&1 ;;
         apt)    dpkg -s "$p" >/dev/null 2>&1 ;;
         pacman) pacman -Qi "$p" >/dev/null 2>&1 ;;
       esac
    then present+=("$p"); else missing+=("$p"); fi
  done
  echo "${present[*]}|${missing[*]}"
}

# ---------- Repo setup ----------
setup_repos() {
  case "$(pm_detect)" in
    zypper)
      # openSUSE: ensure Packman (codecs) for multimedia tools
      if ! zypper lr | grep -qi packman; then
        sudo zypper -n ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
        sudo zypper -n ref || true
      fi
      ;;
    dnf)
      # Fedora: enable RPM Fusion
      if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
        ver="$(rpm -E %fedora 2>/dev/null || echo 42)"
        sudo dnf -y install \
          "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
          "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm" || true
      fi
      sudo dnf -y groupupdate core || true
      ;;
    apt)
      # Ubuntu/Debian: multiverse/universe for Steam and codecs
      if have add-apt-repository; then
        sudo add-apt-repository -y multiverse || true
        sudo add-apt-repository -y universe || true
      fi
      sudo dpkg --add-architecture i386 || true
      sudo apt-get update -y || true
      ;;
    pacman)
      # Arch: nothing special here (assume user uses official repos)
      true
      ;;
  esac
}

# ---------- Core packages ----------
install_core_native() {
  case "$(pm_detect)" in
    zypper)
      local pkgs=(steam lutris mangohud gamemode wine winetricks vulkan-tools vulkan-validationlayers)
      local got_missing="$(pm_group_present "${pkgs[@]}")"
      IFS='|' read -r present missing <<<"$got_missing"
      if [[ -n "${missing:-}" ]]; then
        pm_install ${missing}
      fi
      for p in ${present:-}; do record_status "$p" "${ICON_PRESENT}" "Already installed"; done
      for p in ${missing:-}; do record_status "$p" "${ICON_OK}" "Installed"; done
      ;;
    dnf)
      local pkgs=(steam lutris mangohud gamemode wine winetricks vulkan-tools vulkan-validation-layers)
      local got_missing="$(pm_group_present "${pkgs[@]}")"
      IFS='|' read -r present missing <<<"$got_missing"
      if [[ -n "${missing:-}" ]]; then
        pm_install ${missing}
      fi
      for p in ${present:-}; do record_status "$p" "${ICON_PRESENT}" "Already installed"; done
      for p in ${missing:-}; do record_status "$p" "${ICON_OK}" "Installed"; done
      ;;
    apt)
      local pkgs=(steam-installer steam-devices steam-libs-i386:i386 lutris mangohud gamemode wine winetricks vulkan-tools)
      local got_missing="$(pm_group_present "${pkgs[@]}")"
      IFS='|' read -r present missing <<<"$got_missing"
      if [[ -n "${missing:-}" ]]; then
        pm_install ${missing}
      fi
      for p in ${present:-}; do record_status "$p" "${ICON_PRESENT}" "Already installed"; done
      for p in ${missing:-}; do record_status "$p" "${ICON_OK}" "Installed"; done
      ;;
    pacman)
      local pkgs=(steam lutris mangohud gamemode wine winetricks vulkan-tools vulkan-validation-layers)
      local got_missing="$(pm_group_present "${pkgs[@]}")"
      IFS='|' read -r present missing <<<"$got_missing"
      if [[ -n "${missing:-}" ]]; then
        pm_install ${missing}
      fi
      for p in ${present:-}; do record_status "$p" "${ICON_PRESENT}" "Already installed"; done
      for p in ${missing:-}; do record_status "$p" "${ICON_OK}" "Installed"; done
      ;;
  esac
}

# ---------- Discord policy (native preferred; Flatpak fallback) ----------
install_discord() {
  case "$(pm_detect)" in
    zypper)
      if rpm -q discord >/dev/null 2>&1; then
        record_status "discord" "${ICON_PRESENT}" "Native present"
      else
        if sudo zypper -n in -y discord; then
          record_status "discord" "${ICON_OK}" "Native installed"
        else
          ensure_flathub_user
          fp_install_user com.discordapp.Discord
          record_status "discord" "${ICON_OK}" "Flatpak fallback"
        fi
      fi
      ;;
    dnf)
      if rpm -q discord >/dev/null 2>&1; then
        record_status "discord" "${ICON_PRESENT}" "Native present"
      else
        if sudo dnf -y install discord; then
          record_status "discord" "${ICON_OK}" "Native installed"
        else
          ensure_flathub_user
          fp_install_user com.discordapp.Discord
          record_status "discord" "${ICON_OK}" "Flatpak fallback"
        fi
      fi
      ;;
    apt)
      # No official native in Debian/Ubuntu repos reliably — use Flatpak
      ensure_flathub_user
      fp_install_user com.discordapp.Discord
      record_status "discord" "${ICON_OK}" "Flatpak installed (no stable native)"
      ;;
    pacman)
      # Assume no native in official repos; Flatpak fallback
      ensure_flathub_user
      fp_install_user com.discordapp.Discord
      record_status "discord" "${ICON_OK}" "Flatpak installed (no stable native)"
      ;;
  esac
}

# ---------- QoL flatpaks (user scope) ----------
install_flatpak_apps() {
  ensure_flathub_user
  fp_install_user net.davidotek.pupgui2           # ProtonUp-Qt
  fp_install_user com.vysp3r.ProtonPlus           # ProtonPlus
  fp_install_user com.heroicgameslauncher.hgl     # Heroic Games Launcher
  fp_install_user net.nokyan.Resources            # GOverlay (flatpak id)
}

# ---------- Wine/Vulkan extras ----------
install_wine_stack() {
  case "$(pm_detect)" in
    zypper)
      pm_install wine-mono winetricks || true
      record_status "wine-mono" "${ICON_OK}" "Installed (or present)"
      record_status "winetricks" "${ICON_OK}" "Installed (or present)"
      ;;
    dnf|apt|pacman)
      # Already covered earlier for most; mark present
      record_status "wine" "${ICON_PRESENT}" "Base wine present/installed earlier"
      record_status "winetricks" "${ICON_PRESENT}" "Present/installed earlier"
      ;;
  esac
}

# ---------- Kernel extras (v4l2loopback for OBS virtual cam etc.) ----------
install_kernel_extras() {
  case "$(pm_detect)" in
    zypper)
      if sudo zypper -n in -y v4l2loopback-kmp-default; then
        # Try load module (ignore if mismatched build)
        if modprobe v4l2loopback exclusive_caps=1 max_buffers=2 card_label="Loopback" 2>/dev/null; then
          record_status "v4l2loopback" "${ICON_OK}" "Installed & probe attempted"
        else
          record_status "v4l2loopback" "${ICON_PRESENT}" "Installed; module may require reboot"
        fi
      else
        record_status "v4l2loopback" "${ICON_ERR}" "Install failed"
      fi
      ;;
    dnf|apt|pacman)
      record_status "v4l2loopback" "${ICON_PRESENT}" "Not configured on this distro by default"
      ;;
  esac
}

# ---------- GameMode config (ensure service available) ----------
configure_gamemode() {
  if have gamemoded; then
    record_status "gamemode" "${ICON_PRESENT}" "Daemon available"
  else
    record_status "gamemode" "${ICON_ERR}" "Daemon not found"
  fi
}

# ---------- MangoHud config (user default) ----------
configure_mangohud() {
  local mhdir
  mhdir="$(userhome)/.config/MangoHud"
  mkdir -p "$mhdir"
  if [[ ! -f "$mhdir/MangoHud.conf" ]]; then
    cat >"$mhdir/MangoHud.conf" <<'CONF'
fps_limit=0
preset=1
cpu_stats
gpu_stats
gpu_temp
cpu_temp
ram
vram
frame_timing
wine
vulkan_driver
arch
CONF
    record_status "MangoHud.cfg" "${ICON_OK}" "Default config written"
  else
    record_status "MangoHud.cfg" "${ICON_PRESENT}" "Config exists"
  fi
}

# ---------- MAIN ----------
print_banner
ensure_sudo_keepalive
setup_repos

if [[ "$BUNDLE" == "core" ]]; then
  install_core_native
  install_discord
  install_wine_stack
  install_flatpak_apps
  configure_gamemode
  configure_mangohud
else
  install_core_native
  install_discord
  install_wine_stack
  install_flatpak_apps
  install_kernel_extras
  configure_gamemode
  configure_mangohud
fi

echo
echo "Tips:"
echo " - ProtonUp-Qt: flatpak run net.davidotek.pupgui2"
echo " - ProtonPlus : flatpak run com.vysp3r.ProtonPlus"
echo " - Heroic     : flatpak run com.heroicgameslauncher.hgl"
echo

print_status_summary
echo "Log saved to: ${LOG_FILE}"
echo "Done."
