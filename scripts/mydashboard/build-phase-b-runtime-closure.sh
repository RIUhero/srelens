#!/usr/bin/env bash
set -euo pipefail
umask 077

fail() {
  printf 'phase-b-runtime-build=failed safe-code=%s\n' "$1" >&2
  exit 2
}

[[ $# -eq 2 ]] || fail invalid-arguments
package_dir=$(realpath -e -- "$1") || fail invalid-package-directory
[[ -d "$package_dir" && ! -L "$package_dir" ]] || fail invalid-package-directory
output=$2
[[ "$output" == /* && ! -e "$output" && ! -L "$output" ]] || fail unsafe-output
mkdir -p "$output/root" "$output/gst-min"

shopt -s nullglob
packages=("$package_dir"/*.deb)
(( ${#packages[@]} > 0 )) || fail packages-absent
: >"$output/package-provenance.tsv"
for package in "${packages[@]}"; do
  [[ -f "$package" && ! -L "$package" ]] || fail invalid-package
  architecture=$(dpkg-deb -f "$package" Architecture)
  [[ "$architecture" == amd64 || "$architecture" == all ]] || fail invalid-package-architecture
  name=$(dpkg-deb -f "$package" Package)
  version=$(dpkg-deb -f "$package" Version)
  digest=$(sha256sum "$package" | cut -d' ' -f1)
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$version" "$architecture" "$digest" "$(basename "$package")" \
    >>"$output/package-provenance.tsv"
  dpkg-deb --extract "$package" "$output/root"
done
LC_ALL=C sort -o "$output/package-provenance.tsv" "$output/package-provenance.tsv"

# Debian documentation and packaging metadata are not executable WebKit inputs.
# Excluding the complete trees avoids cross-package documentation symlinks.
rm -rf -- \
  "$output/root/usr/share/doc" \
  "$output/root/usr/share/bug" \
  "$output/root/usr/share/lintian"

plugin_source="$output/root/usr/lib/x86_64-linux-gnu/gstreamer-1.0/libgstapp.so"
[[ -f "$plugin_source" && ! -L "$plugin_source" ]] || fail gstreamer-plugin-absent
install -m 0700 "$plugin_source" "$output/gst-min/libgstapp.so"

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
"$script_dir/verify-phase-b-runtime-closure.sh" "$output" >/dev/null
printf 'phase-b-runtime-build=passed packages=%s documentation=excluded gst-plugin=regular\n' "${#packages[@]}"
