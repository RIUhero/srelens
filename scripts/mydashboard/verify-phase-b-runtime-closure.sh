#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'phase-b-runtime-closure=failed safe-code=%s%s\n' "$1" "${2:+ path=$2}" >&2
  exit 2
}

[[ $# -eq 1 || $# -eq 3 ]] || fail invalid-arguments
runtime=$(realpath -e -- "$1") || fail invalid-runtime
[[ -d "$runtime" && ! -L "$runtime" ]] || fail invalid-runtime
runtime_parent=$(dirname "$runtime")

for excluded in root/usr/share/doc root/usr/share/bug root/usr/share/lintian; do
  [[ ! -e "$runtime/$excluded" && ! -L "$runtime/$excluded" ]] \
    || fail documentation-tree-present "$excluded"
done

plugin="$runtime/gst-min/libgstapp.so"
[[ -f "$plugin" && ! -L "$plugin" ]] || fail non-regular-gstreamer-plugin gst-min/libgstapp.so

symlink_count=0
while IFS= read -r -d '' link; do
  symlink_count=$((symlink_count + 1))
  relative=${link#"$runtime"/}
  literal=$(readlink -- "$link") || fail unreadable-symlink "$relative"
  [[ "$literal" != /* ]] || fail absolute-symlink "$relative"
  resolved=$(realpath -e -- "$link" 2>/dev/null) \
    || fail dangling-or-cyclic-symlink "$relative"
  case "$resolved" in
    "$runtime"/*) ;;
    *) fail escaping-symlink "$relative" ;;
  esac
done < <(find "$runtime" -type l -print0)

file_count=$(find "$runtime" -type f | wc -l)

if [[ $# -eq 3 ]]; then
  file_manifest=$(realpath -e -- "$2") || fail invalid-file-manifest
  symlink_manifest=$(realpath -e -- "$3") || fail invalid-symlink-manifest
  [[ -f "$file_manifest" && ! -L "$file_manifest" ]] || fail invalid-file-manifest
  [[ -f "$symlink_manifest" && ! -L "$symlink_manifest" ]] || fail invalid-symlink-manifest

  fixture=$(mktemp -d /tmp/mydashboard-runtime-verify.XXXXXX)
  cleanup() { rm -rf -- "$fixture"; }
  trap cleanup EXIT INT TERM

  (cd "$runtime_parent" && sha256sum --check "$file_manifest" >/dev/null) \
    || fail runtime-file-digest
  (cd "$runtime_parent" && find "$(basename "$runtime")" -type f -printf '%p\n' | LC_ALL=C sort) \
    >"$fixture/actual-files"
  sed -n 's/^[0-9a-f]\{64\}  //p' "$file_manifest" | LC_ALL=C sort \
    >"$fixture/manifest-files"
  cmp -s "$fixture/actual-files" "$fixture/manifest-files" \
    || fail runtime-file-set

  (cd "$runtime" && find . -type l -printf '%P\t%l\n' | LC_ALL=C sort) \
    >"$fixture/actual-symlinks"
  cmp -s "$fixture/actual-symlinks" "$symlink_manifest" \
    || fail runtime-symlink-set
fi

printf 'phase-b-runtime-closure=passed files=%s symlinks=%s dangling=0 escaping=0 absolute=0 documentation=0\n' \
  "$file_count" "$symlink_count"
