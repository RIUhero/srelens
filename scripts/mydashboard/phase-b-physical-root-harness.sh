#!/usr/bin/env bash
set -euo pipefail
umask 077

display_number=77
display=":${display_number}"
vt_number=7
watchdog_seconds=600
run_user=karasani
campaign=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
results="$campaign/results"
xauthority="$campaign/Xauthority"
xorg_pid=
original_vt=

safe_fail() {
  printf 'phase-b-physical-runtime=failed safe-stage=%s\n' "$1" >&2
  exit 1
}

safe_remove_xauthority() {
  [[ -e "$xauthority" ]] || return 0
  if [[ -f "$xauthority" && ! -L "$xauthority" && $(stat -c %h "$xauthority") == 1 && $(stat -c %U "$xauthority") == "$run_user" && $(stat -c %a "$xauthority") == 600 ]]; then
    rm -f -- "$xauthority"
  fi
}

cleanup() {
  touch "$results/STOP" 2>/dev/null || true
  if [[ -n ${xorg_pid:-} ]] && kill -0 "$xorg_pid" 2>/dev/null; then
    kill -TERM "$xorg_pid" 2>/dev/null || true
    for _ in $(seq 1 40); do kill -0 "$xorg_pid" 2>/dev/null || break; sleep 0.25; done
    kill -KILL "$xorg_pid" 2>/dev/null || true
  fi
  /usr/bin/chvt "${original_vt:-1}" 2>/dev/null || /usr/bin/chvt 1 2>/dev/null || true
  safe_remove_xauthority
}
trap cleanup EXIT INT TERM

[[ $(hostname -s) == ai-worker ]] || safe_fail host
[[ $EUID -eq 0 ]] || safe_fail root-required
[[ -d "$campaign" && ! -L "$campaign" && -d "$results" && ! -L "$results" ]] || safe_fail campaign
(cd "$campaign" && sha256sum --check manifest.sha256 >/dev/null) || safe_fail manifest
for file in root-harness.sh runner.sh tools/run-phase-b-bwrap.sh; do
  target="$campaign/$file"
  [[ -f "$target" && ! -L "$target" && $(stat -c %h "$target") == 1 && $(stat -c %U "$target") == "$run_user" && $(stat -c %a "$target") == 700 ]] || safe_fail harness-metadata
done
[[ $(cat /sys/class/drm/card1-DP-1/status) == connected ]] || safe_fail connector
pgrep -f "/usr/lib/xorg/Xorg ${display}( |$)" >/dev/null && safe_fail display-busy

original_vt=$(/usr/bin/fgconsole 2>/dev/null || printf 1)
install -m 0600 -o "$run_user" -g "$run_user" /dev/null "$xauthority"
cookie=$(/usr/bin/mcookie)
/usr/bin/xauth -f "$xauthority" add "$display" MIT-MAGIC-COOKIE-1 "$cookie" >/dev/null 2>&1 || safe_fail xauthority-create
[[ -f "$xauthority" && ! -L "$xauthority" && $(stat -c %h "$xauthority") == 1 && $(stat -c %U "$xauthority") == "$run_user" && $(stat -c %a "$xauthority") == 600 ]] || safe_fail xauthority-metadata

/usr/bin/openvt -c "$vt_number" -f -s -- \
  /usr/lib/xorg/Xorg "$display" "vt${vt_number}" -keeptty -noreset \
  -nolisten tcp -auth "$xauthority" -logfile /dev/null
for _ in $(seq 1 80); do
  xorg_pid=$(pgrep -f "/usr/lib/xorg/Xorg ${display}( |$)" | head -1 || true)
  [[ -n "$xorg_pid" && -S "/tmp/.X11-unix/X${display_number}" ]] && break
  sleep 0.25
done
[[ -n "$xorg_pid" ]] || safe_fail xorg-ready
DISPLAY="$display" XAUTHORITY="$xauthority" /usr/bin/xdpyinfo >/dev/null || safe_fail xorg-authority

timeout --signal=TERM --kill-after=10s "${watchdog_seconds}s" \
  /usr/sbin/runuser -u "$run_user" -- env \
    DISPLAY="$display" MYDASHBOARD_X11_SOCKET_DIR=/tmp/.X11-unix \
    "$campaign/tools/run-phase-b-bwrap.sh" "$campaign" "$results" "$xauthority" \
    /campaign/source/runner.sh || safe_fail campaign-runtime

[[ -f "$results/STOP" && -f "$results/phase-b-physical-receipt.json" ]] || safe_fail receipt
cleanup
trap - EXIT INT TERM
pgrep -f "/usr/lib/xorg/Xorg ${display}( |$)" >/dev/null && safe_fail xorg-orphan
[[ $(/usr/bin/fgconsole 2>/dev/null || printf '%s' "$original_vt") == "$original_vt" ]] || safe_fail vt-restore
printf 'phase-b-physical-runtime=passed display=:77 vt=7 watchdog=600s cleanup=passed\n'
