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
runtime_lib="$campaign/runtime/root/usr/lib/x86_64-linux-gnu"
gst_plugins="$campaign/runtime/gst-min"
xorg_pid=
original_vt=
xauthority_cleanup_paths=()
xauthority_cleanup_inodes=()

safe_fail() {
  printf 'phase-b-physical-runtime=failed safe-stage=%s\n' "$1" >&2
  exit 1
}

capture_xauthority_cleanup_identity() {
  local candidate inode
  xauthority_cleanup_paths=()
  xauthority_cleanup_inodes=()
  for candidate in "$xauthority" "$xauthority-c" "$xauthority-l" "$xauthority-n"; do
    [[ -e "$candidate" ]] || continue
    [[ -f "$candidate" && ! -L "$candidate" && $(stat -c %h "$candidate") == 1 ]] || continue
    inode=$(stat -c %i "$candidate")
    xauthority_cleanup_paths+=("$candidate")
    xauthority_cleanup_inodes+=("$inode")
  done
}

safe_remove_xauthority() {
  local index candidate inode owner
  for index in "${!xauthority_cleanup_paths[@]}"; do
    candidate=${xauthority_cleanup_paths[$index]}
    inode=${xauthority_cleanup_inodes[$index]}
    [[ -e "$candidate" && -f "$candidate" && ! -L "$candidate" ]] || continue
    [[ $(stat -c %h "$candidate") == 1 && $(stat -c %i "$candidate") == "$inode" ]] || continue
    owner=$(stat -c %U "$candidate")
    [[ "$owner" == "$run_user" || "$owner" == root ]] || continue
    rm -f -- "$candidate"
  done
}

probe_xauthority() {
  xauthority_exists=false
  xauthority_regular=false
  xauthority_owner_valid=false
  xauthority_mode_valid=false
  xauthority_link_count_valid=false
  xauthority_entry_readable=false
  [[ -e "$xauthority" ]] && xauthority_exists=true
  [[ -f "$xauthority" && ! -L "$xauthority" ]] && xauthority_regular=true
  [[ "$xauthority_exists" == true && $(stat -c %U "$xauthority") == "$run_user" ]] && xauthority_owner_valid=true
  [[ "$xauthority_exists" == true && $(stat -c %a "$xauthority") == 600 ]] && xauthority_mode_valid=true
  [[ "$xauthority_exists" == true && $(stat -c %h "$xauthority") == 1 ]] && xauthority_link_count_valid=true
  if [[ "$xauthority_regular" == true && "$xauthority_owner_valid" == true ]]; then
    if /usr/sbin/runuser -u "$run_user" -- env -i \
      HOME="$campaign" USER="$run_user" LOGNAME="$run_user" XAUTHORITY="$xauthority" PATH=/usr/bin:/bin \
      /usr/bin/xauth -f "$xauthority" nlist "$display" 2>/dev/null | grep -q .; then
      xauthority_entry_readable=true
    fi
  fi
}

write_xauthority_safe_receipt() {
  local receipt_tmp
  receipt_tmp=$(mktemp "$results/.xauthority.XXXXXX")
  printf '{"schemaVersion":1,"xauthorityExists":%s,"xauthorityRegular":%s,"xauthorityOwnerValid":%s,"xauthorityModeValid":%s,"xauthorityLinkCountValid":%s,"xauthorityEntryReadable":%s}\n' \
    "$xauthority_exists" "$xauthority_regular" "$xauthority_owner_valid" \
    "$xauthority_mode_valid" "$xauthority_link_count_valid" "$xauthority_entry_readable" >"$receipt_tmp"
  chown "$run_user:$run_user" "$receipt_tmp"
  chmod 0600 "$receipt_tmp"
  mv -f -- "$receipt_tmp" "$results/xauthority-preflight.json"
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
for file in root-harness.sh runner.sh tools/run-phase-b-bwrap.sh tools/wait-webdriver-ready.sh; do
  target="$campaign/$file"
  [[ -f "$target" && ! -L "$target" && $(stat -c %h "$target") == 1 && $(stat -c %U "$target") == "$run_user" && $(stat -c %a "$target") == 700 ]] || safe_fail harness-metadata
done
grep -Fq 'tools/wait-webdriver-ready.sh' "$campaign/runner.sh" || safe_fail runner-readiness-contract
[[ -d "$runtime_lib" && ! -L "$runtime_lib" && -d "$gst_plugins" && ! -L "$gst_plugins" ]] || safe_fail runtime-closure
[[ -f "$campaign/runtime-files.sha256" && ! -L "$campaign/runtime-files.sha256" ]] || safe_fail runtime-file-manifest
[[ -f "$campaign/runtime-symlinks.tsv" && ! -L "$campaign/runtime-symlinks.tsv" ]] || safe_fail runtime-symlink-manifest
(cd "$campaign" && sha256sum --check runtime-files.sha256 >/dev/null) || safe_fail runtime-file-digest
diff -u "$campaign/runtime-symlinks.tsv" \
  <(cd "$campaign/runtime" && find . -type l -printf '%P\t%l\n' | LC_ALL=C sort) \
  >/dev/null || safe_fail runtime-symlink-digest
while IFS= read -r -d '' runtime_link; do
  runtime_target=$(realpath -e -- "$runtime_link") || safe_fail runtime-symlink-target
  case "$runtime_target" in "$campaign/runtime"/*) ;; *) safe_fail runtime-symlink-escape ;; esac
done < <(find "$campaign/runtime" -type l -print0)
linkage=$(LD_LIBRARY_PATH="$runtime_lib" ldd "$campaign/tools/WebKitWebDriver" 2>&1) \
  || safe_fail webdriver-linkage
grep -q 'not found' <<<"$linkage" && safe_fail webdriver-linkage
unset linkage runtime_target
/usr/sbin/runuser -u "$run_user" -- env -i \
  HOME="$campaign" PATH=/usr/bin:/bin LD_LIBRARY_PATH="$runtime_lib" \
  GST_PLUGIN_PATH="$gst_plugins" GST_PLUGIN_SYSTEM_PATH="$gst_plugins" \
  GST_REGISTRY="$results/preflight-gstreamer-registry.bin" \
  "$campaign/tools/WebKitWebDriver" --help >/dev/null 2>&1 || safe_fail webdriver-executable
[[ $(cat /sys/class/drm/card1-DP-1/status) == connected ]] || safe_fail connector
pgrep -f "/usr/lib/xorg/Xorg ${display}( |$)" >/dev/null && safe_fail display-busy

original_vt=$(/usr/bin/fgconsole 2>/dev/null || printf 1)
[[ ! -e "$xauthority" && ! -e "$xauthority-c" && ! -e "$xauthority-l" && ! -e "$xauthority-n" ]] || safe_fail xauthority-preexisting
install -m 0600 -o "$run_user" -g "$run_user" /dev/null "$xauthority"
capture_xauthority_cleanup_identity
cookie=$(/usr/bin/mcookie)
if ! printf 'add %s MIT-MAGIC-COOKIE-1 %s\n' "$display" "$cookie" | \
  /usr/sbin/runuser -u "$run_user" -- env -i \
    HOME="$campaign" USER="$run_user" LOGNAME="$run_user" XAUTHORITY="$xauthority" PATH=/usr/bin:/bin \
    /usr/bin/xauth -f "$xauthority" source - >/dev/null 2>&1; then
  unset cookie
  capture_xauthority_cleanup_identity
  probe_xauthority
  write_xauthority_safe_receipt
  safe_fail xauthority-create
fi
unset cookie
capture_xauthority_cleanup_identity
probe_xauthority
write_xauthority_safe_receipt
[[ "$xauthority_exists" == true && "$xauthority_regular" == true && "$xauthority_owner_valid" == true && "$xauthority_mode_valid" == true && "$xauthority_link_count_valid" == true && "$xauthority_entry_readable" == true ]] || safe_fail xauthority-metadata

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
