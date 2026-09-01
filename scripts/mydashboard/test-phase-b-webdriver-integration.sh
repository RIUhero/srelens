#!/usr/bin/env bash
set -euo pipefail
umask 077

fail() {
  printf 'phase-b-webdriver-integration=failed safe-code=%s\n' "$1" >&2
  exit 1
}

[[ $# -eq 2 || $# -eq 3 ]] || fail invalid-arguments
tauri_driver=$(realpath -e -- "$1") || fail invalid-tauri-driver
native_driver=$(realpath -e -- "$2") || fail invalid-native-driver
application=${3:-}
[[ -x "$tauri_driver" && -x "$native_driver" ]] || fail non-executable-driver
[[ -z "$application" || -x "$application" ]] || fail invalid-application
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
waiter="$script_dir/wait-webdriver-ready.sh"
port=4664
native_port=4665
driver_pid=
fixture=$(mktemp -d /tmp/mydashboard-webdriver-integration.XXXXXX)

cleanup() {
  if [[ -n ${driver_pid:-} ]]; then
    kill -TERM -- "-$driver_pid" 2>/dev/null || true
    for _ in $(seq 1 40); do
      kill -0 "$driver_pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL -- "-$driver_pid" 2>/dev/null || true
    wait "$driver_pid" 2>/dev/null || true
  fi
  rm -rf -- "$fixture"
}
trap cleanup EXIT INT TERM

ss -ltn | grep -qE ":(${port}|${native_port})[[:space:]]" && fail port-busy
ldd "$native_driver" 2>&1 | grep -q 'not found' && fail native-linkage
setsid "$tauri_driver" --port "$port" --native-port "$native_port" \
  --native-host 127.0.0.1 --native-driver "$native_driver" \
  >"$fixture/stdout" 2>"$fixture/stderr" &
driver_pid=$!
"$waiter" "$driver_pid" "http://127.0.0.1:$port/status" 15 >/dev/null
native_pid=$(pgrep -P "$driver_pid" -x WebKitWebDriver | head -1 || true)
[[ -n "$native_pid" ]] || fail native-child-absent
[[ $(ps -o stat= -p "$native_pid") != Z* ]] || fail native-child-zombie
if [[ -n "$application" ]]; then
  response=$(curl --fail --silent --show-error --max-time 30 \
    -H 'content-type: application/json' -X POST "http://127.0.0.1:$port/session" \
    -d "$(jq -cn --arg app "$application" '{capabilities:{alwaysMatch:{"tauri:options":{application:$app}}}}')") \
    || fail application-session-start
  session_id=$(jq -er '.value.sessionId // .sessionId' <<<"$response") \
    || fail application-session-protocol
  curl --fail --silent --show-error --max-time 10 -X DELETE \
    "http://127.0.0.1:$port/session/$session_id" >/dev/null \
    || fail application-session-stop
  session_id=
else
  http_code=$(curl --silent --show-error --max-time 10 -o "$fixture/session-error.json" \
    -w '%{http_code}' -H 'content-type: application/json' -X POST \
    "http://127.0.0.1:$port/session" \
    -d '{"capabilities":{"alwaysMatch":{"tauri:options":{"application":"/campaign/source/missing-feature-off-binary"}}}}') \
    || fail session-request-transport
  [[ "$http_code" != 000 ]] || fail session-request-empty-reply
  jq -e '.value.error | type == "string"' "$fixture/session-error.json" >/dev/null 2>&1 \
    || fail session-error-protocol
fi
cleanup
driver_pid=
[[ -z $(pgrep -x 'tauri-driver|WebKitWebDriver' 2>/dev/null || true) ]] || fail residue
trap - EXIT INT TERM
printf 'phase-b-webdriver-integration=passed process-alive=true listener-bound=true protocol-ready=true session-lifecycle=true residue=0\n'
