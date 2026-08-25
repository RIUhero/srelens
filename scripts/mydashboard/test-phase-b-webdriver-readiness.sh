#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
waiter="$script_dir/wait-webdriver-ready.sh"
fixture=$(mktemp -d /tmp/mydashboard-webdriver-readiness.XXXXXX)
server_pid=

cleanup() {
  if [[ -n ${server_pid:-} ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf -- "$fixture"
}
trap cleanup EXIT INT TERM

stop_server() {
  if [[ -n ${server_pid:-} ]]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
    server_pid=
  fi
}

start_server() {
  local mode=$1 port=$2
  node -e '
    const net = require("node:net");
    const http = require("node:http");
    const [mode, port] = process.argv.slice(1);
    if (mode === "empty") {
      net.createServer(socket => socket.end()).listen(Number(port), "127.0.0.1");
    } else {
      http.createServer((_req, res) => {
        res.setHeader("content-type", "application/json");
        res.end(JSON.stringify({value:{ready:mode === "ready",message:"bounded fixture"}}));
      }).listen(Number(port), "127.0.0.1");
    }
  ' "$mode" "$port" >"$fixture/$mode.stdout" 2>"$fixture/$mode.stderr" &
  server_pid=$!
}

expect_failure() {
  local expected=$1 pid=$2 endpoint=$3 timeout=$4 output
  output="$fixture/$expected.output"
  if "$waiter" "$pid" "$endpoint" "$timeout" >"$output" 2>&1; then
    return 1
  fi
  grep -qx "phase-b-webdriver-readiness=failed safe-code=$expected" "$output"
}

expect_failure child-premature-exit 999999 http://127.0.0.1:4561/status 1

start_server not-ready 4562
expect_failure protocol-not-ready "$server_pid" http://127.0.0.1:4562/status 1
stop_server

start_server empty 4563
expect_failure empty-reply "$server_pid" http://127.0.0.1:4563/status 1
stop_server

sleep 3 &
server_pid=$!
expect_failure listener-timeout "$server_pid" http://127.0.0.1:4564/status 1
stop_server

start_server ready 4565
"$waiter" "$server_pid" http://127.0.0.1:4565/status 2 | grep -q 'protocol-ready=true'
stop_server

printf 'phase-b-webdriver-readiness-contract=passed tests=5 bounded=true residue=0\n'
