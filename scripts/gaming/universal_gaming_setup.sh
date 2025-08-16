#!/usr/bin/env bash
# Team Nocturnal — Universal Gaming Setup (cross-distro) by XsMagical
# Distros: openSUSE (zypper), Fedora/RHEL (dnf/dnf5), Ubuntu/Debian (apt), Arch/Manjaro (pacman)
# Status icons (DO NOT CHANGE): green box ✔ (done/installed), blue box ✔ (already/ok), red box ✖ (failed)

set -euo pipefail

# ===== Colors & Icons =====
RED="\033[31m"; BLUE="\033[34m"; GREEN="\033[32m"; YELLOW="\033[33m"; RESET="\033[0m"; BOLD="\033[1m"
BGREEN="\033[42m"; BBLUE="\033[44m"; BRED="\033[41m"; WHITE="\033[97m"
ICON_OK="${BGREEN}${WHITE} ✔ ${RESET}"        # success / installed / updated
ICON_PRESENT="${BBLUE}${WHITE} ✔ ${RESET}"    # already present / skipped / no-op
ICON_ERR="${BRED}${WHITE} ✖ ${RESET}"         # failed

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

# ===== Defaults =====
BUNDLE="full"            # core|full
YESMODE="false"
AGREE_PK="false"         # openSUSE: auto-kill PackageKit
SKIP_UPGRADE="false"     # allow skipping upgrade

# ===== Helpers =====
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
    ( while true; do sleep 120; sudo -n true 2>/dev/null || exit; done ) &
    SUDO_KEEPALIVE_PID=$!
    trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT
  fi
}

# ===== Arg parse =====
for arg in "$@"; do
  case "$arg" in
    --bundle=*)     BUNDLE="${arg#*=}";;
    -y|--yes)       YESMODE="true";;
    --agree-pk)     AGREE_PK="true";;
    --skip-upgrade) SKIP_UPGRADE="true";;
    --help|-h)
      cat <<EOF
Usage: $0 [--bundle=core|full] [-y|--yes] [--agree-pk] [--skip-upgrade]
EOF
      exit 0;;
  esac
done

# ===== Status tracking =====
STAT_NAMES=(); STAT_ICONS=(); STAT_REASON=()
record_status(){ STAT_NAMES+=("$1"); STAT_ICONS+=("$2"); STAT_REASON+=("$3"); }
print_status_summary(){
  echo "----------------------------------------------------------"
  echo " Install Status Summary"
  echo "----------------------------------------------------------"
  local i
  for ((i=0; i<${#STAT_NAMES[@]}; i++)); do
    printf " %b %-32s %s\n" "${STAT_ICONS[$i]}" "${STAT_NAMES[$i]}:" "${STAT_REASON[$i]}"
  done
  echo "----------------------------------------------------------"
}

# ===== PM detection =====
pm_detect(){
  if have zypper; then echo zypper
  elif have dnf; then echo dnf
  elif have apt-get; then echo apt
  elif have pacman; then echo pacman
  else echo unknown; fi
}

# ===== Repo REFRESH (metadata) =====
pm_refresh_repos(){
  local pm; pm="$(pm_detect)"
  case "$pm" in
    zypper)
      [[ "$AGREE_PK" == "true" ]] && pkill -9 packagekitd 2>/dev/null || true
      if sudo zypper -n ref; then
        record_status "repos-refresh (zypper)" "${ICON_OK}" "zypper ref completed"
      else
        record_status "repos-refresh (zypper)" "${ICON_ERR}" "zypper ref failed"
      fi
      ;;
    dnf)
      if sudo dnf -y makecache --refresh; then
        record_status "repos-refresh (dnf)" "${ICON_OK}" "dnf makecache --refresh"
      else
        record_status "repos-refresh (dnf)" "${ICON_ERR}" "dnf makecache failed"
      fi
      ;;
    apt)
      if sudo apt-get update -y; then
        record_status "repos-refresh (apt)" "${ICON_OK}" "apt-get update done"
      else
        record_status "repos-refresh (apt)" "${ICON_ERR}" "apt-get update failed"
      fi
      ;;
    pacman)
      if sudo pacman -Syy --noconfirm; then
        record_status "repos-refresh (pacman)" "${ICON_OK}" "pacman -Syy completed"
      else
        record_status "repos-refresh (pacman)" "${ICON_ERR}" "pacman -Syy failed"
      fi
      ;;
    *)
      record_status "repos-refresh (unknown)" "${ICON_ERR}" "Unsupported PM"
      ;;
  esac
}

# ===== Install wrapper =====
pm_install(){
  local pkgs=("$@")
  case "$(pm_detect)" in
    zypper)
      [[ "$AGREE_PK" == "true" ]] && pkill -9 packagekitd 2>/dev/null || true
      sudo zypper -n in -y "${pkgs[@]}"
      ;;
    dnf)
      sudo dnf -y install "${pkgs[@]}"
      ;;
    apt)
      sudo apt-get install -y "${pkgs[@]}"
      ;;
    pacman)
      sudo pacman --noconfirm -S --needed "${pkgs[@]}"
      ;;
    *)
      echo "Unsupported package manager"; return 1;;
  esac
}

pm_installed_q(){
  case "$(pm_detect)" in
    zypper|dnf) rpm -q "$1" >/dev/null 2>&1 ;;
    apt)        dpkg -s "$1" >/dev/null 2>&1 ;;
    pacman)     pacman -Qi "$1" >/dev/null 2>&1 ;;
    *)          return 1 ;;
  esac
}

pm_group_present(){
  local present=() missing=()
  for p in "$@"; do
    if pm_installed_q "$p"; then present+=("$p"); else missing+=("$p"); fi
  done
  echo "${present[*]}|${missing[*]}"
}

# ===== Third-party repos =====
setup_repos(){
  case "$(pm_detect)" in
    zypper)
      if ! zypper lr | grep -qi packman; then
        sudo zypper -n ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
      fi
      record_status "third-party (zypper)" "${ICON_PRESENT}" "Packman ensured"
      ;;
    dnf)
      if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
        ver="$(rpm -E %fedora 2>/dev/null || echo 42)"
        if sudo dnf -y install \
          "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
          "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm"; then
          record_status "third-party (dnf)" "${ICON_OK}" "RPM Fusion installed"
        else
          record_status "third-party (dnf)" "${ICON_ERR}" "RPM Fusion install failed"
        fi
      else
        record_status "third-party (dnf)" "${ICON_PRESENT}" "RPM Fusion present"
      fi
      ;;
    apt)
      if have add-apt-repository; then
        sudo add-apt-repository -y multiverse || true
        sudo add-apt-repository -y universe || true
      fi
      sudo dpkg --add-architecture i386 || true
      record_status "third-party (apt)" "${ICON_PRESENT}" "universe/multiverse/i386 ensured"
      ;;
    pacman)
      record_status "third-party (pacman)" "${ICON_PRESENT}" "No extra repos required"
      ;;
  esac
}

# ===== System UPGRADE =====
pm_update_full(){
  local pm; pm="$(pm_detect)"
  case "$pm" in
    zypper)
      [[ "$AGREE_PK" == "true" ]] && pkill -9 packagekitd 2>/dev/null || true
      if sudo zypper -n up -y; then
        record_status "system-upgrade (zypper)" "${ICON_OK}" "zypper up completed"
        return 0
      else
        record_status "system-upgrade (zypper)" "${ICON_ERR}" "zypper up failed"
        return 1
      fi
      ;;
    dnf)
      if sudo dnf -y upgrade --refresh; then
        record_status "system-upgrade (dnf)" "${ICON_OK}" "dnf upgrade --refresh completed"
        return 0
      else
        record_status "system-upgrade (dnf)" "${ICON_ERR}" "dnf upgrade failed"
        return 1
      fi
      ;;
    apt)
      if sudo apt-get dist-upgrade -y; then
        record_status "system-upgrade (apt)" "${ICON_OK}" "dist-upgrade completed"
        return 0
      else
        record_status "system-upgrade (apt)" "${ICON_ERR}" "dist-upgrade failed"
        return 1
      fi
      ;;
    pacman)
      if sudo pacman -Syu --noconfirm; then
        record_status "system-upgrade (pacman)" "${ICON_OK}" "pacman -Syu completed"
        return 0
      else
        record_status "system-upgrade (pacman)" "${ICON_ERR}" "pacman -Syu failed"
        return 1
      fi
      ;;
    *) record_status "system-upgrade (unknown)" "${ICON_ERR}" "Unsupported PM"; return 1;;
  esac
}

# ===== Core packages =====
install_core_native(){
  case "$(pm_detect)" in
    zypper) local pkgs=(steam lutris mangohud gamemode wine winetricks vulkan-tools vulkan-validationlayers);;
    dnf)    local pkgs=(steam lutris mangohud gamemode wine winetricks vulkan-tools vulkan-validation-layers);;
    apt)    local pkgs=(steam-installer steam-devices steam-libs-i386:i386 lutris mangohud gamemode wine winetricks vulkan-tools);;
    pacman) local pkgs=(steam lutris mangohud gamemode wine winetricks vulkan-tools vulkan-validation-layers);;
  esac
  local got_missing; got_missing="$(pm_group_present "${pkgs[@]}")"
  IFS='|' read -r present missing <<<"$got_missing"
  if [[ -n "${missing:-}" ]]; then pm_install ${missing}; fi
  for p in ${present:-}; do record_status "$p" "${ICON_PRESENT}" "Already installed"; done
  for p in ${missing:-}; do record_status "$p" "${ICON_OK}" "Installed"; done
}

# ===== Flatpak setup =====
ensure_flathub_user(){
  if ! have flatpak; then
    case "$(pm_detect)" in
      zypper|dnf|apt|pacman) pm_install flatpak || true;;
    esac
  fi
  if ! flatpak remotes --user | grep -q '^flathub'; then
    as_user flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi
}

# Accept a display name for status clarity (e.g., "ProtonUp-Qt")
fp_install_user(){
  local appid="$1"; shift
  local disp="${1:-$appid}"
  if as_user flatpak info --user "$appid" >/dev/null 2>&1; then
    record_status "$disp" "${ICON_PRESENT}" "Flatpak (user): already installed"
  else
    if as_user flatpak install -y --user flathub "$appid"; then
      record_status "$disp" "${ICON_OK}" "Flatpak (user): installed"
    else
      record_status "$disp" "${ICON_ERR}" "Flatpak (user): install failed"
    fi
  fi
}

# ===== Discord policy =====
install_discord(){
  case "$(pm_detect)" in
    zypper|dnf)
      if pm_installed_q discord; then
        record_status "Discord" "${ICON_PRESENT}" "Native present"
      else
        if pm_install discord; then
          record_status "Discord" "${ICON_OK}" "Native installed"
        else
          ensure_flathub_user; fp_install_user com.discordapp.Discord "Discord"
          record_status "Discord" "${ICON_OK}" "Flatpak fallback"
        fi
      fi
      ;;
    apt|pacman)
      ensure_flathub_user; fp_install_user com.discordapp.Discord "Discord"
      record_status "Discord" "${ICON_OK}" "Flatpak installed (no stable native)"
      ;;
  esac
}

# ===== Proton tools, Heroic, GOverlay =====
install_flatpak_apps(){
  ensure_flathub_user
  fp_install_user net.davidotek.pupgui2 "ProtonUp-Qt"
  fp_install_user com.vysp3r.ProtonPlus "ProtonPlus"
  fp_install_user com.heroicgameslauncher.hgl "Heroic Games Launcher"
  fp_install_user net.nokyan.Resources "GOverlay"
}

# ===== Detect installed Proton versions =====
detect_proton_versions(){
  local uhome; uhome="$(userhome)"
  local paths=(
    "$uhome/.steam/root/compatibilitytools.d"
    "$uhome/.local/share/Steam/compatibilitytools.d"
    "$uhome/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d"
  )
  local found=()
  for p in "${paths[@]}"; do
    if [[ -d "$p" ]]; then
      while IFS= read -r -d '' d; do
        base="$(basename "$d")"
        # Heuristic: match Proton/GE style names
        if [[ "$base" =~ [Pp]roton || "$base" =~ GE-?[Pp]roton ]]; then
          found+=("$base")
        fi
      done < <(find "$p" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
    fi
  done

  if ((${#found[@]}==0)); then
    record_status "Proton versions" "${ICON_PRESENT}" "None detected in compatibilitytools.d"
  else
    # Deduplicate & sort
    mapfile -t uniq < <(printf "%s\n" "${found[@]}" | sort -u)
    # Limit display to keep summary tidy
    local show="$(printf "%s, " "${uniq[@]}")"; show="${show%, }"
    if ((${#show} > 120)); then
      # truncate long list
      local count="${#uniq[@]}"
      show="$(printf "%s, %s, %s, … (total %d)" "${uniq[0]}" "${uniq[1]}" "${uniq[2]}" "$count")"
    fi
    record_status "Proton versions" "${ICON_PRESENT}" "$show"
  fi
}

# ===== Wine/Vulkan extras =====
install_wine_stack(){
  case "$(pm_detect)" in
    zypper)
      if pm_install wine-mono winetricks; then
        record_status "wine-mono" "${ICON_OK}" "Installed"
        record_status "winetricks" "${ICON_OK}" "Installed"
      else
        record_status "wine-mono" "${ICON_ERR}" "Install failed"
        record_status "winetricks" "${ICON_ERR}" "Install failed"
      fi
      ;;
    dnf|apt|pacman)
      record_status "wine" "${ICON_PRESENT}" "Base wine present/installed earlier"
      record_status "winetricks" "${ICON_PRESENT}" "Present/installed earlier"
      ;;
  esac
}

# ===== Kernel extras =====
install_kernel_extras(){
  case "$(pm_detect)" in
    zypper)
      if pm_install v4l2loopback-kmp-default; then
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

# ===== GameMode & MangoHud =====
configure_gamemode(){
  if have gamemoded; then
    record_status "GameMode" "${ICON_PRESENT}" "Daemon available"
  else
    record_status "GameMode" "${ICON_ERR}" "Daemon not found"
  fi
}

configure_mangohud(){
  local mhdir; mhdir="$(userhome)/.config/MangoHud"
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

# ===== MAIN =====
print_banner
ensure_sudo_keepalive

# 1) ALWAYS refresh repos first
pm_refresh_repos

# 2) Ensure third-party repos, then refresh AGAIN
setup_repos
pm_refresh_repos

# 3) System upgrade (unless skipped)
if [[ "$SKIP_UPGRADE" == "false" ]]; then
  pm_update_full || true
else
  record_status "system-upgrade (skipped)" "${ICON_PRESENT}" "User requested --skip-upgrade"
fi

# 4) Install stack
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

# 5) Proton detection (managers + versions)
detect_proton_versions

echo
echo "Tips:"
echo " - ProtonUp-Qt: flatpak run net.davidotek.pupgui2"
echo " - ProtonPlus : flatpak run com.vysp3r.ProtonPlus"
echo " - Heroic     : flatpak run com.heroicgameslauncher.hgl"
echo

print_status_summary
echo "Log saved to: ${LOG_FILE}"
echo "Done."
