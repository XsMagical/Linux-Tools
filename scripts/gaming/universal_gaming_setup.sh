#!/usr/bin/env bash
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
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal Gaming Setup Script by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

set -euo pipefail
print_banner

# ===== Flags / defaults =====
ASSUME_YES=0
VERBOSE=0
NATIVE_ONLY=0
FLATPAK_ONLY=0

INSTALL_DISCORD=1
INSTALL_HEROIC=1
INSTALL_STEAM=1
INSTALL_LUTRIS=1
INSTALL_PROTONPLUS=1      # Fedora native (COPR) preferred
INSTALL_PROTONUPQT=1      # Flatpak fallback

INSTALL_OBS=0             # Off by default; enabled in --bundle=full
INSTALL_GAMESCOPE=0       # Off by default; enabled in --bundle=full
INSTALL_GOVERLAY=0        # Off by default; enabled in --bundle=full
INSTALL_V4L2LOOPBACK=0    # Off by default; enabled in --bundle=full
INSTALL_PROTONTRICKS=1    # Tools for Proton

KEEP_FLATPAK=0
CLEAN_DUPES=1
BUNDLE=""                 # lite|normal|full

# Overlays are **games only** (Steam wrapper). No system-wide support.
OVERLAYS_MODE=""          # games|none|status
OVERLAY_ONLY=0

usage() {
cat <<USAGE
Usage: $(basename "$0") [options]

General:
  -y, --yes             Assume yes for package prompts
  -v, --verbose         Verbose package output
  --native-only         Only native packages
  --flatpak-only        Only Flatpaks
  --keep-flatpak        Keep Flatpak duplicates even if native exists
  --no-clean            Do not remove Flatpak duplicates

Per-app toggles:
  --no-steam | --no-lutris | --no-heroic | --no-discord
  --no-protonplus | --no-protonupqt | --no-protontricks

Bundles:
  --bundle=lite|normal|full
    • full adds: obs-studio, gamescope, GOverlay, v4l2loopback

Overlays (games only):
  --overlays=games|none|status
  --overlay-only        Apply/show overlay and exit (no installs)

Examples:
  $HOME/scripts/universal_gaming_setup.sh --overlays=games  --overlay-only
  $HOME/scripts/universal_gaming_setup.sh --overlays=none   --overlay-only
  $HOME/scripts/universal_gaming_setup.sh --bundle=full -y
USAGE
}

# ===== Parse args =====
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    -v|--verbose) VERBOSE=1 ;;
    --native-only) NATIVE_ONLY=1 ;;
    --flatpak-only) FLATPAK_ONLY=1 ;;
    --keep-flatpak) KEEP_FLATPAK=1 ;;
    --no-clean) CLEAN_DUPES=0 ;;
    --no-steAM|--no-steam) INSTALL_STEAM=0 ;;
    --no-lutris) INSTALL_LUTRIS=0 ;;
    --no-heroic) INSTALL_HEROIC=0 ;;
    --no-discord) INSTALL_DISCORD=0 ;;
    --no-protonplus) INSTALL_PROTONPLUS=0 ;;
    --no-protonupqt) INSTALL_PROTONUPQT=0 ;;
    --no-protontricks) INSTALL_PROTONTRICKS=0 ;;
    --bundle=lite) BUNDLE="lite" ;;
    --bundle=normal) BUNDLE="normal" ;;
    --bundle=full) BUNDLE="full" ;;
    --overlays=games) OVERLAYS_MODE="games" ;;
    --overlays=none) OVERLAYS_MODE="none" ;;
    --overlays=status) OVERLAYS_MODE="status" ;;
    --overlay-only) OVERLAY_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown flag: $arg"; exit 2 ;;
  esac
done
[[ $NATIVE_ONLY -eq 1 && $FLATPAK_ONLY -eq 1 ]] && { echo "Cannot use --native-only and --flatpak-only together."; exit 2; }

# ===== Bundle presets =====
case "$BUNDLE" in
  lite)
    INSTALL_HEROIC=0
    INSTALL_LUTRIS=0
    INSTALL_DISCORD=0
    INSTALL_OBS=0
    INSTALL_GAMESCOPE=0
    INSTALL_GOVERLAY=0
    INSTALL_V4L2LOOPBACK=0
    ;;
  normal|"")
    # Defaults stand
    ;;
  full)
    INSTALL_OBS=1
    INSTALL_GAMESCOPE=1
    INSTALL_GOVERLAY=1
    INSTALL_V4L2LOOPBACK=1
    ;;
esac

# ===== Distro detect =====
if [[ -r /etc/os-release ]]; then . /etc/os-release; else ID="unknown"; ID_LIKE=""; fi
ARCH="$(uname -m)"
case "$ARCH" in aarch64|armv7*|armhf|arm64) INSTALL_STEAM=0 ;; esac

# ===== Package helpers =====
# Refactor DNF handling to support dnf5 (flags must follow subcommand)
if command -v dnf5 >/dev/null 2>&1; then
  DNF_CMD="dnf5"
else
  DNF_CMD="dnf"
fi
DNF_INSTALL_FLAGS="install -y --setopt=install_weak_deps=False --best --refresh --allowerasing"
[[ $VERBOSE -eq 1 ]] && DNF_INSTALL_FLAGS="$DNF_INSTALL_FLAGS -v"

APT_INSTALL_FLAGS="-y -o Dpkg::Options::=--force-confnew"
[[ $VERBOSE -eq 1 ]] && APT_INSTALL_FLAGS="$APT_INSTALL_FLAGS -V"
PACMAN_FLAGS="--needed --noconfirm"
[[ $VERBOSE -eq 1 ]] && PACMAN_FLAGS="$PACMAN_FLAGS -v"

have_flatpak() { command -v flatpak >/dev/null 2>&1; }
flatpak_user() { flatpak --user "$@"; }
fp_add_flathub() { flatpak_user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true; }
fp_present() { flatpak_user list --app --columns=application | grep -qx "$1"; }
fp_install() { flatpak_user install -y --noninteractive "$@"; }
fp_remove() { flatpak_user uninstall -y --delete-data "$@" || true; }

ensure_rpmfusion() {
  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    sudo "$DNF_CMD" $DNF_INSTALL_FLAGS \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
  fi
}

ensure_debian_components() {
  case "${ID_LIKE:-$ID}" in
    *debian*)
      sudo dpkg --add-architecture i386 2>/dev/null || true
      sudo sed -i 's/^\s*deb \(.*\)$/\0 contrib non-free non-free-firmware/' /etc/apt/sources.list || true
      sudo apt update || true
      ;;
  esac
}

install_native() {
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)   sudo "$DNF_CMD" $DNF_INSTALL_FLAGS "$@" ;;
    *debian*|*ubuntu*) sudo apt-get ${APT_INSTALL_FLAGS} install "$@" ;;
    *arch*|*manjaro*)  sudo pacman -S ${PACMAN_FLAGS} "$@" ;;
    *suse*|*opensuse*) sudo zypper --non-interactive in "$@" ;;
    *) echo "Unsupported distro family: ${ID_LIKE:-$ID}"; return 1 ;;
  esac
}

# ===== Install sets =====
install_core() {
  # MangoHud/GameMode/Vulkan/Wine/Winetricks/Protontricks
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)
      ensure_rpmfusion
      install_native mangohud gamemode vkBasalt vulkan-tools vulkan-validation-layers wine winetricks
      [[ $INSTALL_PROTONTRICKS -eq 1 ]] && install_native protontricks || true
      ;;
    *debian*|*ubuntu*)
      ensure_debian_components
      install_native mangohud gamemode mesa-vulkan-drivers vulkan-tools wine winetricks
      [[ $INSTALL_PROTONTRICKS -eq 1 ]] && install_native protontricks || true
      ;;
    *arch*|*manjaro*)
      install_native mangohud gamemode vulkan-tools wine winetricks protontricks
      ;;
    *suse*)
      install_native mangohud gamemode vulkan-tools wine winetricks || true
      ;;
  esac
}

install_steam() {
  if [[ $FLATPAK_ONLY -eq 1 ]]; then
    have_flatpak || install_native flatpak; fp_add_flathub
    fp_install flathub com.valvesoftware.Steam; return
  fi
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*) ensure_rpmfusion; install_native steam ;;
    *debian*|*ubuntu*) ensure_debian_components; install_native steam ;;
    *arch*|*manjaro*) install_native steam ;;
    *suse*) install_native steam ;;
  esac
}

install_lutris() {
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*) ensure_rpmfusion; install_native lutris ;;
    *debian*|*ubuntu*)
      if apt-cache policy lutris | grep -q Candidate; then install_native lutris
      else have_flatpak || install_native flatpak; fp_add_flathub; fp_install flathub net.lutris.Lutris; fi
      ;;
    *arch*|*manjaro*) install_native lutris ;;
    *suse*)
      if zypper se -x lutris | grep -q '^i\? | lutris'; then install_native lutris
      else have_flatpak || install_native flatpak; fp_add_flathub; fp_install flathub net.lutris.Lutris; fi
      ;;
  esac
}

install_heroic() {
  have_flatpak || install_native flatpak; fp_add_flathub
  fp_install flathub com.heroicgameslauncher.hgl
}

install_discord() {
  # Native where reasonable; Flatpak fallback
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*) ensure_rpmfusion; install_native discord || true ;;
    *) : ;;
  esac
  if ! command -v discord >/dev/null 2>&1; then
    have_flatpak || install_native flatpak; fp_add_flathub
    fp_install flathub com.discordapp.Discord || true
  fi
}

install_obs_and_extras() {
  [[ $INSTALL_OBS -eq 1 ]] && {
    case "${ID_LIKE:-$ID}" in
      *fedora*|*rhel*) install_native obs-studio ;;
      *debian*|*ubuntu*) install_native obs-studio || { have_flatpak || install_native flatpak; fp_add_flathub; fp_install flathub com.obsproject.Studio; } ;;
      *arch*|*manjaro*) install_native obs-studio ;;
      *suse*) install_native obs-studio || true ;;
    esac
  }
  [[ $INSTALL_GAMESCOPE -eq 1 ]] && {
    case "${ID_LIKE:-$ID}" in
      *fedora*|*rhel*) install_native gamescope ;;
      *debian*|*ubuntu*) install_native gamescope || true ;;
      *arch*|*manjaro*) install_native gamescope ;;
      *suse*) install_native gamescope || true ;;
    esac
  }
  [[ $INSTALL_GOVERLAY -eq 1 ]] && {
    case "${ID_LIKE:-$ID}" in
      *fedora*|*rhel*) install_native goverlay || { have_flatpak || install_native flatpak; fp_add_flathub; fp_install flathub net.lutris.GOverlay; } ;;
      *debian*|*ubuntu*|*arch*|*suse*) have_flatpak || install_native flatpak; fp_add_flathub; fp_install flathub net.lutris.GOverlay ;;
    esac
  }
  [[ $INSTALL_V4L2LOOPBACK -eq 1 ]] && {
    case "${ID_LIKE:-$ID}" in
      *fedora*|*rhel*) install_native v4l2loopback v4l2loopback-utils || true ;;
      *debian*|*ubuntu*) install_native v4l2loopback-dkms v4l2loopback-utils || true ;;
      *arch*|*manjaro*) install_native v4l2loopback-dkms v4l2loopback-utils || true ;;
      *suse*) install_native v4l2loopback-kmp-default v4l2loopback-utils || true ;;
    esac
  }
}

install_proton_helpers() {
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)
      if [[ $INSTALL_PROTONPLUS -eq 1 && ! $(command -v protonplus) ]]; then
        sudo "$DNF_CMD" -y copr enable wehagy/protonplus || true
        sudo "$DNF_CMD" $DNF_INSTALL_FLAGS protonplus || true
      fi
      ;;
  esac
  if [[ $INSTALL_PROTONUPQT -eq 1 ]] && ! command -v protonplus >/dev/null 2>&1; then
    have_flatpak || install_native flatpak; fp_add_flathub
    fp_install flathub net.davidotek.pupgui2 || true
  fi
}

dedupe_apps() {
  [[ $CLEAN_DUPES -eq 1 ]] || return 0
  if command -v steam >/dev/null 2>&1 && fp_present com.valvesoftware.Steam; then fp_remove com.valvesoftware.Steam; fi
  if command -v lutris >/dev/null 2>&1 && fp_present net.lutris.Lutris; then fp_remove net.lutris.Lutris; fi
  if command -v discord >/dev/null 2>&1 && fp_present com.discordapp.Discord; then fp_remove com.discordapp.Discord; fi
  if command -v obs >/dev/null 2>&1 && fp_present com.obsproject.Studio; then fp_remove com.obsproject.Studio; fi
}

ensure_mangohud_config() {
  mkdir -p "$HOME/.config/MangoHud"
  local cfg="$HOME/.config/MangoHud/MangoHud.conf"
  if [[ ! -s "$cfg" ]]; then
    cat > "$cfg" <<'EOF'
version=1
position=top-left
background_alpha=0.4
gpu_stats
gpu_core_clock
gpu_mem_clock
gpu_power
gpu_temp
cpu_stats
cpu_temp
ram
vram
frametime
frame_timing=1
engine_version
vulkan_driver
arch
EOF
  fi
}

# ===== Overlays (games only: Steam wrapper) =====
ov_log() { printf '[Overlays] %s\n' "$*"; }

ov_games_enable() {
  ov_log "Enabling per‑game overlays via Steam wrapper…"
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
  update-desktop-database "$local_desktop" >/dev/null 2>&1 || true

  ov_restart_steam_if_running
  ov_games_status
}

ov_games_disable() {
  ov_log "Disabling per‑game overlays (removing wrapper/desktop)…"
  rm -f "$HOME/scripts/steam_with_overlays.sh" "$HOME/.local/share/applications/steam.desktop" 2>/dev/null || true
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

  # Also clear any live shell vars so overlays stop immediately
  export -n MANGOHUD MANGOHUD_CONFIGFILE ENABLE_VKBASALT VK_INSTANCE_LAYERS VK_LAYER_PATH 2>/dev/null || true
  unset     MANGOHUD MANGOHUD_CONFIGFILE ENABLE_VKBASALT VK_INSTANCE_LAYERS VK_LAYER_PATH 2>/dev/null || true

  ov_restart_steam_if_running
  ov_games_status
}

ov_games_status() {
  echo "[Overlays] Status:"
  [[ -x "$HOME/scripts/steam_with_overlays.sh" ]] \
    && echo "  • Steam wrapper: $HOME/scripts/steam_with_overlays.sh" \
    && grep -E '^Exec=' "$HOME/.local/share/applications/steam.desktop" 2>/dev/null \
    || echo "  • No Steam wrapper"
}

ov_restart_steam_if_running() {
  if pgrep -x steam >/dev/null 2>&1; then
    ov_log "Restarting Steam to apply overlay changes…"
    pkill -x steam || true
    (nohup steam >/dev/null 2>&1 & disown) || true
  fi
}

handle_overlays_only() {
  case "$OVERLAYS_MODE" in
    games) ov_games_enable ;;
    none)  ov_games_disable ;;
    status) ov_games_status ;;
    "") echo "No overlay mode. Use --overlays=games|none|status"; return 1 ;;
    *) echo "Unknown overlay mode: $OVERLAYS_MODE"; return 2 ;;
  esac
}

# ===== Quick path: overlay-only =====
if [[ -n "$OVERLAYS_MODE" && $OVERLAY_ONLY -eq 1 ]]; then
  handle_overlays_only
  exit $?
fi

# ===== Installs =====
echo "==> Installing core gaming stack…"
install_core

if [[ $INSTALL_STEAM -eq 1 ]]; then
  echo "==> Installing Steam…"
  install_steam
fi

if [[ $INSTALL_LUTRIS -eq 1 ]]; then
  echo "==> Installing Lutris…"
  install_lutris
fi

if [[ $INSTALL_HEROIC -eq 1 ]]; then
  echo "==> Installing Heroic…"
  install_heroic
fi

if [[ $INSTALL_DISCORD -eq 1 ]]; then
  echo "==> Installing Discord…"
  install_discord
fi

echo "==> Proton tools…"
install_proton_helpers

echo "==> Extras (bundle dependent)…"
install_obs_and_extras

echo "==> Ensuring MangoHud defaults…"
ensure_mangohud_config

if [[ $KEEP_FLATPAK -eq 0 ]]; then
  echo "==> Cleaning Flatpak duplicates (prefer native)…"
  dedupe_apps
fi

# Optional: apply overlay choice after install
if [[ -n "$OVERLAYS_MODE" ]]; then
  handle_overlays_only || true
fi

echo
echo "✅ Done."
echo "Overlay controls (games only):"
echo "  $HOME/scripts/universal_gaming_setup.sh --overlays=games  --overlay-only"
echo "  $HOME/scripts/universal_gaming_setup.sh --overlays=none   --overlay-only"
echo "  $HOME/scripts/universal_gaming_setup.sh --overlays=status --overlay-only"
echo
echo "Presets:"
echo "  Lite:    core only"
echo "  Normal:  core + Steam/Lutris/Heroic/Discord (default)"
echo "  Full:    Normal + OBS Studio, Gamescope, GOverlay, v4l2loopback"
