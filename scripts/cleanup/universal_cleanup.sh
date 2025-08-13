#!/usr/bin/env bash
# ==================== Team-Nocturnal Universal Linux Cleanup Script ====================
# Safe-by-default cleanup for Debian/Ubuntu (APT), Fedora/RHEL (DNF/DNF5), Arch/Manjaro (Pacman),
# openSUSE (Zypper), Alpine (APK), plus Flatpak/Snap, user caches, journals, and optional
# Docker/Steam cache pruning, kernel pruning, and bootloader refresh.
#
# Flags:
#   --journal-days=N       Trim systemd journals to N days (default: 14)
#   --aggressive           Deeper cache cleaning (dnf clean all / paccache keep=1 / npm clean / zypper clean -a)
#   --prune-kernels        Prune old kernels using distro-safe methods (never removes running)
#   --docker               Docker prune (images/containers/networks/volumes) with confirm
#   --steam-cache          Clear Steam shader caches and GPU shader caches (safe)
#   --refresh-bootloader   Refresh GRUB/systemd-boot entries after changes (optional)
#   --dry-run              Show actions only (print commands, make no changes)
#   --yes                  Non-interactive (auto-confirm)
#   --no-snap              Skip Snap cleanup
#   --no-flatpak           Skip Flatpak cleanup
#   -h | --help            Help
#
# Exit: 0=ok, 1=error

set -euo pipefail

# ===== Colors & Banner =====
RED="\033[31m"; BLUE="\033[34m"; RESET="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
print_banner() {
  printf '%b\n' "${RED}████████╗███╗   ██╗${RESET}"
  printf '%b\n' "${RED}╚══██╔══╝████╗  ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██╔██╗ ██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║╚██╗██║${RESET}"
  printf '%b\n' "${RED}   ██║   ██║ ╚████║${RESET}"
  printf '%b\n' "${RED}   ╚═╝   ╚═╝  ╚═══╝${RESET}"
  printf '%b\n' "${BLUE}----------------------------------------------------------${RESET}"
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Universal Linux Cleanup Script by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}
print_banner

# ===== Defaults =====
JOURNAL_DAYS=14
AGGRESSIVE=0
PRUNE_KERNELS=0
DOCKER_PRUNE=0
DRY_RUN=0
YES=0
NO_SNAP=0
NO_FLATPAK=0
STEAM_CACHE=0
REFRESH_BOOTLOADER=0

log_dir="${HOME}/cleanup_logs"
mkdir -p "$log_dir"
LOG_FILE="${log_dir}/clean-$(date +%Y%m%d-%H%M).log"
# Tee to file while preserving errors
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
  cat <<'EOF'
Usage: universal_cleanup.sh [options]

Options:
  --journal-days=N       Vacuum systemd journals to N days (default: 14)
  --aggressive           Deeper cache purge (dnf clean all / paccache keep=1 / npm clean / zypper clean -a)
  --prune-kernels        Remove old kernels using distro-safe methods
  --docker               Docker: system prune (unused images/containers/networks/volumes)
  --steam-cache          Clear Steam shader caches and GPU shader caches (safe)
  --refresh-bootloader   Refresh GRUB/systemd-boot entries (optional)
  --dry-run              Show what would run, make no changes
  --yes                  Non-interactive confirmations
  --no-snap              Skip Snap cleanup
  --no-flatpak           Skip Flatpak cleanup
  -h, --help             Show this help
EOF
}

# ===== Arg parse =====
for arg in "$@"; do
  case "$arg" in
    --journal-days=*) JOURNAL_DAYS="${arg#*=}";;
    --aggressive)     AGGRESSIVE=1;;
    --prune-kernels)  PRUNE_KERNELS=1;;
    --docker)         DOCKER_PRUNE=1;;
    --steam-cache)    STEAM_CACHE=1;;
    --refresh-bootloader) REFRESH_BOOTLOADER=1;;
    --dry-run)        DRY_RUN=1;;
    --yes)            YES=1;;
    --no-snap)        NO_SNAP=1;;
    --no-flatpak)     NO_FLATPAK=1;;
    -h|--help)        usage; exit 0;;
    *) echo "Unknown option: $arg"; usage; exit 1;;
  esac
done

# ===== Helpers =====
as_root() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '[DRY-RUN] sudo %q' "$1"; shift || true
    for x in "$@"; do printf ' %q' "$x"; done; printf '\n'
    return 0
  fi
  if [[ $EUID -ne 0 ]]; then sudo "$@"; else "$@"; fi
}

run_cmd() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '[DRY-RUN] %s\n' "$*"
  else
    bash -lc "$*"
  fi
}

confirm() {
  if [[ $YES -eq 1 ]]; then return 0; fi
  read -r -p "$1 [y/N]: " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

pm_detect() {
  if command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf >/dev/null 2>&1; then echo dnf
  elif command -v pacman >/dev/null 2>&1; then echo pacman
  elif command -v zypper >/dev/null 2>&1; then echo zypper
  elif command -v apk >/dev/null 2>&1; then echo apk
  elif command -v rpm-ostree >/dev/null 2>&1 && rpm-ostree status >/dev/null 2>&1; then echo rpm-ostree
  else echo none; fi
}

is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }

detect_bootloader() {
  if command -v bootctl >/dev/null 2>&1 && bootctl is-installed >/dev/null 2>&1; then
    echo "systemd-boot"
  elif command -v grub2-mkconfig >/dev/null 2>&1 || command -v grub-mkconfig >/dev/null 2>&1 \
       || [[ -d /boot/grub2 ]] || compgen -G "/boot/efi/EFI/*/grub.cfg" >/dev/null; then
    echo "grub"
  else
    echo "unknown"
  fi
}

refresh_bootloader() {
  local type cfg osid=""
  type="$(detect_bootloader)"
  echo "-> Refresh bootloader (${type})"
  case "$type" in
    systemd-boot)
      as_root bootctl update || true
      ;;
    grub)
      if [[ -r /etc/os-release ]]; then . /etc/os-release; osid="${ID:-}"; fi
      if [[ "$osid" == "fedora" && -e /boot/grub2/grub.cfg ]]; then
        # Per TN preference (known-good path for Fedora BLS GRUB):
        cfg="/boot/grub2/grub.cfg"
      else
        if [[ -e /boot/grub2/grub.cfg ]]; then
          cfg="/boot/grub2/grub.cfg"
        else
          cfg="$(compgen -G "/boot/efi/EFI/*/grub.cfg" | head -n1 || true)"
        fi
      fi
      if [[ -z "${cfg:-}" ]]; then
        echo "   Could not find grub.cfg path. Skipping."
        return 0
      fi
      if command -v grub2-mkconfig >/dev/null 2>&1; then
        as_root grub2-mkconfig -o "$cfg" || true
      else
        as_root grub-mkconfig -o "$cfg" || true
      fi
      ;;
    *)
      echo "   Unknown bootloader. Skipping refresh."
      ;;
  esac
}

echo "== Universal Cleanup started: $(date)"
echo "Log: $LOG_FILE"

PM="$(pm_detect)"
echo "Detected package manager: ${PM}"
echo "Options -> JOURNAL_DAYS=${JOURNAL_DAYS} AGGRESSIVE=${AGGRESSIVE} PRUNE_KERNELS=${PRUNE_KERNELS} DOCKER=${DOCKER_PRUNE} STEAM_CACHE=${STEAM_CACHE} REFRESH_BOOTLOADER=${REFRESH_BOOTLOADER} DRY_RUN=${DRY_RUN}"

# ===== Package cleanup =====
case "$PM" in
  apt)
    echo "-> APT: autoremove and cache cleanup"
    as_root apt-get update -y || true
    as_root apt-get -y autoremove --purge || true
    if [[ $AGGRESSIVE -eq 1 ]]; then
      as_root apt-get -y clean || true
    else
      as_root apt-get -y autoclean || true
    fi

    if [[ $PRUNE_KERNELS -eq 1 ]]; then
      echo "-> APT: kernel pruning (safe)"
      current="$(uname -r)"
      echo "   Running kernel: $current"
      old_kernels=$(dpkg -l 'linux-image-[0-9]*-generic' 2>/dev/null | awk '/^ii/{print $2}' | grep -v -- "$current" || true)
      if [[ -n "${old_kernels:-}" ]]; then
        echo "   Removing: ${old_kernels//$'\n'/ }"
        # shellcheck disable=SC2086
        as_root apt-get -y remove $old_kernels || true
        as_root apt-get -y autoremove --purge || true
      else
        echo "   No old kernels found."
      fi
    fi
    ;;
  dnf)
    echo "-> DNF: autoremove and cache cleanup"
    as_root dnf -y autoremove || true
    if [[ $AGGRESSIVE -eq 1 ]]; then
      as_root dnf -y clean all || true
    else
      as_root dnf -y clean packages || true
    fi
    if [[ $PRUNE_KERNELS -eq 1 ]]; then
      echo "-> DNF: kernel pruning (safe; keeps running)"
      to_remove="$(dnf repoquery --installonly --latest-limit=-2 -q 2>/dev/null || true)"
      if [[ -z "$to_remove" ]]; then
        echo "   No old installonly packages to remove."
      else
        echo "   Removing:"
        echo "$to_remove" | sed 's/^/     - /'
        if [[ $DRY_RUN -eq 1 ]]; then
          printf '[DRY-RUN] sudo dnf -y remove %s\n' "$to_remove"
        else
          # shellcheck disable=SC2086
          as_root dnf -y remove $to_remove || true
        fi
      fi
    fi
    ;;
  pacman)
    echo "-> Pacman: orphans and cache cleanup"
    if pacman -Qtdq >/dev/null 2>&1; then
      orphans="$(pacman -Qtdq || true)"
      if [[ -n "${orphans:-}" ]]; then
        # shellcheck disable=SC2086
        as_root pacman --noconfirm -Rns $orphans || true
      else
        echo "   No orphaned packages."
      fi
    else
      echo "   Orphan query not available (older pacman?)."
    fi
    if command -v paccache >/dev/null 2>&1; then
      if [[ $AGGRESSIVE -eq 1 ]]; then
        as_root paccache -rk1 || true
        as_root paccache -ruk1 || true
      else
        as_root paccache -rk3 || true
        as_root paccache -ruk3 || true
      fi
    else
      if [[ $AGGRESSIVE -eq 1 ]]; then as_root pacman -Scc --noconfirm || true
      else as_root pacman -Sc --noconfirm || true; fi
    fi
    if [[ $PRUNE_KERNELS -eq 1 ]]; then
      echo "-> Pacman: kernel pruning skipped to avoid breakage (manage linux/linux-lts manually)."
    fi
    ;;
  zypper)
    echo "-> Zypper: remove orphans and clean cache"
    # Remove orphaned packages (if any)
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "[DRY-RUN] zypper packages --orphaned"
    else
      # Remove orphans if present
      orphans="$(zypper --non-interactive --quiet packages --orphaned 2>/dev/null | awk '/^[ip-]/{print $5}' | sed '/^$/d' | sort -u || true)"
      if [[ -n "${orphans:-}" ]]; then
        echo "$orphans" | sed 's/^/   orphan: /'
        # shellcheck disable=SC2086
        as_root zypper --non-interactive remove $orphans || true
      else
        echo "   No orphaned packages."
      fi
    fi
    if [[ $AGGRESSIVE -eq 1 ]]; then
      as_root zypper --non-interactive clean -a || true
    else
      as_root zypper --non-interactive clean || true
    fi
    if [[ $PRUNE_KERNELS -eq 1 ]]; then
      if command -v purge-kernels >/dev/null 2>&1; then
        echo "-> Zypper: kernel pruning via purge-kernels (safe)"
        as_root purge-kernels || true
      else
        echo "-> Zypper: purge-kernels not found; skipping kernel prune."
      fi
    fi
    ;;
  apk)
    echo "-> APK: remove cache"
    # Alpine keeps package cache under /var/cache/apk
    if [[ $AGGRESSIVE -eq 1 ]]; then
      as_root sh -c 'apk cache clean || true; rm -rf /var/cache/apk/* 2>/dev/null || true'
    else
      as_root sh -c 'apk cache clean || true'
    fi
    echo "   Orphan removal is manual on Alpine; skipping."
    if [[ $PRUNE_KERNELS -eq 1 ]]; then
      echo "-> APK: kernel pruning not supported; skipping."
    fi
    ;;
  rpm-ostree)
    echo "-> rpm-ostree: cleaning cached metadata and old deployments (conservative)"
    as_root rpm-ostree cleanup -m || true   # metadata
    as_root rpm-ostree cleanup -r || true   # old refs / pending
    echo "   Use 'rpm-ostree upgrade' to rebase/upgrade base image. Kernel pruning is managed by deployments."
    ;;
  *)
    echo "-> No supported package manager detected; skipping system package cleanup."
    ;;
esac

# ===== Flatpak & Snap =====
if [[ $NO_FLATPAK -eq 0 ]] && command -v flatpak >/dev/null 2>&1; then
  echo "-> Flatpak: uninstall unused & refresh metadata"
  as_root flatpak uninstall --unused -y || true
  as_root flatpak update --appstream -y || true
  if [[ $AGGRESSIVE -eq 1 ]]; then as_root flatpak repair || true; fi

  # EOL runtime warning (example: GNOME 46)
  EOL_APPS="$(flatpak list --app --columns=application,runtime 2>/dev/null | awk '/org\.gnome\.Platform.*46/ {print $1}' || true)"
  if [[ -n "${EOL_APPS:-}" ]]; then
    echo "WARNING: These Flatpak apps still use EOL runtime org.gnome.Platform//46:"
    printf '  - %s\n' ${EOL_APPS}
    echo "  -> Consider switching to native packages or newer Flatpak sources."
  fi
fi

if [[ $NO_SNAP -eq 0 ]] && command -v snap >/dev/null 2>&1; then
  echo "-> Snap: remove disabled revisions"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY-RUN] snap list --all | awk '/disabled/{print \$1, \$3}' | while read n r; do sudo snap remove \"\$n\" --revision=\"\$r\"; done"
  else
    snap list --all | awk '/disabled/{print $1, $3}' | while read -r name rev; do
      as_root snap remove "$name" --revision="$rev" || true
    done
  fi
fi

# ===== Journals & Logs =====
if command -v journalctl >/dev/null 2>&1; then
  echo "-> Journald: vacuum to ${JOURNAL_DAYS} days"
  as_root journalctl --vacuum-time="${JOURNAL_DAYS}d" || true
fi
echo "-> Rotated logs: deleting *.gz older than 30 days in /var/log"
as_root find /var/log -type f -name "*.gz" -mtime +30 -print -delete || true

# ===== User caches =====
echo "-> Cleaning user thumbnail cache"
run_cmd 'rm -rf "${HOME}/.cache/thumbnails/"* 2>/dev/null || true'
echo "-> Emptying user Trash"
run_cmd 'rm -rf "${HOME}/.local/share/Trash/files/"* "${HOME}/.local/share/Trash/info/"* 2>/dev/null || true'

# ===== Dev/tool caches =====
if command -v pip >/dev/null 2>&1; then echo "-> pip cache purge"; run_cmd 'pip cache purge || true'; fi
if command -v pip3 >/dev/null 2>&1; then echo "-> pip3 cache purge"; run_cmd 'pip3 cache purge || true'; fi
if command -v npm >/dev/null 2>&1; then
  echo "-> npm cache"
  if [[ $AGGRESSIVE -eq 1 ]]; then run_cmd 'npm cache clean --force || true'
  else run_cmd 'npm cache verify || true'; fi
fi
if command -v yarn >/dev/null 2>&1; then echo "-> yarn cache clean"; run_cmd 'yarn cache clean || true'; fi
if command -v cargo-cache >/dev/null 2>&1; then echo "-> cargo-cache: clean registries and git db"; run_cmd 'cargo-cache -a || true'; fi

# ===== Steam shader/GPU caches (optional) =====
steam_cache_clean() {
  echo "-> Steam cache cleanup (safe: caches only)"
  local paths=(
    "${HOME}/.local/share/Steam/steamapps/shadercache"
    "${HOME}/.local/share/Steam/steamshadercache"
    "${HOME}/.steam/steam/steamapps/shadercache"
    "${HOME}/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/shadercache"
    "${HOME}/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamshadercache"
    "${HOME}/.cache/mesa_shader_cache" "${HOME}/.cache/mesa_shader_cache_32"
    "${HOME}/.nv/GLCache" "${HOME}/.cache/nv_vulkan" "${HOME}/.cache/steam"
  )
  for p in "${paths[@]}"; do
    if [[ -d "$p" ]]; then
      echo "   clearing: $p"
      if [[ $DRY_RUN -eq 1 ]]; then
        printf '[DRY-RUN] rm -rf %q/*\n' "$p"
      else
        rm -rf "$p"/* 2>/dev/null || true
      fi
    fi
  done
}
if [[ $STEAM_CACHE -eq 1 ]]; then steam_cache_clean; fi

# ===== Docker (optional) =====
if [[ $DOCKER_PRUNE -eq 1 ]] && command -v docker >/dev/null 2>&1; then
  echo "-> Docker: system prune (unused images/containers/networks/volumes)"
  if confirm "Proceed with 'docker system prune -a --volumes'? This removes ALL unused images and dangling volumes."; then
    as_root docker system prune -a --volumes -f || true
  else
    echo "   Skipped Docker prune."
  fi
fi

# ===== Bootloader refresh (optional) =====
if [[ $REFRESH_BOOTLOADER -eq 1 ]]; then
  refresh_bootloader
fi

# ===== WSL note =====
if is_wsl; then echo "-> WSL detected: journald or docker may be non-local. Actions were conservative."; fi

echo "== Cleanup complete: $(date)"
echo "Log saved to: $LOG_FILE"

# ===== Quick Tips =====
# Save to:  ~/scripts/universal_cleanup.sh
# Make executable:  chmod +x ~/scripts/universal_cleanup.sh
# Safe defaults:    ~/scripts/universal_cleanup.sh --yes
# Aggressive run:   ~/scripts/universal_cleanup.sh --aggressive --yes
# Full sweep:       ~/scripts/universal_cleanup.sh --aggressive --prune-kernels --steam-cache --refresh-bootloader --docker --yes
