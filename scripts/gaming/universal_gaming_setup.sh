#!/usr/bin/env bash
# Team-Nocturnal — Universal Gaming Setup Script by XsMagical
# Goal: universal across openSUSE/Fedora/Ubuntu(Debian)/Arch with:
# - Single sudo prompt at start
# - Logs saved under the invoking user's home (not /root)
# - Native-first Discord detection; Flatpak only as fallback
# - Checkbox status per item inline + final summary with reasons
# - Proton tools via Flatpak (user scope)
# - Safe on openSUSE (no flaky games:tools repo)

set -euo pipefail

# ===== Colors & Symbols =====
GREEN="✅"
BLUE="🔷"
RED="❌"
YELLOW="⚠"
RESET="\033[0m"

# ===== Banner =====
# ===== Colors =====
RED="\033[1;31m"   # bright red
BLUE="\033[1;34m"
RESET="\033[0m"

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


# ===== Real user / Log location (always under real user's HOME) =====
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")"
LOGDIR="$REAL_HOME/scripts/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/gaming_$(date +%Y%m%d_%H%M%S).log"

# Start logging (stdout+stderr) to user log
exec > >(tee -a "$LOGFILE") 2>&1
echo "Logging to: $LOGFILE"

# ===== Arg parsing (kept light, default bundle=full) =====
BUNDLE="full"
AGREE_PK="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle=*) BUNDLE="${1#*=}"; shift ;;
    --bundle) BUNDLE="$2"; shift 2 ;;
    -y|--yes)  shift ;; # accepted for compatibility; we run non-interactive where supported
    --agree-pk) AGREE_PK="true"; shift ;;
    *) echo "Note: unknown flag '$1' ignored." ; shift ;;
  esac
done

# ===== Helpers =====
have() { command -v "$1" >/dev/null 2>&1; }

detect_pkg_manager() {
  if have zypper; then echo "zypper"
  elif have dnf; then echo "dnf"
  elif have apt-get; then echo "apt"
  elif have pacman; then echo "pacman"
  else echo "unknown"; fi
}
PKG_MANAGER="$(detect_pkg_manager)"

# Single sudo prompt at the beginning (unless already root)
if [[ "$(id -u)" -ne 0 ]]; then
  if sudo -vn 2>/dev/null; then
    echo "Sudo cached; proceeding."
  else
    echo "Requesting sudo password (once)..."
    sudo -v
  fi
fi

# PackageKit lock handling (best effort)
release_pkgkit_lock() {
  if [[ "$AGREE_PK" == "true" ]] && have pkcon; then
    pkcon quit >/dev/null 2>&1 || true
    sleep 1
  fi
}

# Run a command with optional retry if PackageKit locked
run_pkg_cmd() {
  local cmd="$*"
  if ! eval "$cmd"; then
    release_pkgkit_lock
    eval "$cmd"
  fi
}

# Track statuses
declare -A STATUS MSG SCOPE

set_status() {
  local key="$1" stat="$2" msg="${3:-}"
  STATUS["$key"]="$stat"
  MSG["$key"]="$msg"
}

# ===== Distro specific glue =====

suse_prepare() {
  export ZYPP_LOCK_TIMEOUT=30
  release_pkgkit_lock

  # Ensure Packman exists
  if ! zypper lr | awk '{print $3}' | grep -q '^packman$'; then
    echo "==> openSUSE: adding Packman"
    run_pkg_cmd "sudo zypper -n ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman"
  fi
  echo "==> openSUSE: refreshing repos"
  run_pkg_cmd "sudo zypper -n ref"
}

dnf_prepare() {
  release_pkgkit_lock
  # Optional: RPM Fusion already expected if user had Steam/Discord natively before.
  true
}

apt_prepare() {
  release_pkgkit_lock
  run_pkg_cmd "sudo apt-get update -y"
}

pacman_prepare() {
  release_pkgkit_lock
  run_pkg_cmd "sudo pacman -Sy --noconfirm"
}

# ===== Native install helpers =====
native_installed() {
  case "$PKG_MANAGER" in
    zypper) zypper se -i "$1" | awk '{print $1}' | grep -q '^i$' ;;
    dnf)    dnf list installed "$1" &>/dev/null ;;
    apt)    dpkg -l | awk '{print $2}' | grep -qx "$1" ;;
    pacman) pacman -Qi "$1" &>/dev/null ;;
    *) return 1 ;;
  esac
}

native_install() {
  local pkg="$1" summary_key="${2:-$1}"
  case "$PKG_MANAGER" in
    zypper)
      if native_installed "$pkg"; then
        echo " - $summary_key : $BLUE Already present"
        set_status "$summary_key" "$BLUE" "Already present"
      else
        if run_pkg_cmd "sudo zypper -n in -l -y $pkg"; then
          echo " - $summary_key : $GREEN Installed"
          set_status "$summary_key" "$GREEN" "Installed"
        else
          echo " - $summary_key : $RED Error (native)"
          set_status "$summary_key" "$RED" "Error (native)"
        fi
      fi
      ;;
    dnf)
      if native_installed "$pkg"; then
        echo " - $summary_key : $BLUE Already present"
        set_status "$summary_key" "$BLUE" "Already present"
      else
        if run_pkg_cmd "sudo dnf install -y $pkg"; then
          echo " - $summary_key : $GREEN Installed"
          set_status "$summary_key" "$GREEN" "Installed"
        else
          echo " - $summary_key : $RED Error (native)"
          set_status "$summary_key" "$RED" "Error (native)"
        fi
      fi
      ;;
    apt)
      if native_installed "$pkg"; then
        echo " - $summary_key : $BLUE Already present"
        set_status "$summary_key" "$BLUE" "Already present"
      else
        if run_pkg_cmd "sudo apt-get install -y $pkg"; then
          echo " - $summary_key : $GREEN Installed"
          set_status "$summary_key" "$GREEN" "Installed"
        else
          echo " - $summary_key : $RED Error (native)"
          set_status "$summary_key" "$RED" "Error (native)"
        fi
      fi
      ;;
    pacman)
      if native_installed "$pkg"; then
        echo " - $summary_key : $BLUE Already present"
        set_status "$summary_key" "$BLUE" "Already present"
      else
        if run_pkg_cmd "sudo pacman -S --noconfirm $pkg"; then
          echo " - $summary_key : $GREEN Installed"
          set_status "$summary_key" "$GREEN" "Installed"
        else
          echo " - $summary_key : $RED Error (native)"
          set_status "$summary_key" "$RED" "Error (native)"
        fi
      fi
      ;;
    *)
      echo " - $summary_key : $RED Skipped (unknown manager)"
      set_status "$summary_key" "$RED" "Skipped (unknown manager)"
      ;;
  esac
}

# ===== Flatpak helpers (user scope) =====
ensure_flatpak_user_remote() {
  if ! have flatpak; then
    case "$PKG_MANAGER" in
      zypper) run_pkg_cmd "sudo zypper -n in -y flatpak" ;;
      dnf)    run_pkg_cmd "sudo dnf install -y flatpak" ;;
      apt)    run_pkg_cmd "sudo apt-get install -y flatpak" ;;
      pacman) run_pkg_cmd "sudo pacman -S --noconfirm flatpak" ;;
    esac
  fi
  if ! flatpak remotes --user | grep -q '^flathub'; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo || true
  fi
}

flatpak_status() {
  local app="$1" scope="$2"
  if [[ "$scope" == "user" ]]; then
    flatpak info --user "$app" >/dev/null 2>&1
  else
    flatpak info --system "$app" >/dev/null 2>&1
  fi
}

flatpak_install_user() {
  local app="$1" label="${2:-$1}"
  ensure_flatpak_user_remote
  if flatpak_status "$app" user; then
    echo " - $label (Flatpak, user) : $BLUE Already present"
    SCOPE["$label"]="Flatpak (user)"
    set_status "$label" "$BLUE" "Already present"
  else
    if flatpak install -y --user flathub "$app"; then
      echo " - $label (Flatpak, user) : $GREEN Installed"
      SCOPE["$label"]="Flatpak (user)"
      set_status "$label" "$GREEN" "Installed"
    else
      echo " - $label (Flatpak, user) : $RED Error"
      SCOPE["$label"]="Flatpak (user)"
      set_status "$label" "$RED" "Error"
    fi
  fi
}

# ===== Discord (native preferred, fall back to Flatpak) =====
install_discord() {
  echo "==> Discord (native first, Flatpak fallback)"
  local native_pkg="discord"
  local native_ok=false

  case "$PKG_MANAGER" in
    zypper)
      # openSUSE: packman provides discord; user may already have it
      if native_installed "$native_pkg"; then
        echo " - Discord (native) : $BLUE Already present"
        set_status "discord" "$BLUE" "Already present (native)"
        native_ok=true
      else
        if run_pkg_cmd "sudo zypper -n in -y $native_pkg"; then
          echo " - Discord (native) : $GREEN Installed"
          set_status "discord" "$GREEN" "Installed (native)"
          native_ok=true
        fi
      fi
      ;;
    dnf|apt|pacman)
      if native_installed "$native_pkg"; then
        echo " - Discord (native) : $BLUE Already present"
        set_status "discord" "$BLUE" "Already present (native)"
        native_ok=true
      else
        if run_pkg_cmd "sudo $(echo $PKG_MANAGER | sed 's/apt/apt-get/') install -y $native_pkg"; then
          echo " - Discord (native) : $GREEN Installed"
          set_status "discord" "$GREEN" "Installed (native)"
          native_ok=true
        fi
      fi
      ;;
  esac

  if [[ "$native_ok" == "false" ]]; then
    # Only fall back to Flatpak if native not available/succeeded
    flatpak_install_user "com.discordapp.Discord" "discord"
  else
    # If Flatpak also present, note it but do not touch
    if flatpak_status "com.discordapp.Discord" user || flatpak_status "com.discordapp.Discord" system; then
      echo "   ${YELLOW}Note:${RESET} Flatpak Discord also present; keeping native as primary."
    fi
  fi
}

# ===== Core installs by distro (conservative names) =====
install_core() {
  echo "==> Core gaming packages"
  case "$PKG_MANAGER" in
    zypper)
      native_install Mesa-libGL1-32bit "Mesa-libGL1-32bit"
      native_install libvulkan1-32bit  "libvulkan1-32bit"
      native_install vulkan-tools      "vulkan-tools"
      native_install vulkan-validationlayers "vulkan-validationlayers"
      native_install gamemode          "gamemode"
      native_install libgamemode0      "libgamemode0"
      native_install libgamemodeauto0-32bit "libgamemodeauto0-32bit"
      native_install mangohud          "mangohud"
      native_install mangohud-32bit    "mangohud-32bit"
      native_install steam             "steam"
      native_install lutris            "lutris"
      native_install gamescope         "gamescope"
      ;;
    dnf)
      native_install vulkan-tools      "vulkan-tools"
      native_install gamemode          "gamemode"
      native_install mangohud          "mangohud"
      native_install steam             "steam"
      native_install lutris            "lutris"
      native_install gamescope         "gamescope"
      ;;
    apt)
      native_install vulkan-tools      "vulkan-tools"
      native_install gamemode          "gamemode"
      native_install mangohud          "mangohud"
      native_install steam             "steam"
      native_install lutris            "lutris"
      native_install gamescope         "gamescope"
      ;;
    pacman)
      native_install vulkan-tools      "vulkan-tools"
      native_install gamemode          "gamemode"
      native_install mangohud          "mangohud"
      native_install steam             "steam"
      native_install lutris            "lutris"
      native_install gamescope         "gamescope"
      ;;
    *)
      echo " - $RED Unknown package manager; skipping core set."
      ;;
  esac
}

install_wine() {
  echo "==> Wine + Winetricks"
  case "$PKG_MANAGER" in
    zypper)
      native_install wine "wine"
      native_install wine-32bit "wine-32bit"
      native_install winetricks "winetricks"
      ;;
    dnf|apt|pacman)
      native_install wine "wine"
      native_install winetricks "winetricks"
      ;;
  esac
}

install_qol() {
  echo "==> QoL apps"
  install_discord
  case "$PKG_MANAGER" in
    zypper)
      native_install obs-studio "obs-studio"
      native_install goverlay "goverlay"
      native_install vkbasalt "vkbasalt"
      native_install Mesa-demo "Mesa-demo"
      ;;
    dnf|apt|pacman)
      native_install obs-studio "obs-studio"
      native_install goverlay "goverlay" || true
      native_install vkbasalt "vkbasalt" || true
      ;;
  esac
}

install_kernel_extras() {
  echo "==> Optional kernel extras (v4l2loopback)"
  case "$PKG_MANAGER" in
    zypper)
      native_install kernel-default-devel "kernel-default-devel"
      native_install v4l2loopback-kmp-default "v4l2loopback-kmp-default"
      if modinfo v4l2loopback >/dev/null 2>&1; then
        if sudo modprobe v4l2loopback exclusive_caps=1 max_buffers=2 card_label="Loopback"; then
          set_status "v4l2loopback" "$GREEN" "Loaded"
        else
          set_status "v4l2loopback" "$BLUE" "Installed (module available)"
        fi
      else
        set_status "v4l2loopback" "$YELLOW" "Installed but no module for running kernel yet"
        echo "   $YELLOW Installed but no module for the current kernel yet.$RESET"
      fi
      ;;
    dnf|apt|pacman)
      # leave empty; varies widely by kernel/builds
      :
      ;;
  esac
}

install_flatpak_apps() {
  echo "==> Proton tools & Heroic (Flatpak, user scope)"
  flatpak_install_user "net.davidotek.pupgui2" "ProtonUp-Qt"
  flatpak_install_user "com.vysp3r.ProtonPlus" "ProtonPlus"
  flatpak_install_user "com.heroicgameslauncher.hgl" "Heroic"
}

# ===== MAIN =====
print_banner

case "$PKG_MANAGER" in
  zypper) suse_prepare ;;
  dnf)    dnf_prepare ;;
  apt)    apt_prepare ;;
  pacman) pacman_prepare ;;
  *) echo "$RED Unknown distro package manager. Proceeding with Flatpak apps only.$RESET" ;;
esac

# Bundle selection kept simple (full is default)
if [[ "$BUNDLE" == "core" ]]; then
  install_core
elif [[ "$BUNDLE" == "apps" ]]; then
  install_qol
  install_flatpak_apps
else
  install_core
  install_wine
  install_qol
  install_kernel_extras
  install_flatpak_apps
fi

# ===== Summary =====
echo "----------------------------------------------------------"
echo " Install Status Summary"
echo "----------------------------------------------------------"
# Print in a stable order
items=(
  steam lutris gamescope mangohud vulkan-tools gamemode wine winetricks
  "obs-studio" discord goverlay vkbasalt "Mesa-libGL1-32bit" "libvulkan1-32bit" "vulkan-validationlayers"
  "ProtonUp-Qt" "ProtonPlus" "Heroic" v4l2loopback
)
declare -A printed
for k in "${items[@]}"; do
  if [[ -n "${STATUS[$k]+x}" && -z "${printed[$k]+x}" ]]; then
    echo -n "${STATUS[$k]} $k"
    if [[ -n "${SCOPE[$k]+x}" ]]; then
      echo -n " [${SCOPE[$k]}]"
    fi
    if [[ -n "${MSG[$k]+x}" ]]; then
      echo -n " — ${MSG[$k]}"
    fi
    echo
    printed[$k]=1
  fi
done

echo "----------------------------------------------------------"
echo "Tips:"
echo "- ProtonUp-Qt: flatpak run net.davidotek.pupgui2"
echo "- ProtonPlus : flatpak run com.vysp3r.ProtonPlus"
echo "- Heroic     : flatpak run com.heroicgameslauncher.hgl"
echo "Log saved to: $LOGFILE"
echo "Done."
