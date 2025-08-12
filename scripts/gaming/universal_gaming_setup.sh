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
# • ARM guard: skips Steam on ARM platforms
# • Overlay modes: --overlays=system|steam|none|status with --overlay-only for fast toggling
#
set -euo pipefail

# ---------- Defaults ----------
ASSUME_YES=0
VERBOSE=0
NATIVE_ONLY=0
FLATPAK_ONLY=0

INSTALL_DISCORD=1
INSTALL_HEROIC=1
INSTALL_STEAM=1
INSTALL_LUTRIS=1
INSTALL_PROTONPLUS=1
INSTALL_PROTONUPQT=1

KEEP_FLATPAK=0; CLEAN_DUPES=1
BUNDLE=""                       # lite|normal|full
OVERLAYS_MODE=""                # system|steam|none|status|repair
OVERLAYS_ONLY=0                 # exit before installs

# ---------- Parse args ----------
for arg in "$@"; do
  case "$arg" in
    -y|--yes)           ASSUME_YES=1 ;;
    -v|--verbose)       VERBOSE=1 ;;
    --native-only)      NATIVE_ONLY=1 ;;
    --flatpak-only)     FLATPAK_ONLY=1 ;;
    --no-discord)       INSTALL_DISCORD=0 ;;
    --no-heroic)        INSTALL_HEROIC=0 ;;
    --no-steAM|--no-steam) INSTALL_STEAM=0 ;;
    --no-lutris)        INSTALL_LUTRIS=0 ;;
    --no-protonplus)    INSTALL_PROTONPLUS=0 ;;
    --no-protonupqt)    INSTALL_PROTONUPQT=0 ;;
    --keep-flatpak)     KEEP_FLATPAK=1 ;;
    --no-clean)         CLEAN_DUPES=0 ;;
    --bundle=lite)      BUNDLE="lite" ;;
    --bundle=normal)    BUNDLE="normal" ;;
    --bundle=full)      BUNDLE="full" ;;
    --overlays=none)    OVERLAYS_MODE="none"  ;;   # Disable overlays
    --overlays=steam)   OVERLAYS_MODE="steam" ;;   # Steam-only overlays
    --overlays=system)  OVERLAYS_MODE="system" ;;  # System-wide overlays
    --overlays=status)  OVERLAYS_MODE="status" ;;  # Show current overlay status
    --overlays=repair)  OVERLAYS_MODE="repair" ;;  # Aggressive cleanup, no install
    --overlay-only)     OVERLAYS_ONLY=1 ;;
    -h|--help)
      cat <<'HLP'
Usage: universal_gaming_setup.sh [options]

General:
  -y, --yes            Assume yes for package prompts
  -v, --verbose        Verbose package output
  --native-only        Only native packages (no Flatpaks)
  --flatpak-only       Only Flatpaks (no native)
  --keep-flatpak       Keep Flatpak duplicates even if native exists
  --no-clean           Do not remove duplicates

Per-app toggles:
  --no-steam | --no-lutris | --no-heroic | --no-discord
  --no-protonplus | --no-protonupqt

Bundles:
  --bundle=lite|normal|full

Overlays:
  --overlays=system|steam|none|status|repair
  --overlay-only       Apply/check overlays and exit (no installs)

Examples:
  $0 --overlays=system --overlay-only
  $0 --overlays=steam  --overlay-only
  $0 --overlays=none   --overlay-only
  $0 --bundle=lite -y
HLP
      exit 0 ;;
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
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}\n"
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

# Noninteractive
export DEBIAN_FRONTEND=noninteractive

# ---------- DNF safe flags ----------
DNF_FLAGS="-y --setopt=install_weak_deps=False --best --allowerasing --refresh"
[[ $VERBOSE -eq 1 ]] && DNF_FLAGS="$DNF_FLAGS -v"

# ---------- APT safe flags ----------
APT_INSTALL_FLAGS="-y -o Dpkg::Options::=--force-confnew"
[[ $VERBOSE -eq 1 ]] && APT_INSTALL_FLAGS="$APT_INSTALL_FLAGS -V"

# ---------- Pacman safe flags ----------
PACMAN_FLAGS="--needed --noconfirm"
[[ $VERBOSE -eq 1 ]] && PACMAN_FLAGS="$PACMAN_FLAGS -v"

# ---------- Package helpers ----------
pkg_present() { command -v rpm >/dev/null 2>&1 && rpm -q "$1" >/dev/null 2>&1 || command -v dpkg >/dev/null 2>&1 && dpkg -s "$1" >/dev/null 2>&1 || command -v pacman >/dev/null 2>&1 && pacman -Qi "$1" >/dev/null 2>&1; }
service_running() { systemctl is-active --quiet "$1"; }
have_flatpak() { command -v flatpak >/dev/null 2>&1; }

# ---------- Flatpak (user scope) ----------
fp_user() {
  local cmd="$1"; shift || true
  flatpak --user "$cmd" "$@"
}
flatpak_install_user() { fp_user install -y --noninteractive "$@"; }
flatpak_uninstall_user() { fp_user uninstall -y --delete-data "$@"; }
flatpak_app_present_user() { fp_user list --app --columns=application | grep -qx "$1"; }
flatpak_add_flathub() { fp_user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true; }

# ---------- Debian helpers: enable contrib/non-free and basics ----------
ensure_debian_components() {
  case "${ID_LIKE:-$ID}" in
    *debian*)
      if ! grep -Eq '^\s*deb .* (contrib|non-free)' /etc/apt/sources.list; then
        echo "[Debian] Enabling contrib non-free non-free-firmware…"
        sudo sed -i 's/^\s*deb \(.*\)$/\0 contrib non-free non-free-firmware/' /etc/apt/sources.list || true
      fi
      sudo dpkg --add-architecture i386 2>/dev/null || true
      sudo apt update || true
      ;;
  esac
}

# ---------- Fedora repos ----------
ensure_rpmfusion() {
  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
    echo "[Fedora] Enabling RPM Fusion…"
    sudo dnf ${DNF_FLAGS} install \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
  fi
}

# ---------- Installers ----------
install_native() {
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)
      sudo dnf ${DNF_FLAGS} install "$@"
      ;;
    *debian*|*ubuntu*)
      sudo apt-get update -y || true
      sudo apt-get ${APT_INSTALL_FLAGS} install "$@"
      ;;
    *arch*|*manjaro*|*endeavouros*)
      sudo pacman -S ${PACMAN_FLAGS} "$@"
      ;;
    *suse*|*opensuse*)
      sudo zypper --non-interactive in "$@"
      ;;
    *)
      echo "Unsupported distro family: ${ID_LIKE:-$ID}"; return 1 ;;
  esac
}

remove_native() {
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)   sudo dnf -y remove "$@" ;;
    *debian*|*ubuntu*) sudo apt-get -y remove "$@" ;;
    *arch*|*manjaro*)  sudo pacman -Rns --noconfirm "$@" ;;
    *suse*|*opensuse*) sudo zypper --non-interactive rm "$@" ;;
  esac
}

# ---------- App installers (native-first with Flatpak fallback) ----------
install_discord() {
  if [[ $NATIVE_ONLY -eq 0 ]]; then
    case "${ID_LIKE:-$ID}" in
      *fedora*|*rhel*)
        echo "[Discord] Installing native (RPM Fusion)…"
        install_native discord || true
        ;;
      *debian*|*ubuntu*|*arch*|*suse*)
        : ;; # handled by fallback
    esac
  fi
  if ! command -v discord >/dev/null 2>&1; then
    if [[ $FLATPAK_ONLY -eq 0 ]]; then
      have_flatpak || install_native flatpak
      flatpak_add_flathub
      echo "[Discord] Installing Flatpak (user)…"
      flatpak_install_user flathub com.discordapp.Discord || true
    fi
  fi
}

install_steam() {
  if [[ $FLATPAK_ONLY -eq 1 ]]; then
    have_flatpak || install_native flatpak
    flatpak_add_flathub
    echo "[Steam] Installing Flatpak (user)…"
    flatpak_install_user flathub com.valvesoftware.Steam
    return 0
  fi
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)
      ensure_rpmfusion
      echo "[Steam] Installing native…"
      install_native steam
      ;;
    *debian*|*ubuntu*)
      ensure_debian_components
      echo "[Steam] Installing native…"
      install_native steam
      ;;
    *arch*|*manjaro*)
      echo "[Steam] Installing native…"
      install_native steam
      ;;
    *suse*)
      echo "[Steam] Installing native…"
      install_native steam
      ;;
  esac
}

install_lutris() {
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)
      ensure_rpmfusion
      echo "[Lutris] Installing native…"
      install_native lutris
      ;;
    *debian*|*ubuntu*)
      if apt-cache policy lutris | grep -q Candidate; then
        echo "[Lutris] Installing native…"
        install_native lutris
      else
        have_flatpak || install_native flatpak
        flatpak_add_flathub
        echo "[Lutris] Installing Flatpak (user)…"
        flatpak_install_user flathub net.lutris.Lutris
      fi
      ;;
    *arch*|*manjaro*)
      echo "[Lutris] Installing native…"
      install_native lutris
      ;;
    *suse*)
      if zypper se -x lutris | grep -q '^i\? | lutris'; then
        echo "[Lutris] Installing native…"
        install_native lutris
      else
        have_flatpak || install_native flatpak
        flatpak_add_flathub
        echo "[Lutris] Installing Flatpak (user)…"
        flatpak_install_user flathub net.lutris.Lutris
      fi
      ;;
  esac
}

install_heroic() {
  have_flatpak || install_native flatpak
  flatpak_add_flathub
  echo "[Heroic] Installing Flatpak (user)…"
  flatpak_install_user flathub com.heroicgameslauncher.hgl
}

install_mangohud_gamemode_vulkan_wine() {
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)
      ensure_rpmfusion
      install_native mangohud gamemode vkBasalt vulkan-tools vulkan-validation-layers wine winetricks
      ;;
    *debian*|*ubuntu*)
      ensure_debian_components
      install_native mangohud gamemode mesa-vulkan-drivers vulkan-tools wine winetricks
      ;;
    *arch*|*manjaro*)
      install_native mangohud gamemode vulkan-tools wine winetricks
      ;;
    *suse*)
      install_native mangohud gamemode vulkan-tools wine winetricks || true
      ;;
  esac
}

# ---------- Duplicate cleanup (prefer native) ----------
dedupe_apps() {
  [[ $CLEAN_DUPES -eq 1 ]] || return 0
  # Steam
  if command -v steam >/dev/null 2>&1 && flatpak_app_present_user com.valvesoftware.Steam; then
    echo "[De-dup] Removing Steam Flatpak (native present)…"
    flatpak_uninstall_user com.valvesoftware.Steam || true
  fi
  # Lutris
  if command -v lutris >/dev/null 2>&1 && flatpak_app_present_user net.lutris.Lutris; then
    echo "[De-dup] Removing Lutris Flatpak (native present)…"
    flatpak_uninstall_user net.lutris.Lutris || true
  fi
  # Discord
  if command -v discord >/dev/null 2>&1 && flatpak_app_present_user com.discordapp.Discord; then
    echo "[De-dup] Removing Discord Flatpak (native present)…"
    flatpak_uninstall_user com.discordapp.Discord || true
  fi
}

# ---------- Proton helpers ----------
install_proton_helpers() {
  # ProtonPlus preferred on Fedora via COPR
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)
      if [[ $INSTALL_PROTONPLUS -eq 1 ]]; then
        if ! command -v protonplus >/dev/null 2>&1; then
          echo "[ProtonPlus] Enabling COPR wehagy/protonplus…"
          sudo dnf -y copr enable wehagy/protonplus || true
          sudo dnf ${DNF_FLAGS} install protonplus || true
        fi
      fi
      ;;
  esac

  # ProtonUp-Qt fallback (Flatpak user)
  if [[ $INSTALL_PROTONUPQT -eq 1 && ! command -v protonplus >/dev/null 2>&1 ]]; then
    have_flatpak || install_native flatpak
    flatpak_add_flathub
    if ! flatpak_app_present_user net.davidotek.pupgui2; then
      echo "[ProtonUp-Qt] Installing Flatpak (user)…"
      flatpak_install_user flathub net.davidotek.pupgui2 || true
    fi
  fi
}

# ---------- MangoHud default config ----------
ensure_mangohud_config() {
  mkdir -p "$HOME/.config/MangoHud"
  local cfg="$HOME/.config/MangoHud/MangoHud.conf"
  if [[ ! -s "$cfg" ]]; then
    cat > "$cfg" <<'EOF'
version=1
fps_limit=0
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

# ======================= Overlay helpers (Steam/system/none) ========================
ov_log() { printf '[Overlays] %s\n' "$*"; }

ov_rm_system_env() {
  sudo rm -f /etc/profile.d/tn-gaming-env.sh /etc/environment.d/tn-gaming-env.conf 2>/dev/null || true
  sudo sed -i '/^MANGOHUD=/d;/^MANGOHUD_CONFIGFILE=/d;/^ENABLE_VKBASALT=/d;/^VK_INSTANCE_LAYERS=/d;/^VK_LAYER_PATH=/d' /etc/environment 2>/dev/null || true
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
  systemctl --user show-environment | grep -E 'MANGOHUD|MANGOHUD_CONFIGFILE|ENABLE_VKBASALT|VK_INSTANCE_LAYERS|VK_LAYER_PATH' || echo "  • No overlay vars in user-manager env"
}
# ===================== End overlay helpers =====================

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
      ov_setup_systemwide
      ov_restart_steam_if_running
      ov_log "Mode set to: SYSTEM‑WIDE"
      ;;
    none)
      ov_disable_globals
      ov_rm_steam_wrapper
      ov_status
      ov_log "Mode set to: DISABLED"
      ;;
    status)
      ov_status
      ;;
    repair)
      ov_disable_globals
      ov_rm_steam_wrapper
      ov_status
      ov_log "Mode set to: REPAIR (cleanup only)"
      ;;
    *) echo "Unknown overlay mode: ${OVERLAYS_MODE}"; exit 2 ;;
  esac
  # If user sent only an overlays command or explicitly asked overlay-only, exit now.
  [[ $OVERLAYS_ONLY -eq 1 ]] && exit 0
fi

# ========================= System update & repos ========================
echo "[0/8] Preparing system…"
if [[ $FLATPAK_ONLY -eq 0 ]]; then
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*)
      ensure_rpmfusion
      ;;
    *debian*|*ubuntu*)
      ensure_debian_components
      ;;
    *) : ;;
  esac
fi

# ========================= Installs =========================
step=1

# (1) Core runtime tools
echo "[$((step++))/8] Installing MangoHud/GameMode/Vulkan/Wine…"
install_mangohud_gamemode_vulkan_wine

# (2) Steam
if [[ $INSTALL_STEAM -eq 1 ]]; then
  echo "[$((step++))/8] Installing Steam…"
  install_steam
else
  echo "[$((step++))/8] Skipping Steam per flag."
fi

# (3) Lutris
if [[ $INSTALL_LUTRIS -eq 1 ]]; then
  echo "[$((step++))/8] Installing Lutris…"
  install_lutris
else
  echo "[$((step++))/8] Skipping Lutris per flag."
fi

# (4) Heroic
if [[ $INSTALL_HEROIC -eq 1 ]]; then
  echo "[$((step++))/8] Installing Heroic…"
  install_heroic
else
  echo "[$((step++))/8] Skipping Heroic per flag."
fi

# (5) Discord
if [[ $INSTALL_DISCORD -eq 1 ]]; then
  echo "[$((step++))/8] Installing Discord…"
  install_discord
else
  echo "[$((step++))/8] Skipping Discord per flag."
fi

# (6) Proton helpers
echo "[$((step++))/8] Installing Proton helpers…"
install_proton_helpers

# (7) MangoHud config
echo "[$((step++))/8] Ensuring MangoHud config…"
ensure_mangohud_config

# (8) De-duplicate apps if requested (prefer native)
if [[ $KEEP_FLATPAK -eq 0 ]]; then
  echo "[$((step++))/8] Cleaning duplicates (prefer native)…"
  dedupe_apps
else
  echo "[$((step++))/8] Keeping Flatpak duplicates per flag."
fi

# ----- If user also passed an overlay mode alongside installs, apply it here. -----
if [[ -n "${OVERLAYS_MODE}" && $OVERLAYS_ONLY -eq 0 ]]; then
  case "$OVERLAYS_MODE" in
    steam)
      ov_disable_globals
      ov_setup_steam_wrapper
      ov_restart_steam_if_running
      ;;
    system)
      ov_rm_steam_wrapper
      ov_setup_systemwide
      ov_restart_steam_if_running
      ;;
    none)
      ov_disable_globals
      ov_rm_steam_wrapper
      ov_restart_steam_if_running
      ;;
    status|repair)
      : ;; # already shown earlier
  esac
fi

echo "------------------------------------------------------------"
echo "✅ Done! Native-first gaming stack is ready."
echo "Flags recap:"
echo "  BUNDLE=$BUNDLE NATIVE_ONLY=$NATIVE_ONLY FLATPAK_ONLY=$FLATPAK_ONLY CLEAN_DUPES=$CLEAN_DUPES KEEP_FLATPAK=$KEEP_FLATPAK"
echo
echo "Overlay controls (can be run alone with --overlay-only):"
echo "  • Steam only:  $0 --overlays=steam --overlay-only"
echo "  • System-wide: $0 --overlays=system --overlay-only"
echo "  • Disable:     $0 --overlays=none --overlay-only"
echo "  • Status:      $0 --overlays=status --overlay-only"
echo "  • Repair:      $0 --overlays=repair --overlay-only"
echo "------------------------------------------------------------"
