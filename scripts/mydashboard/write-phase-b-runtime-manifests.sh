#!/usr/bin/env bash
set -euo pipefail
umask 077

fail() {
  printf 'phase-b-runtime-manifest=failed safe-code=%s\n' "$1" >&2
  exit 2
}

[[ $# -eq 1 ]] || fail invalid-arguments
campaign=$(realpath -e -- "$1") || fail invalid-campaign
runtime="$campaign/runtime"
[[ -d "$runtime" && ! -L "$runtime" ]] || fail invalid-runtime
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"$script_dir/verify-phase-b-runtime-closure.sh" "$runtime" >/dev/null

file_tmp=$(mktemp "$campaign/.runtime-files.XXXXXX")
symlink_tmp=$(mktemp "$campaign/.runtime-symlinks.XXXXXX")
cleanup() { rm -f -- "$file_tmp" "$symlink_tmp"; }
trap cleanup EXIT INT TERM
(cd "$campaign" && find runtime -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) >"$file_tmp"
(cd "$runtime" && find . -type l -printf '%P\t%l\n' | LC_ALL=C sort) >"$symlink_tmp"
chmod 0600 "$file_tmp" "$symlink_tmp"
mv -f -- "$file_tmp" "$campaign/runtime-files.sha256"
mv -f -- "$symlink_tmp" "$campaign/runtime-symlinks.tsv"
trap - EXIT INT TERM

"$script_dir/verify-phase-b-runtime-closure.sh" \
  "$runtime" "$campaign/runtime-files.sha256" "$campaign/runtime-symlinks.tsv" >/dev/null
printf 'phase-b-runtime-manifest=passed mutation-detection=exact-files-and-symlinks\n'
