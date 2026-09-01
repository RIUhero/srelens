#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
waiter="$script_dir/wait-webdriver-ready.sh"
fixture=$(mktemp -d /tmp/mydashboard-webdriver-readiness.XXXXXX)
server_pid=
server_port=
server_sequence=0

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
  local mode=$1 port_file
  server_sequence=$((server_sequence + 1))
  port_file="$fixture/$mode-$server_sequence.port"
  node -e '
    const fs = require("node:fs");
    const net = require("node:net");
    const http = require("node:http");
    const [mode, portFile] = process.argv.slice(1);
    const ready = server => {
      fs.writeFileSync(portFile, `${server.address().port}\n`, {mode: 0o600});
    };
    if (mode === "empty") {
      const server = net.createServer(socket => socket.end());
      server.listen(0, "127.0.0.1", () => ready(server));
    } else {
      const server = http.createServer((_req, res) => {
        res.setHeader("content-type", "application/json");
        res.end(JSON.stringify({value:{ready:mode === "ready",message:"bounded fixture"}}));
      });
      server.listen(0, "127.0.0.1", () => ready(server));
    }
  ' "$mode" "$port_file" >"$fixture/$mode.stdout" 2>"$fixture/$mode.stderr" &
  server_pid=$!
  for _ in {1..100}; do
    if [[ -s "$port_file" ]]; then
      server_port=$(<"$port_file")
      [[ "$server_port" =~ ^[1-9][0-9]*$ ]] || return 1
      return 0
    fi
    kill -0 "$server_pid" 2>/dev/null || {
      printf 'fixture-server=failed mode=%s\n' "$mode" >&2
      sed -n '1,80p' "$fixture/$mode.stderr" >&2
      return 1
    }
    sleep 0.05
  done
  printf 'fixture-server=failed mode=%s reason=listen-timeout\n' "$mode" >&2
  return 1
}

expect_failure() {
  local expected=$1 pid=$2 endpoint=$3 timeout=$4 output
  output="$fixture/$expected.output"
  if "$waiter" "$pid" "$endpoint" "$timeout" >"$output" 2>&1; then
    printf 'expected-failure=missing safe-code=%s\n' "$expected" >&2
    sed -n '1,80p' "$output" >&2
    return 1
  fi
  if ! grep -qx "phase-b-webdriver-readiness=failed safe-code=$expected" "$output"; then
    printf 'expected-failure=mismatch safe-code=%s\n' "$expected" >&2
    sed -n '1,80p' "$output" >&2
    return 1
  fi
}

expect_failure child-premature-exit 99999999 http://127.0.0.1:9/status 1

start_server not-ready
expect_failure protocol-not-ready "$server_pid" "http://127.0.0.1:$server_port/status" 1
stop_server

start_server empty
expect_failure empty-reply "$server_pid" "http://127.0.0.1:$server_port/status" 1
stop_server

sleep 3 &
server_pid=$!
expect_failure listener-timeout "$server_pid" http://127.0.0.1:4564/status 1
stop_server

start_server ready
"$waiter" "$server_pid" "http://127.0.0.1:$server_port/status" 2 | grep -q 'protocol-ready=true'
stop_server

printf 'phase-b-webdriver-readiness-contract=passed tests=5 bounded=true residue=0\n'
