#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

core_binary=${1:-target/release/srelens}
if [[ ! -x "$core_binary" || -L "$core_binary" ]]; then
  printf 'core acceptance requires one regular executable: %s\n' "$core_binary" >&2
  exit 2
fi

request_file=$(mktemp)
response_file=$(mktemp)
cleanup() {
  rm -f -- "$request_file" "$response_file"
}
trap cleanup EXIT
chmod 600 "$request_file" "$response_file"

printf '%s\n%s\n' \
  '{"version":1,"operation":"read_projection"}' \
  '{"version":1,"operation":"shutdown"}' >"$request_file"

env -i "$core_binary" --mydashboard-core-stdio \
  <"$request_file" >"$response_file"

mapfile -t responses <"$response_file"
if (( ${#responses[@]} != 2 )); then
  printf 'core acceptance expected exactly two response lines\n' >&2
  exit 3
fi
if [[ ${responses[0]} != '{"status":"ok","version":1,"projection":{"tasks":[]}}' ]]; then
  printf 'core acceptance projection response mismatch\n' >&2
  exit 4
fi
if [[ ${responses[1]} != '{"status":"ok","version":1,"projection":null}' ]]; then
  printf 'core acceptance shutdown response mismatch\n' >&2
  exit 5
fi

if grep -Eqi 'credential|token|oauth|cookie|email|account|session|prompt|filesystem|provider.error|/home/|/tmp/' "$response_file"; then
  printf 'core acceptance response crossed the redaction boundary\n' >&2
  exit 6
fi

printf 'core-process=passed\ncore-projection=passed\ncore-clean-shutdown=passed\nprovider-dispatch=false\ncredential-access=false\n'
