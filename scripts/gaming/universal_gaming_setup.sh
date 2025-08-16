#!/usr/bin/env bash
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
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# ------------------------
# Defaults & CLI
# ------------------------
ASSUME_YES=0
BUNDLE="full"
OVERLAYS="${OVERLAYS:-none}"
LOG_DIR="${HOME}/scripts/logs"
AUTOLOG=1            # default: log is ON
AGREE_PACKAGEKIT_QUIT=0  # new flag for openSUSE lock handling

usage() {
  cat <<'EOF'
Usage: universal_gaming_setup.sh [options]

Options:
  --bundle=<core|qol|wine|apps|full>  Select what to install (default: full)
  --overlays=<none|system|user>       Configure MangoHud/GameMode overlays (default: none)
  -y, --yes                           Non-interactive mode (assume yes)
  --no-log                            Disable automatic logging
  --autolog                           Force logging on (default already on)
  --agree-pk                          On openSUSE, automatically release PackageKit lock (safe)
  -h, --help                          Show this help

Examples:
  ./universal_gaming_setup.sh --bundle=full -y
  ./universal_gaming_setup.sh --bundle=apps --overlays=user
EOF
}

for arg in "$@"; do
  case "$arg" in
    --bundle=*) BUNDLE="${arg#*=}";;
    --overlays=*) OVERLAYS="${arg#*=}";;
    -y|--yes) ASSUME_YES=1;;
    --no-log) AUTOLOG=0;;
    --autolog) AUTOLOG=1;;
    --agree-pk) AGREE_PACKAGEKIT_QUIT=1;;
    -h|--help) usage; exit 0;;
    *) ;;
  esac
done

YN_FLAG=()
if [[ $ASSUME_YES -eq 1 ]]; then
  YN_FLAG=(-y)
fi

# ------------------------
# Auto log (default ON)
# ------------------------
maybe_start_logging() {
  if [[ ${AUTOLOG} -eq 1 && -t 1 ]]; then
    mkdir -p "${LOG_DIR}" || true
    ts="$(date +%Y%m%d_%H%M%S)"
    logf="${LOG_DIR}/gaming_${ts}.log"
    echo "Logging to: ${logf}"
    # restart script with tee capturing output; avoid recursion
    if [[ -z "${TN_LOGGING_ALREADY:-}" ]]; then
      export TN_LOGGING_ALREADY=1
      # exec to preserve exit code
      exec bash -c '"$0" "$@" 2>&1 | tee -a "$1"' bash "$0" "$@" "$logf"
    fi
  fi
}

# If the last arg looks like a log file path from our re-exec, skip starting again.
if [[ "${@: -1}" != *.log ]]; then
  maybe_start_logging "$@"
fi

print_banner

# Detect OS
OS_ID=""; OS_ID_LIKE=""
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  OS_ID="${ID:-}"
  OS_ID_LIKE="${ID_LIKE:-}"
fi

is_like() { echo "$OS_ID $OS_ID_LIKE" | grep -qiE "$1"; }

# ------------------------
# Helpers per distro
# ------------------------
suse_release_pkgkit_lock() {
  if is_like 'suse|opensuse'; then
    if [[ "${ASSUME_YES}" -eq 1 || "${AGREE_PACKAGEKIT_QUIT}" -eq 1 ]]; then
      echo "==> openSUSE: Releasing PackageKit lock (non-interactive)"
      pkcon quit >/dev/null 2>&1 || true
      systemctl stop packagekit.service >/dev/null 2>&1 || true
      killall -q packagekitd >/dev/null 2>&1 || true
    else
      echo "==> openSUSE: PackageKit may lock zypper. Re-run with --agree-pk or -y to auto-quit it."
    fi
  fi
}

suse_zypper() {
  suse_release_pkgkit_lock
  zypper --non-interactive "${YN_FLAG[@]}" "$@"
}

# Repo refresh / enablement
ensure_repos_suse() {
  echo "==> openSUSE: Ensuring Packman & refreshing repositories"
  suse_zypper refresh || true

  # Ensure Packman present (OSS/Non-OSS already present by default on TW)
  if ! zypper lr | grep -qi '^packman'; then
    suse_zypper addrepo --refresh --priority 90 --check \
      --name packman https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || true
  fi

  # Refresh again; ignore occasional mirror hiccups
  suse_zypper refresh || true

  # Safe dup to align vendor (no-op if fine)
  suse_zypper --no-refresh dup --allow-vendor-change || true
}

install_core_suse() {
  echo "==> Installing core gaming packages (Steam, Lutris, Wine, Vulkan, etc.)"
  suse_zypper refresh || true

  # 32-bit GL/Vulkan + tools
  suse_zypper install \
    Mesa-libGL1-32bit libvulkan1-32bit vulkan-tools vulkan-validationlayers || true

  # QoL
  suse_zypper install \
    gamemode libgamemode0 libgamemodeauto0-32bit mangohud mangohud-32bit gamescope || true

  # Wine stack
  suse_zypper install wine wine-32bit winetricks || true

  # Apps
  suse_zypper install steam lutris discord obs-studio || true

  # Kernel extras (optional; they exist on TW)
  suse_zypper install kernel-default-devel v4l2loopback-kmp-default || true
}

install_goverlay_suse() {
  echo "==> Installing GOverlay (native)"
  # Avoid broken games:tools repo; install from OSS (goverlay + vkbasalt live in main repo)
  suse_zypper install goverlay vkbasalt Mesa-demo || true
}

# Flatpak helpers
ensure_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    if is_like 'suse|opensuse'; then
      suse_zypper install flatpak || true
    elif is_like 'fedora|rhel|centos'; then
      sudo dnf install -y flatpak || true
    elif is_like 'debian|ubuntu'; then
      sudo apt-get update -y || true
      sudo apt-get install -y flatpak || true
    elif is_like 'arch'; then
      sudo pacman -S --noconfirm flatpak || true
    fi
  fi

  # Add flathub for both system and user scopes (idempotent)
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
  flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
}

install_flatpak_apps() {
  ensure_flatpak

  # ProtonUp-Qt (user scope)
  echo "==> Installing ProtonUp-Qt (Flatpak, user scope)"
  flatpak install -y --user flathub net.davidotek.pupgui2 || true

  # Heroic (system scope, but fallback to user if system fails)
  echo "==> Installing Heroic (Flatpak)"
  if ! flatpak install -y flathub com.heroicgameslauncher.hgl; then
    flatpak install -y --user flathub com.heroicgameslauncher.hgl || true
  fi

  # ProtonPlus (user scope)
  echo "==> Installing ProtonPlus (Flatpak, user scope)"
  flatpak install -y --user flathub com.vysp3r.ProtonPlus || true
}

# Overlays config
configure_overlays() {
  echo "==> Overlays: ${OVERLAYS}"
  mkdir -p "${HOME}/.config/MangoHud" "${HOME}/.config" || true

  # Simple MangoHud default
  MH_CFG="${HOME}/.config/MangoHud/MangoHud.conf"
  if [[ ! -s "${MH_CFG}" ]]; then
    cat > "${MH_CFG}" <<'EOC'
fps
frametime
gpu_stats
cpu_stats
vram
ram
vulkan_driver
full
EOC
    echo "==> MangoHud config created"
  else
    echo "==> MangoHud config already exists"
  fi

  # GameMode config stub
  GM_CFG="${HOME}/.config/gamemode.ini"
  if [[ ! -s "${GM_CFG}" ]]; then
    cat > "${GM_CFG}" <<'EOG'
[general]
renice=10
[easyanti-cheat]
enabled=auto
EOG
    echo "==> GameMode config created"
  else
    echo "==> GameMode config already exists"
  fi

  case "${OVERLAYS}" in
    system)
      # No systemwide changes on openSUSE by default (keep conservative)
      ;;
    user|none|*)
      ;;
  esac
}

# ------------------------
# Distro dispatch
# ------------------------
install_core_fedora() {
  sudo dnf -y groupinstall "Development Tools" >/dev/null 2>&1 || true
  sudo dnf -y install steam lutris mangohud gamemode gamescope wine winetricks \
    vulkan-tools vulkan-validation-layers discord obs-studio || true
}

install_core_debian() {
  sudo apt-get update -y || true
  sudo apt-get install -y steam lutris mangohud gamemode gamescope wine winetricks \
    vulkan-tools vulkan-validationlayers obs-studio || true
  # Discord: snap/flatpak/manual; we won’t force here to keep prior behavior
}

install_core_arch() {
  sudo pacman -Syu --noconfirm || true
  sudo pacman -S --noconfirm steam lutris mangohud gamemode gamescope wine winetricks \
    vulkan-tools vulkan-validation-layers obs-studio || true
  # Discord from repo is 'discord'
  sudo pacman -S --noconfirm discord || true
}

do_install() {
  if is_like 'suse|opensuse'; then
    ensure_repos_suse
    case "${BUNDLE}" in
      core) install_core_suse ;;
      qol)  suse_zypper install mangohud gamemode gamescope || true ;;
      wine) suse_zypper install wine wine-32bit winetricks || true ;;
      apps) suse_zypper install steam lutris discord obs-studio || true ;;
      full|*) install_core_suse ;;
    esac

    # Proton tools + Heroic
    install_flatpak_apps

    # GOverlay native
    install_goverlay_suse

    # Overlays
    configure_overlays

  elif is_like 'fedora|rhel|centos'; then
    case "${BUNDLE}" in
      core) install_core_fedora ;;
      full|*) install_core_fedora ;;
      qol)  sudo dnf install -y mangohud gamemode gamescope || true ;;
      wine) sudo dnf install -y wine winetricks || true ;;
      apps) sudo dnf install -y steam lutris discord obs-studio || true ;;
    esac
    install_flatpak_apps
    configure_overlays

  elif is_like 'debian|ubuntu'; then
    case "${BUNDLE}" in
      core) install_core_debian ;;
      full|*) install_core_debian ;;
      qol)  sudo apt-get install -y mangohud gamemode gamescope || true ;;
      wine) sudo apt-get install -y wine winetricks || true ;;
      apps) sudo apt-get install -y steam lutris obs-studio || true ;;
    esac
    install_flatpak_apps
    configure_overlays

  elif is_like 'arch'; then
    case "${BUNDLE}" in
      core) install_core_arch ;;
      full|*) install_core_arch ;;
      qol)  sudo pacman -S --noconfirm mangohud gamemode gamescope || true ;;
      wine) sudo pacman -S --noconfirm wine winetricks || true ;;
      apps) sudo pacman -S --noconfirm steam lutris discord obs-studio || true ;;
    esac
    install_flatpak_apps
    configure_overlays

  else
    echo "Unsupported distro (need dnf/apt/pacman/zypper)."
    exit 1
  fi
}

# ------------------------
# Run
# ------------------------
do_install

# ------------------------
# Summary
# ------------------------
echo "----------------------------------------------------------"
echo " Install Status Summary"
echo "----------------------------------------------------------"
have() { command -v "$1" >/dev/null 2>&1; }

# Basics
have steam && echo "✅ steam: Present" || echo "❌ steam: Missing"
have lutris && echo "✅ lutris: Present" || echo "❌ lutris: Missing"
have gamescope && echo "✅ gamescope: Present" || echo "❌ gamescope: Missing"
have mangohud && echo "✅ mangohud: Present" || echo "❌ mangohud: Missing"
have vulkaninfo && echo "✅ vulkaninfo: Present" || echo "❌ vulkaninfo: Missing"
have gamemoded && echo "✅ gamemoded: Present" || echo "❌ gamemoded: Missing"
have wine && echo "✅ wine: Present" || echo "❌ wine: Missing"
have winetricks && echo "✅ winetricks: Present" || echo "❌ winetricks: Missing"
have obs && echo "✅ obs: Present" || echo "❌ obs: Missing"
have discord && echo "✅ discord: Present" || echo "❌ discord: Missing"

# Proton tools
if command -v flatpak >/dev/null 2>&1; then
  if flatpak info --user net.davidotek.pupgui2 >/dev/null 2>&1 || flatpak info net.davidotek.pupgui2 >/dev/null 2>&1; then
    echo "✅ ProtonUp-Qt (Flatpak): Present"
  else
    echo "❌ ProtonUp-Qt (Flatpak): Missing"
  fi
  if flatpak info --user com.vysp3r.ProtonPlus >/dev/null 2>&1 || flatpak info com.vysp3r.ProtonPlus >/dev/null 2>&1; then
    echo "✅ ProtonPlus (Flatpak): Present"
  else
    echo "❌ ProtonPlus (Flatpak): Missing"
  fi
else
  echo "❌ ProtonUp-Qt/ProtonPlus: Flatpak not available"
fi

# GOverlay
if have goverlay; then
  echo "✅ GOverlay: Present"
else
  if command -v flatpak >/dev/null 2>&1 && flatpak info com.github.benjamimgois.goverlay >/dev/null 2>&1; then
    echo "✅ GOverlay (Flatpak): Present"
  else
    echo "❌ GOverlay: Missing"
  fi
fi

# v4l2loopback (module availability may lag behind newest kernels)
if lsmod | grep -q '^v4l2loopback'; then
  echo "✅ v4l2loopback: Loaded"
elif modinfo v4l2loopback >/dev/null 2>&1; then
  echo "✅ v4l2loopback: Present"
else
  echo "⚠ v4l2loopback: Not available for running kernel build yet"
fi

# Final log line if logging
if [[ "${@: -1}" == *"/gaming_"*".log" ]]; then
  echo "----------------------------------------------------------"
  echo "Log saved to: ${@: -1}"
fi
echo "Done."
[31m████████╗███╗   ██╗[0m
[31m╚══██╔══╝████╗  ██║[0m
[31m   ██║   ██╔██╗ ██║[0m
[31m   ██║   ██║╚██╗██║[0m
[31m   ██║   ██║ ╚████║[0m
[31m   ╚═╝   ╚═╝  ╚═══╝[0m
[34m----------------------------------------------------------[0m
[34m   Team-Nocturnal.com Universal Gaming Setup by XsMagical[0m
[34m----------------------------------------------------------[0m
==> openSUSE: Ensuring Packman & refreshing repositories
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> Installing core gaming packages (Steam, Lutris, Wine, Vulkan, etc.)
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> Installing ProtonUp-Qt (Flatpak, user scope)
Looking for matches…
Skipping: net.davidotek.pupgui2/x86_64/stable is already installed
==> Installing Heroic (Flatpak)
Looking for matches…
Remote ‘flathub’ found in multiple installations:

   1) system
   2) user

Which do you want to use (0 to abort)? [0-2]: 0
error: No remote chosen to resolve ‘flathub’ which exists in multiple installations
Looking for matches…
Skipping: com.heroicgameslauncher.hgl/x86_64/stable is already installed
==> Installing ProtonPlus (Flatpak, user scope)
Looking for matches…
Skipping: com.vysp3r.ProtonPlus/x86_64/stable is already installed
==> Installing GOverlay (native)
==> openSUSE: Releasing PackageKit lock (non-interactive)
The flag y is not known.
==> Overlays: none
==> MangoHud config created
==> GameMode config created
----------------------------------------------------------
 Install Status Summary
----------------------------------------------------------
✅ steam: Present
✅ lutris: Present
✅ gamescope: Present
✅ mangohud: Present
✅ vulkaninfo: Present
✅ gamemoded: Present
✅ wine: Present
✅ winetricks: Present
✅ obs: Present
✅ discord: Present
✅ ProtonUp-Qt (Flatpak): Present
✅ ProtonPlus (Flatpak): Present
✅ GOverlay: Present
✅ v4l2loopback: Present
----------------------------------------------------------
Log saved to: /root/scripts/logs/gaming_20250815_232741.log
Done.
/home/xs/scripts/universal_gaming_setup.sh: line 403: $'\E[31m████████╗███╗': command not found
