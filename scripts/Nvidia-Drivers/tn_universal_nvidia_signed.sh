#!/usr/bin/env bash
# File: ~/scripts/universal_gaming_with_nvidia.sh
# Purpose: Run universal gaming setup with optional NVIDIA driver install control
# Distros: Fedora/RHEL, Ubuntu/Debian, Arch/Manjaro
# Behavior: Delegates gaming to universal_gaming_setup.sh; adds --nvidia flag:
#           --nvidia=repo|skip|site  (default: repo)
#           --nvidia-url=<direct .run URL>  (required for --nvidia=site)

set -Eeuo pipefail

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
  printf '%b\n' "${BLUE}   Team-Nocturnal.com Gaming (+ NVIDIA option) by XsMagical${RESET}"
  printf '%b\n\n' "${BLUE}----------------------------------------------------------${RESET}"
}

log()   { printf '%b\n' "${DIM}==> $*${RESET}"; }
warn()  { printf '%b\n' "${RED}[!]${RESET} $*\n"; }
have()  { command -v "$1" >/dev/null 2>&1; }

trap 'warn "Error on line $LINENO"' ERR

# ===== Defaults / Flags =====
NVIDIA_MODE="repo"      # repo|skip|site
NVIDIA_URL=""
PASS_ARGS=()

usage() {
  cat <<'EOF'
Usage: sudo ./universal_gaming_with_nvidia.sh [gaming-flags...] [--nvidia=repo|skip|site] [--nvidia-url=URL]

Gaming:
  All flags are forwarded to your ~/scripts/universal_gaming_setup.sh unchanged.

NVIDIA Driver (optional):
  --nvidia=repo    Install latest driver from distro repositories (safe, default)
  --nvidia=skip    Skip NVIDIA driver handling
  --nvidia=site    Install NVIDIA from official .run installer (advanced)
  --nvidia-url=URL Direct URL to NVIDIA .run (required with --nvidia=site)

Notes:
- For safe installs across distros, use --nvidia=repo (default).
- To install via your universal signed installer, keep --nvidia=repo and ensure
  ~/scripts/tn_universal_nvidia_signed.sh exists. This wrapper will call it.
- For --nvidia=site you MUST supply --nvidia-url and handle Secure Boot yourself.
EOF
}

parse_args() {
  while (( $# )); do
    case "$1" in
      --nvidia=repo|--nvidia=skip|--nvidia=site)
        NVIDIA_MODE="${1#--nvidia=}";;
      --nvidia=*)
        warn "Unknown --nvidia option value: ${1#--nvidia=}"; exit 2;;
      --nvidia-url=*)
        NVIDIA_URL="${1#--nvidia-url=}";;
      -h|--help)
        usage; exit 0;;
      *)
        PASS_ARGS+=("$1");;
    esac
    shift
  done
}

run() {
  log "$*"
  eval "$@"
}

sb_enabled() { mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot.*enabled'; }

install_nvidia_repo() {
  # Prefer your universal installer if present; otherwise fall back to distro basics
  local uni="$HOME/scripts/tn_universal_nvidia_signed.sh"
  if [[ -x "$uni" ]]; then
    log "Running universal NVIDIA (signed) installer from repo sources..."
    run "sudo \"$uni\" -y"
    return 0
  fi

  # Minimal fallback if the universal script isn't available
  . /etc/os-release 2>/dev/null || true
  if [[ "${ID_LIKE:-}${ID:-}" =~ (fedora|rhel|centos|rocky|almalinux) ]]; then
    have dnf || { warn "dnf not found"; return 1; }
    run "sudo dnf -y install dnf-plugins-core || true"
    run "sudo dnf -y install \
      \"https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm\" \
      \"https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm\" || true"
    run "sudo dnf -y install xorg-x11-drv-nvidia nvidia-settings nvidia-persistenced || true"
  elif [[ "${ID_LIKE:-}${ID:-}" =~ (debian|ubuntu|linuxmint|pop) ]]; then
    have apt-get || { warn "apt-get not found"; return 1; }
    if have ubuntu-drivers; then
      run "sudo apt-get -y install ubuntu-drivers-common mokutil || true"
      run "sudo ubuntu-drivers autoinstall || true"
    else
      run "sudo apt-get -y install nvidia-driver nvidia-settings nvidia-persistenced || true"
    fi
  elif [[ "${ID_LIKE:-}${ID:-}" =~ (arch|manjaro|endeavouros) ]]; then
    have pacman || { warn "pacman not found"; return 1; }
    run "sudo pacman --noconfirm -Syu || true"
    run "sudo pacman --noconfirm -S nvidia-dkms nvidia-utils nvidia-settings || true"
  else
    warn "Unsupported distro for NVIDIA repo install."
    return 1
  fi
}

install_nvidia_site() {
  [[ -n "$NVIDIA_URL" ]] || { warn "--nvidia=site requires --nvidia-url=<direct .run URL>"; exit 2; }
  have wget || have curl || { warn "Need wget or curl to download NVIDIA installer"; exit 2; }
  local tmpdir; tmpdir="$(mktemp -d)"
  local runfile="$tmpdir/nvidia.run"

  if have wget; then
    run "wget -O \"$runfile\" \"$NVIDIA_URL\""
  else
    run "curl -L \"$NVIDIA_URL\" -o \"$runfile\""
  fi

  run "chmod +x \"$runfile\""

  if sb_enabled; then
    warn "Secure Boot is ENABLED. NVIDIA .run installer produces unsigned modules."
    warn "You will need to sign modules or disable Secure Boot. Proceeding anyway..."
  fi

  # Kill display manager to run the .run installer safely (TTY recommended)
  if have systemctl; then
    log "Stopping display manager (graphical.target) to install driver..."
    run "sudo systemctl isolate multi-user.target || true"
  fi

  # Non-interactive flags; adjust as needed
  run "sudo \"$runfile\" --silent --dkms || sudo \"$runfile\" --silent || true"

  log "NVIDIA site installer finished. You may need to handle MOK signing manually if SB is ON."
}

main() {
  print_banner
  [[ $EUID -eq 0 ]] && warn "Run this wrapper as your user; it will sudo as needed."

  parse_args "$@"

  # 1) Run the gaming setup (passes all non-NVIDIA args straight through)
  local gaming="$HOME/scripts/universal_gaming_setup.sh"
  if [[ -x "$gaming" ]]; then
    log "Starting gaming setup..."
    run "\"$gaming\" ${PASS_ARGS[*]:-}"
  else
    warn "Gaming script not found at $gaming. Skipping gaming setup."
  fi

  # 2) Handle NVIDIA as requested
  case "$NVIDIA_MODE" in
    repo)
      log "NVIDIA mode: repo (safe, default)"
      install_nvidia_repo || warn "NVIDIA repo install encountered issues."
      ;;
    skip)
      log "NVIDIA mode: skip — not modifying drivers."
      ;;
    site)
      log "NVIDIA mode: site (.run installer) — advanced/unsupported by distros."
      install_nvidia_site
      ;;
    *)
      warn "Unknown NVIDIA mode: $NVIDIA_MODE"; exit 2;;
  esac

  echo
  echo -e "✅ ${BOLD}Gaming setup complete${RESET} (NVIDIA mode: ${NVIDIA_MODE})."
  echo -e "🔁 ${BOLD}Reboot recommended${RESET} to finalize driver and gaming stack."
}

main "$@"
