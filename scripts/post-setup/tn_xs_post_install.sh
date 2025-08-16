#!/usr/bin/env bash
# Team Nocturnal — Universal Post-Install Script by XsMagical
# Per-package reporting (✅ ☑️ ➖ ❌) + final roll-up summary + end-of-run checklist
# Auto-enables Packman on openSUSE for media/full presets, with openSUSE name fixes.

# ===== Colors =====
RED="\033[31m"; BLUE="\033[34m"; RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
GREEN="\033[32m"; YELLOW="\033[33m"

print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal Post-Install Script by XsMagical${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
}

# Re-exec in bash if invoked via sh/dash
if [ -z "${BASH_VERSION:-}" ]; then exec bash "$0" "$@"; fi
# (No 'set -e'; we continue past individual package errors.)

# ===== Logging =====
log_dir="${HOME}/scripts/logs"; mkdir -p "$log_dir"
LOG_FILE="${log_dir}/post_install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "${LOG_FILE}") 2>&1

step() { printf '%b\n' "${BOLD}${BLUE}==>${RESET} $*"; }
info() { printf '%b\n' "ℹ  $*"; }
warn() { printf '%b\n' "${YELLOW}⚠${RESET}  $*"; }
ok()   { printf '%b\n' "${GREEN}✅${RESET} $*"; }

# ===== CLI =====
ASSUME_YES=0
PRESET="general"
while getopts ":y" opt; do
  case "$opt" in
    y) ASSUME_YES=1 ;;
    \?) ;;  # ignore others
  esac
done
shift $((OPTIND-1))
if [[ $# -ge 1 ]]; then
  case "$1" in gaming|media|general|lite|full) PRESET="$1"; shift ;; esac
fi

# ===== Privilege warm-up =====
SUDO=""
if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; $SUDO -v || true; fi

print_banner
step "Log: ${LOG_FILE}"

# ===== Distro Detect =====
DISTRO="unknown"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  case "${ID_LIKE:-$ID}" in
    *fedora*|*rhel*|*centos*) DISTRO="fedora" ;;
    *debian*|*ubuntu*)        DISTRO="debian" ;;
    *arch*)                   DISTRO="arch" ;;
    *suse*)                   DISTRO="opensuse" ;;
    *) DISTRO="${ID:-unknown}" ;;
  esac
fi
info "Detected distro: ${DISTRO}"

# ===== Package helpers =====
DNF_FLAGS=(--best --allowerasing --skip-broken)

pm_refresh() {
  case "$DISTRO" in
    fedora)   ${SUDO} sh -c 'command -v dnf5 &>/dev/null && dnf5 -q makecache || dnf -q makecache' || true ;;
    debian)   ${SUDO} apt-get update || true ;;
    arch)     ${SUDO} pacman -Sy --noconfirm || true ;;
    opensuse) ${SUDO} zypper -n refresh || true ;;
    *) true ;;
  esac
}

pkg_installed() {
  local pkg="${1:-}"; [[ -z "$pkg" ]] && return 1
  case "$DISTRO" in
    fedora)
      rpm -q "$pkg" &>/dev/null || \
      { command -v dnf5 &>/dev/null && dnf5 -q list installed "$pkg" &>/dev/null; } || \
      { command -v dnf  &>/dev/null && dnf  -q list installed "$pkg" &>/dev/null; }
      ;;
    debian)   dpkg -s "$pkg" &>/dev/null ;;
    arch)     pacman -Qi "$pkg" &>/dev/null ;;
    opensuse) rpm -q "$pkg" &>/dev/null ;;
    *) return 1 ;;
  esac
}

pkg_available() {
  local pkg="${1:-}"; [[ -z "$pkg" ]] && return 1
  case "$DISTRO" in
    fedora)   (dnf -q list "$pkg" 2>/dev/null || dnf5 -q list "$pkg" 2>/dev/null) | grep -qE 'Installed|Available' ;;
    debian)   apt-cache policy "$pkg" 2>/dev/null | awk -F': ' '/Candidate:/ {print $2}' | grep -vq '(none)' ;;
    arch)     pacman -Si "$pkg" &>/dev/null ;;
    opensuse)
      # exact-name search in the structured table output
      zypper -n se -t package -s -x "$pkg" 2>/dev/null | grep -i -qE "\|${pkg}\|"
      ;;
    *) return 1 ;;
  esac
}

# ===== Per-batch + Global status tracking =====
PKG_INSTALLED_NEW=(); PKG_ALREADY=(); PKG_SKIPPED=(); PKG_FAILED=()
G_INSTALLED_NEW=();  G_ALREADY=();  G_SKIPPED=();  G_FAILED=()

try_install_pkg() {
  local pkg="$1"; [[ -z "$pkg" ]] && return 0

  if pkg_installed "$pkg"; then PKG_ALREADY+=("$pkg"); G_ALREADY+=("$pkg"); return 0; fi
  if ! pkg_available "$pkg"; then PKG_SKIPPED+=("$pkg"); G_SKIPPED+=("$pkg"); return 0; fi

  local rc=0
  case "$DISTRO" in
    fedora)
      if command -v dnf5 &>/dev/null; then
        ${SUDO} dnf5 install "${DNF_FLAGS[@]}" $([[ $ASSUME_YES -eq 1 ]] && echo -y) "$pkg"; rc=$?
      else
        ${SUDO} dnf  install "${DNF_FLAGS[@]}" $([[ $ASSUME_YES -eq 1 ]] && echo -y) "$pkg"; rc=$?
      fi
      ;;
    debian)   ${SUDO} apt-get install $([[ $ASSUME_YES -eq 1 ]] && echo -y) "$pkg"; rc=$? ;;
    arch)     ${SUDO} pacman -S --noconfirm --needed "$pkg"; rc=$? ;;
    opensuse) ${SUDO} zypper -n --gpg-auto-import-keys in --no-confirm "$pkg"; rc=$? ;;
    *)        rc=1 ;;
  esac

  if [[ $rc -eq 0 ]] && pkg_installed "$pkg"; then
    PKG_INSTALLED_NEW+=("$pkg"); G_INSTALLED_NEW+=("$pkg")
  else
    # If install failed on openSUSE and it's not actually in repos, count as Skipped.
    if [[ "$DISTRO" == "opensuse" ]] && ! pkg_available "$pkg"; then
      PKG_SKIPPED+=("$pkg"); G_SKIPPED+=("$pkg")
    else
      PKG_FAILED+=("$pkg"); G_FAILED+=("$pkg")
    fi
  fi
}

pm_install_list() {
  local pkgs=("$@"); [[ ${#pkgs[@]} -eq 0 ]] && return 0
  PKG_INSTALLED_NEW=(); PKG_ALREADY=(); PKG_SKIPPED=(); PKG_FAILED=()
  for p in "${pkgs[@]}"; do try_install_pkg "$p"; done
  summarize_pkg_batch
}

summarize_pkg_batch() {
  local n_new=${#PKG_INSTALLED_NEW[@]}
  local n_alr=${#PKG_ALREADY[@]}
  local n_skp=${#PKG_SKIPPED[@]}
  local n_fail=${#PKG_FAILED[@]}

  echo
  printf '%b\n' "${BOLD}Package Summary:${RESET}"
  [[ $n_new  -gt 0 ]] && { printf '%b ' "✅ Installed ($n_new):";   printf '%s ' "${PKG_INSTALLED_NEW[@]}"; echo; }
  [[ $n_alr  -gt 0 ]] && { printf '%b ' "☑️  Already ($n_alr):";    printf '%s ' "${PKG_ALREADY[@]}";        echo; }
  [[ $n_skp  -gt 0 ]] && { printf '%b ' "➖ Skipped ($n_skp):";     printf '%s ' "${PKG_SKIPPED[@]}";         echo; }
  [[ $n_fail -gt 0 ]] && { printf '%b ' "❌ Failed ($n_fail):";     printf '%s ' "${PKG_FAILED[@]}";          echo; }
  [[ $n_new -eq 0 && $n_alr -eq 0 && $n_skp -eq 0 && $n_fail -eq 0 ]] && echo "(no packages in this batch)"
  echo
}

print_final_summary() {
  local n_new=${#G_INSTALLED_NEW[@]}
  local n_alr=${#G_ALREADY[@]}
  local n_skp=${#G_SKIPPED[@]}
  local n_fail=${#G_FAILED[@]}

  echo
  printf '%b\n' "${BOLD}${BLUE}==>${RESET} Final Summary"
  [[ $n_new  -gt 0 ]] && { printf '%b ' "✅ Installed ($n_new):";   printf '%s ' "${G_INSTALLED_NEW[@]}"; echo; }
  [[ $n_alr  -gt 0 ]] && { printf '%b ' "☑️  Already ($n_alr):";    printf '%s ' "${G_ALREADY[@]}";        echo; }
  [[ $n_skp  -gt 0 ]] && { printf '%b ' "➖ Skipped ($n_skp):";     printf '%s ' "${G_SKIPPED[@]}";         echo; }
  [[ $n_fail -gt 0 ]] && { printf '%b ' "❌ Failed ($n_fail):";     printf '%s ' "${G_FAILED[@]}";          echo; }
  [[ $n_new -eq 0 && $n_alr -eq 0 && $n_skp -eq 0 && $n_fail -eq 0 ]] && echo "(no packages processed)"
  echo
}

# NEW: end-of-run checklist (one line per package, easy to scan, with icons)
print_end_checklist() {
  echo
  printf '%b\n' "${BOLD}${BLUE}==>${RESET} End-of-Run Checklist"
  if [[ ${#G_INSTALLED_NEW[@]} -gt 0 ]]; then
    printf '%b\n' "✅ Installed:"
    printf '%s\n' "${G_INSTALLED_NEW[@]}" | sort -u | sed 's/^/  ✅ /'
  fi
  if [[ ${#G_ALREADY[@]} -gt 0 ]]; then
    printf '%b\n' "☑️  Already present:"
    printf '%s\n' "${G_ALREADY[@]}" | sort -u | sed 's/^/  ☑️  /'
  fi
  if [[ ${#G_SKIPPED[@]} -gt 0 ]]; then
    printf '%b\n' "➖ Skipped (not in repos):"
    printf '%s\n' "${G_SKIPPED[@]}" | sort -u | sed 's/^/  ➖ /'
  fi
  if [[ ${#G_FAILED[@]} -gt 0 ]]; then
    printf '%b\n' "❌ Failed (errors/conflicts):"
    printf '%s\n' "${G_FAILED[@]}" | sort -u | sed 's/^/  ❌ /'
  fi
  if [[ ${#G_INSTALLED_NEW[@]} -eq 0 && ${#G_ALREADY[@]} -eq 0 && ${#G_SKIPPED[@]} -eq 0 && ${#G_FAILED[@]} -eq 0 ]]; then
    echo "(no packages processed)"
  fi
  echo
}

# ===== Fedora-only: RPM Fusion =====
enable_rpmfusion() {
  [[ "$DISTRO" != "fedora" ]] && return 0
  step "Ensuring RPM Fusion (free & nonfree) is enabled"
  local rel; rel="$(rpm -E %fedora 2>/dev/null)"
  pm_install_list "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${rel}.noarch.rpm"
  pm_install_list "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${rel}.noarch.rpm"
  ok "RPM Fusion ensured"
}

# ===== openSUSE-only: Packman (runs for media/full) =====
enable_packman_opensuse() {
  [[ "$DISTRO" != "opensuse" ]] && return 0
  step "Checking for Packman repository"
  if ! zypper lr -u | grep -qi packman; then
    info "Adding Packman repo (Tumbleweed)"
    ${SUDO} zypper -n ar -cfp 90 https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman || warn "Failed to add Packman repo"
  else
    info "Packman repo already exists"
  fi

  step "Refreshing repositories"
  ${SUDO} zypper -n refresh

  step "Switching multimedia packages to Packman vendor"
  ${SUDO} zypper -n dup --from packman --allow-vendor-change || warn "Vendor switch failed (can be re-run later)"

  ok "Packman enabled and multimedia vendor switch complete"
}

# ===== openSUSE name fixes =====
suse_fix_media_names() {
  [[ "$DISTRO" != "opensuse" ]] && return 0
  # ffmpeg versions if unversioned isn't available
  if ! pkg_available "ffmpeg"; then
    for alt in ffmpeg-7 ffmpeg-6 ffmpeg-5; do
      if pkg_available "$alt"; then
        local new=()
        for p in "${PKGS[@]}"; do
          [[ "$p" == "ffmpeg" ]] && new+=("$alt") || new+=("$p")
        done
        PKGS=("${new[@]}")
        info "Using $alt in place of ffmpeg"
        break
      fi
    done
  fi
  # Prefer HandBrake GUI package name on openSUSE
  if ! pkg_available "HandBrake" && pkg_available "ghb"; then
    local new=()
    for p in "${PKGS[@]}"; do
      [[ "$p" == "HandBrake" ]] && new+=("ghb") || new+=("$p")
    done
    PKGS=("${new[@]}")
    info "Using ghb in place of HandBrake"
  fi
  # CLI fallback handbrake-cli if HandBrake-cli is not available
  if ! pkg_available "HandBrake-cli" && pkg_available "handbrake-cli"; then
    local new=()
    for p in "${PKGS[@]}"; do
      [[ "$p" == "HandBrake-cli" ]] && new+=("handbrake-cli") || new+=("$p")
    done
    PKGS=("${new[@]}")
    info "Using handbrake-cli in place of HandBrake-cli"
  fi
}

# ===== Package Sets =====
add_general_packages() {
  PKGS=()
  case "$DISTRO" in
    fedora)   PKGS+=( curl wget git vim htop btop unzip p7zip p7zip-plugins neofetch tlp ) ;;
    debian)   PKGS+=( curl wget git vim htop btop unzip p7zip-full p7zip-rar neofetch tlp ) ;;
    arch)     PKGS+=( curl wget git vim htop btop unzip p7zip neofetch tlp ) ;;
    opensuse) PKGS+=( curl wget git vim htop btop unzip 7zip fastfetch ) ;;  # openSUSE: 7zip (not p7zip)
  esac
}

add_media_packages() {
  case "$DISTRO" in
    fedora)
      PKGS+=( vlc mpv celluloid ffmpeg handbrake gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugins-ugly-free gstreamer1-plugins-ugly gstreamer1-libav qbittorrent )
      ;;
    debian)
      PKGS+=( vlc mpv celluloid ffmpeg handbrake gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav libavcodec-extra qbittorrent )
      ;;
    arch)
      PKGS+=( vlc mpv celluloid ffmpeg handbrake gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav qbittorrent )
      ;;
    opensuse)
      # openSUSE: HandBrake GUI (preferred) + CLI (if present)
      PKGS+=( vlc mpv celluloid ffmpeg HandBrake HandBrake-cli gstreamer-plugins-base gstreamer-plugins-good gstreamer-plugins-bad gstreamer-plugins-ugly gstreamer-plugins-libav qbittorrent )
      ;;
  esac
}

add_gaming_packages() {
  case "$DISTRO" in
    fedora)   PKGS+=( steam lutris heroic-games-launcher discord mangohud gamemode wine winetricks vulkan-tools ) ;;
    debian)   ensure_debian_components; PKGS+=( steam lutris heroic discord mangohud gamemode wine winetricks vulkan-tools ) ;;
    arch)     PKGS+=( steam lutris heroic-games-launcher discord mangohud gamemode wine winetricks vulkan-tools ) ;;
    opensuse) PKGS+=( steam lutris heroic-games-launcher discord mangohud gamemode wine winetricks vulkan-tools ) ;;
  esac
}

add_devvirt_packages() {
  case "$DISTRO" in
    fedora)   PKGS+=( gcc make cmake clang pkgconf kernel-devel qemu-kvm libvirt virt-install virt-manager edk2-ovmf ) ;;
    debian)   PKGS+=( build-essential "linux-headers-$(uname -r)" qemu-system libvirt-daemon-system libvirt-clients virtinst virt-manager ovmf ) ;;
    arch)     PKGS+=( base-devel clang cmake qemu libvirt virt-manager edk2-ovmf ) ;;
    opensuse) PKGS+=( gcc make cmake clang kernel-default-devel qemu libvirt virt-install virt-manager ovmf ) ;;  # qemu (not qemu-kvm)
  esac
}

# ===== Presets =====
run_general_preset() {
  step "General tools"
  add_general_packages
  pm_refresh
  pm_install_list "${PKGS[@]}"
  ok "General tools attempted"
}

run_media_preset() {
  [[ "$DISTRO" == "opensuse" ]] && enable_packman_opensuse
  step "Media tools"
  PKGS=(); add_media_packages
  [[ "$DISTRO" == "opensuse" ]] && suse_fix_media_names
  pm_refresh
  pm_install_list "${PKGS[@]}"
  ok "Media tools attempted"
}

run_gaming_preset() {
  step "Gaming stack"
  PKGS=(); add_gaming_packages
  pm_refresh
  pm_install_list "${PKGS[@]}"
  ok "Gaming stack attempted"
}

run_lite_preset() { run_general_preset; }

run_full_preset() {
  run_general_preset
  # Packman will be ensured inside media preset to avoid duplicate log spam
  run_media_preset

  # Dev/virt last
  PKGS=(); add_devvirt_packages
  step "Dev/Virtualization stack"
  pm_refresh
  pm_install_list "${PKGS[@]}"

  step "Configuring libvirt (sockets, groups, default network)"
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemd not found; skipping libvirt setup"; ok "Dev/Virtualization stack attempted"; return 0
  fi
  systemctl list-unit-files --type=socket | grep -q '^virtlogd\.socket'  && ${SUDO} systemctl enable --now virtlogd.socket  || true
  systemctl list-unit-files --type=socket | grep -q '^virtlockd\.socket' && ${SUDO} systemctl enable --now virtlockd.socket || true
  if systemctl list-unit-files --type=socket | grep -q '^virtqemud\.socket'; then
    ${SUDO} systemctl enable --now virtqemud.socket virtqemud-ro.socket virtqemud-admin.socket || true
  else
    systemctl list-unit-files --type=service | grep -q '^libvirtd\.service' && ${SUDO} systemctl enable --now libvirtd.service || true
  fi
  getent group libvirt >/dev/null 2>&1 && ${SUDO} usermod -aG libvirt "$USER" || true
  getent group kvm     >/dev/null 2>&1 && ${SUDO} usermod -aG kvm     "$USER" || true
  if command -v virsh >/dev/null 2>&1; then
    ${SUDO} virsh net-autostart default 2>/dev/null || true
    ${SUDO} virsh net-start     default 2>/dev/null || true
  fi
  ok "Dev/Virtualization stack attempted"
}

# ===== Fedora preflight =====
[[ "$DISTRO" == "fedora" ]] && enable_rpmfusion

# ===== Run =====
case "$PRESET" in
  gaming)  run_gaming_preset ;;
  media)   run_media_preset ;;
  general) run_general_preset ;;
  lite)    run_lite_preset ;;
  full)    run_full_preset ;;
  *)       run_general_preset ;;
esac

# ===== Final Summary + End-of-Run Checklist =====
print_final_summary
print_end_checklist

echo
ok "Post-install complete. Log: ${LOG_FILE}"
