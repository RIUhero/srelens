#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
runner="$script_dir/run-phase-b-bwrap.sh"
fixture=$(mktemp -d /tmp/mydashboard-bwrap-contract.XXXXXX)
campaign="$fixture/campaign"
results="$campaign/results"
x11="$fixture/x11"
xauthority="$fixture/Xauthority"
host_private="$fixture/host-private"

cleanup() {
  chmod -R u+rwX "$fixture" 2>/dev/null || true
  rm -rf -- "$fixture"
}
trap cleanup EXIT INT TERM

mkdir -m 0700 "$campaign" "$results" "$x11" "$host_private"
mkdir -p "$campaign/runtime/root/usr/lib/x86_64-linux-gnu" "$campaign/runtime/gst-min"
printf 'read-only artifact\n' >"$campaign/artifact"
chmod 0400 "$campaign/artifact"
printf 'must remain hidden\n' >"$host_private/sentinel"
ln -s "$host_private/sentinel" "$campaign/symlink-escape"

# Pre-creating the authority file avoids xauth's missing-file warning while
# preserving a one-link, owner-only boundary. The cookie never reaches output.
install -m 0600 /dev/null "$xauthority"
if command -v xauth >/dev/null; then
  xauth -f "$xauthority" add :199 MIT-MAGIC-COOKIE-1 00112233445566778899aabbccddeeff >/dev/null 2>&1
fi
[[ -f "$xauthority" && ! -L "$xauthority" && $(stat -c %h "$xauthority") == 1 ]]
[[ $(stat -c %u "$xauthority") == "$EUID" && $(stat -c %a "$xauthority") == 600 ]]

count_comm() {
  local wanted=$1 count=0 proc comm
  for proc in /proc/[0-9]*; do
    [[ -r "$proc/comm" ]] || continue
    read -r comm <"$proc/comm" || true
    [[ "$comm" == "$wanted" ]] && count=$((count + 1))
  done
  printf '%s\n' "$count"
}

before_srelens=$(count_comm srelens)
before_bwrap=$(count_comm bwrap)

# Reproduce the incident without revealing the raw mount path or stderr.
old_error="$fixture/old.stderr"
if bwrap --ro-bind / / --ro-bind "$campaign" /campaign /bin/true 2>"$old_error"; then
  printf 'contract=failed safe-code=missing-campaign-not-reproduced\n' >&2
  exit 1
fi
grep -q "Can't mkdir /campaign: Read-only file system" "$old_error"

MYDASHBOARD_X11_SOCKET_DIR="$x11" "$runner" "$campaign" "$results" "$xauthority" \
  /bin/sh -ceu '
    test -d /campaign/source
    test -d /results
    test ! -e /host-private
    test ! -e /home/host-private
    test ! -e /campaign/source/symlink-escape
    test "$LD_LIBRARY_PATH" = /campaign/source/runtime/root/usr/lib/x86_64-linux-gnu
    test "$GST_PLUGIN_PATH" = /campaign/source/runtime/gst-min
    test "$GST_PLUGIN_SYSTEM_PATH" = /campaign/source/runtime/gst-min
    test "$GST_REGISTRY" = /run/runtime/gstreamer-registry.bin
    touch /campaign/ephemeral
    test -f /campaign/ephemeral
    ! touch /outside-root 2>/dev/null
    ! touch /usr/system-mutation 2>/dev/null
    ! touch /campaign/source/artifact 2>/dev/null
    ! touch /campaign/source/runtime/root/usr/lib/x86_64-linux-gnu/mutation 2>/dev/null
    ! sh -c "printf mutation >>/campaign/source/artifact" 2>/dev/null
    printf bounded > /results/contract-receipt
    test "$(cat /results/contract-receipt)" = bounded
    python3 - <<"PY"
import socket
s = socket.socket()
s.settimeout(0.2)
try:
    s.connect(("1.1.1.1", 53))
except OSError:
    raise SystemExit(0)
raise SystemExit(1)
PY
  '

[[ $(cat "$results/contract-receipt") == bounded ]]
[[ $(cat "$campaign/artifact") == 'read-only artifact' ]]

# Invalid sources and escape-shaped metadata fail closed with fixed safe codes.
invalid_stderr="$fixture/invalid.stderr"
if MYDASHBOARD_X11_SOCKET_DIR="$x11" "$runner" "$fixture/missing" "$results" "$xauthority" /bin/true 2>"$invalid_stderr"; then
  exit 1
fi
grep -qx 'phase-b-bwrap=failed safe-code=invalid-campaign-source' "$invalid_stderr"

ln -s "$campaign" "$fixture/campaign-link"
if MYDASHBOARD_X11_SOCKET_DIR="$x11" "$runner" "$fixture/campaign-link" "$results" "$xauthority" /bin/true >/dev/null 2>&1; then
  exit 1
fi

ln "$xauthority" "$fixture/Xauthority-hardlink"
if MYDASHBOARD_X11_SOCKET_DIR="$x11" "$runner" "$campaign" "$results" "$xauthority" /bin/true >/dev/null 2>&1; then
  exit 1
fi
rm "$fixture/Xauthority-hardlink"

# Early command failure propagates without starting any product process.
if MYDASHBOARD_X11_SOCKET_DIR="$x11" "$runner" "$campaign" "$results" "$xauthority" /bin/sh -c 'exit 37' >/dev/null 2>&1; then
  exit 1
else
  [[ $? == 37 ]]
fi

[[ $(count_comm srelens) == "$before_srelens" ]]
[[ $(count_comm bwrap) == "$before_bwrap" ]]
[[ ! -e "$results/provider-dispatch" && ! -e "$results/core-started" ]]
printf 'phase-b-bwrap-contract=passed tests=22 provider-dispatch=false core-started=false residue=0\n'
