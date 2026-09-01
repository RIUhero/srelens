#!/usr/bin/env bash
set -euo pipefail

expected_head=${MYDASHBOARD_EXPECTED_HEAD:?set MYDASHBOARD_EXPECTED_HEAD to the exact candidate SHA}
receipt_dir=${MYDASHBOARD_RECEIPT_DIR:-}

actual_head=$(git rev-parse HEAD)
actual_tree=$(git rev-parse 'HEAD^{tree}')
if [[ "$actual_head" != "$expected_head" ]]; then
  printf 'candidate mismatch: expected=%s actual=%s\n' "$expected_head" "$actual_head" >&2
  exit 2
fi

git diff --quiet
git diff --cached --quiet
test -f Cargo.lock
test -f pnpm-lock.yaml

required_commands=(cc c++ git node pkg-config pnpm rustc cargo sha256sum)
required_pc=(
  glib-2.0
  gtk+-3.0
  webkit2gtk-4.1
  javascriptcoregtk-4.1
  ayatana-appindicator3-0.1
  librsvg-2.0
  openssl
)
missing=0

for command_name in "${required_commands[@]}"; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'missing-command=%s\n' "$command_name" >&2
    missing=1
  fi
done

for module in "${required_pc[@]}"; do
  if pkg-config --exists "$module"; then
    printf 'pkg-config=%s@%s\n' "$module" "$(pkg-config --modversion "$module")"
  else
    printf 'missing-pkg-config=%s\n' "$module" >&2
    missing=1
  fi
done

if (( missing != 0 )); then
  exit 3
fi

if [[ -n "$receipt_dir" ]]; then
  mkdir -p "$receipt_dir"
  umask 077
  receipt="$receipt_dir/prerequisites.json"
  os_id=$(source /etc/os-release && printf '%s' "$ID")
  os_version=$(source /etc/os-release && printf '%s' "$VERSION_ID")
  arch=$(uname -m)
  printf '{"schemaVersion":1,"sourceHead":"%s","sourceTree":"%s","hostClass":"linux-desktop-build","os":"%s","osVersion":"%s","arch":"%s","credentialsRead":false,"providerDispatch":false}\n' \
    "$actual_head" "$actual_tree" "$os_id" "$os_version" "$arch" >"$receipt"
fi

printf 'desktop-prerequisites=present\nsource-head=%s\nsource-tree=%s\n' "$actual_head" "$actual_tree"
