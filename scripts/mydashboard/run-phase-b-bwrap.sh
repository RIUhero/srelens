#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'phase-b-bwrap=failed safe-code=%s\n' "$1" >&2
  exit 2
}

[[ $# -ge 4 ]] || fail invalid-arguments
campaign=$1
results=$2
xauthority=$3
shift 3
x11_socket_dir=${MYDASHBOARD_X11_SOCKET_DIR:-/tmp/.X11-unix}

[[ -d "$campaign" && ! -L "$campaign" ]] || fail invalid-campaign-source
[[ -d "$results" && ! -L "$results" ]] || fail invalid-results-source
[[ -d "$x11_socket_dir" && ! -L "$x11_socket_dir" ]] || fail invalid-x11-source
[[ -f "$xauthority" && ! -L "$xauthority" ]] || fail invalid-xauthority
[[ $(stat -c %u "$campaign") == "$EUID" && $(stat -c %a "$campaign") == 700 ]] || fail unsafe-campaign-metadata
[[ $(stat -c %u "$results") == "$EUID" && $(stat -c %a "$results") == 700 ]] || fail unsafe-results-metadata
[[ $(stat -c %u "$xauthority") == "$EUID" ]] || fail unsafe-xauthority-owner
[[ $(stat -c %a "$xauthority") == 600 && $(stat -c %h "$xauthority") == 1 ]] || fail unsafe-xauthority-metadata

campaign_real=$(realpath -e -- "$campaign") || fail invalid-campaign-source
results_real=$(realpath -e -- "$results") || fail invalid-results-source
case "$results_real" in
  "$campaign_real"/*) ;;
  *) fail results-outside-campaign ;;
esac

exec /usr/bin/bwrap \
  --die-with-parent \
  --new-session \
  --unshare-ipc \
  --unshare-pid \
  --unshare-uts \
  --unshare-cgroup-try \
  --unshare-net \
  --ro-bind /usr /usr \
  --symlink usr/bin /bin \
  --symlink usr/lib /lib \
  --symlink usr/lib64 /lib64 \
  --ro-bind /etc /etc \
  --ro-bind /sys /sys \
  --dev-bind /dev /dev \
  --proc /proc \
  --tmpfs /home \
  --tmpfs /tmp \
  --tmpfs /run \
  --tmpfs /var \
  --dir /tmp/.X11-unix \
  --ro-bind "$x11_socket_dir" /tmp/.X11-unix \
  --tmpfs /campaign \
  --dir /campaign/source \
  --ro-bind "$campaign_real" /campaign/source \
  --dir /results \
  --bind "$results_real" /results \
  --ro-bind "$xauthority" /run/Xauthority \
  --dir /home/runtime \
  --dir /run/runtime \
  --setenv HOME /home/runtime \
  --setenv XDG_CONFIG_HOME /run/runtime/config \
  --setenv XDG_DATA_HOME /run/runtime/data \
  --setenv XDG_CACHE_HOME /run/runtime/cache \
  --setenv XDG_RUNTIME_DIR /run/runtime \
  --setenv XAUTHORITY /run/Xauthority \
  --remount-ro / \
  --chdir /campaign/source \
  -- "$@"
