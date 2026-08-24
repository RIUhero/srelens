#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

expected_head=${MYDASHBOARD_EXPECTED_HEAD:?set MYDASHBOARD_EXPECTED_HEAD to the exact candidate SHA}
receipt_dir=${MYDASHBOARD_RECEIPT_DIR:?set MYDASHBOARD_RECEIPT_DIR to a bounded output directory}
mkdir -p "$receipt_dir"
receipt_dir=$(cd "$receipt_dir" && pwd)

unset OPENAI_API_KEY ANTHROPIC_API_KEY CODEX_API_KEY CLAUDE_API_KEY
unset TAURI_SIGNING_PRIVATE_KEY TAURI_SIGNING_PRIVATE_KEY_PASSWORD

MYDASHBOARD_RECEIPT_DIR="$receipt_dir" \
  scripts/mydashboard/check-linux-desktop-prerequisites.sh

pnpm install --frozen-lockfile --ignore-scripts
# pnpm-workspace.yaml declares esbuild as the only allowed native lifecycle.
pnpm rebuild esbuild
pnpm typecheck
pnpm build
cargo build --locked -p srelens-desktop --features custom-protocol --release
pnpm --filter @srelens/desktop tauri build -- --bundles deb

actual_head=$(git rev-parse HEAD)
actual_tree=$(git rev-parse 'HEAD^{tree}')
cargo_lock_sha=$(sha256sum Cargo.lock | cut -d' ' -f1)
pnpm_lock_sha=$(sha256sum pnpm-lock.yaml | cut -d' ' -f1)

shopt -s nullglob
artifacts=(target/release/bundle/deb/*.deb)
if (( ${#artifacts[@]} != 1 )); then
  printf 'expected exactly one deb artifact, found %d\n' "${#artifacts[@]}" >&2
  exit 4
fi

artifact=${artifacts[0]}
artifact_name=$(basename "$artifact")
artifact_sha=$(sha256sum "$artifact" | cut -d' ' -f1)
artifact_size=$(stat -c '%s' "$artifact")
cp "$artifact" "$receipt_dir/$artifact_name"

umask 077
printf '{"schemaVersion":1,"sourceHead":"%s","sourceTree":"%s","cargoLockSha256":"%s","pnpmLockSha256":"%s","artifact":"%s","artifactBytes":%s,"artifactSha256":"%s","credentialsRead":false,"providerDispatch":false,"runtimeSmoke":false}\n' \
  "$actual_head" "$actual_tree" "$cargo_lock_sha" "$pnpm_lock_sha" \
  "$artifact_name" "$artifact_size" "$artifact_sha" >"$receipt_dir/desktop-build.json"

printf 'desktop-compile=passed\ndesktop-package=passed\nartifact=%s\nartifact-sha256=%s\nsource-head=%s\nsource-tree=%s\n' \
  "$artifact_name" "$artifact_sha" "$actual_head" "$actual_tree"
