#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'phase-b-webdriver-readiness=failed safe-code=%s\n' "$1" >&2
  exit 2
}

[[ $# -eq 3 ]] || fail invalid-arguments
driver_pid=$1
endpoint=$2
timeout_seconds=$3
[[ "$driver_pid" =~ ^[1-9][0-9]*$ ]] || fail invalid-pid
[[ "$endpoint" =~ ^http://127\.0\.0\.1:([1-9][0-9]{0,4})/status$ ]] || fail invalid-endpoint
port=${BASH_REMATCH[1]}
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || fail invalid-timeout
(( port <= 65535 )) || fail invalid-endpoint

pid_has_listener_on_port() {
  local port_hex inode fd target
  printf -v port_hex '%04X' "$port"
  for fd in "/proc/$driver_pid/fd/"*; do
    target=$(readlink "$fd" 2>/dev/null || true)
    inode=${target#socket:[}
    inode=${inode%]}
    [[ "$target" == "socket:[$inode]" ]] || continue
    if awk -v port=":$port_hex" -v inode="$inode" \
      '$2 ~ port "$" && $4 == "0A" && $10 == inode {found=1} END {exit !found}' \
      /proc/net/tcp /proc/net/tcp6 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

probe_dir=$(mktemp -d /tmp/mydashboard-webdriver-ready.XXXXXX)
cleanup() { rm -rf -- "$probe_dir"; }
trap cleanup EXIT INT TERM

deadline=$((SECONDS + timeout_seconds))
listener_seen=false
empty_reply_seen=false
protocol_response_seen=false
while (( SECONDS < deadline )); do
  kill -0 "$driver_pid" 2>/dev/null || fail child-premature-exit
  pid_has_listener_on_port && listener_seen=true
  set +e
  curl --silent --show-error --max-time 1 -o "$probe_dir/body" "$endpoint" 2>"$probe_dir/stderr"
  curl_code=$?
  set -e
  if [[ $curl_code -eq 0 ]]; then
    protocol_response_seen=true
    if [[ "$listener_seen" == true ]] && jq -e '.value.ready == true' "$probe_dir/body" >/dev/null 2>&1; then
      printf 'phase-b-webdriver-readiness=passed process-alive=true listener-bound=true protocol-ready=true\n'
      exit 0
    fi
  elif [[ $curl_code -eq 52 ]]; then
    empty_reply_seen=true
  fi
  sleep 0.1
done

[[ "$listener_seen" == true ]] || fail listener-timeout
[[ "$empty_reply_seen" == false ]] || fail empty-reply
[[ "$protocol_response_seen" == false ]] || fail protocol-not-ready
fail readiness-timeout
