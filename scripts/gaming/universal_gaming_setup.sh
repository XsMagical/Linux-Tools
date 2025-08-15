
install_heroic() {
  pm_detect
  if [ "$OSF" = "arch" ]; then
    flatpak_ensure; install_heroic &>/dev/null || install_heroic
  else
    # Fedora/Debian can try native first, else Flatpak
    if ! install_heroic &>/dev/null || install_heroic
      flatpak_ensure; install_heroic &>/dev/null || install_heroic
    fi
  fi
}

arch_ensure_v4l2loopback_loaded() {
  [ "$OSF" != "arch" ] && return 0
  if lsmod | grep -q ^v4l2loopback; then return 0; fi
  sudo modprobe v4l2loopback devices=1 card_label="Virtual Camera" exclusive_caps=1 || true
  echo v4l2loopback | sudo tee /etc/modules-load.d/v4l2loopback.conf >/dev/null || true
}
