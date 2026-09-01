#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
verifier="$script_dir/verify-phase-b-runtime-closure.sh"
builder="$script_dir/build-phase-b-runtime-closure.sh"
manifest_writer="$script_dir/write-phase-b-runtime-manifests.sh"
fixture=$(mktemp -d /tmp/mydashboard-runtime-contract.XXXXXX)
cleanup() { rm -rf -- "$fixture"; }
trap cleanup EXIT INT TERM

make_runtime() {
  local name=$1
  mkdir -p "$fixture/$name/runtime/root/usr/lib/x86_64-linux-gnu" "$fixture/$name/runtime/gst-min"
  printf 'plugin\n' >"$fixture/$name/runtime/gst-min/libgstapp.so"
}

expect_failure() {
  local code=$1; shift
  local output="$fixture/$code.output"
  if "$@" >"$output" 2>&1; then
    printf 'expected runtime closure failure was accepted: %s\n' "$code" >&2
    exit 1
  fi
  grep -q "safe-code=$code" "$output"
}

make_runtime relative
printf 'library\n' >"$fixture/relative/runtime/root/usr/lib/x86_64-linux-gnu/libvalid.so.1"
ln -s libvalid.so.1 "$fixture/relative/runtime/root/usr/lib/x86_64-linux-gnu/libvalid.so"
"$verifier" "$fixture/relative/runtime" >/dev/null

make_runtime absolute
ln -s /usr/lib/liboutside.so "$fixture/absolute/runtime/root/usr/lib/x86_64-linux-gnu/libabsolute.so"
expect_failure absolute-symlink "$verifier" "$fixture/absolute/runtime"

make_runtime dangling
ln -s missing.so "$fixture/dangling/runtime/root/usr/lib/x86_64-linux-gnu/libdangling.so"
expect_failure dangling-or-cyclic-symlink "$verifier" "$fixture/dangling/runtime"

make_runtime escape
printf 'outside\n' >"$fixture/outside.so"
ln -s "$fixture/outside.so" "$fixture/escape/runtime/root/usr/lib/x86_64-linux-gnu/libescape.so"
expect_failure absolute-symlink "$verifier" "$fixture/escape/runtime"
rm "$fixture/escape/runtime/root/usr/lib/x86_64-linux-gnu/libescape.so"
ln -s ../../../../../../outside.so "$fixture/escape/runtime/root/usr/lib/x86_64-linux-gnu/libescape.so"
expect_failure escaping-symlink "$verifier" "$fixture/escape/runtime"

make_runtime chain
printf 'chain\n' >"$fixture/chain/runtime/root/usr/lib/x86_64-linux-gnu/libchain.so.2"
ln -s libchain.so.2 "$fixture/chain/runtime/root/usr/lib/x86_64-linux-gnu/libchain.so.1"
ln -s libchain.so.1 "$fixture/chain/runtime/root/usr/lib/x86_64-linux-gnu/libchain.so"
"$verifier" "$fixture/chain/runtime" >/dev/null

make_runtime broken-chain
ln -s missing.so.2 "$fixture/broken-chain/runtime/root/usr/lib/x86_64-linux-gnu/libbroken.so.1"
ln -s libbroken.so.1 "$fixture/broken-chain/runtime/root/usr/lib/x86_64-linux-gnu/libbroken.so"
expect_failure dangling-or-cyclic-symlink "$verifier" "$fixture/broken-chain/runtime"

make_runtime cycle
ln -s libcycle.so.2 "$fixture/cycle/runtime/root/usr/lib/x86_64-linux-gnu/libcycle.so.1"
ln -s libcycle.so.1 "$fixture/cycle/runtime/root/usr/lib/x86_64-linux-gnu/libcycle.so.2"
expect_failure dangling-or-cyclic-symlink "$verifier" "$fixture/cycle/runtime"

make_runtime documentation
mkdir -p "$fixture/documentation/runtime/root/usr/share/doc/package-a"
ln -s ../package-b/changelog.gz "$fixture/documentation/runtime/root/usr/share/doc/package-a/changelog.gz"
expect_failure documentation-tree-present "$verifier" "$fixture/documentation/runtime"

make_runtime manifest
printf 'library\n' >"$fixture/manifest/runtime/root/usr/lib/x86_64-linux-gnu/libmanifest.so"
"$manifest_writer" "$fixture/manifest" >/dev/null
"$verifier" "$fixture/manifest/runtime" "$fixture/manifest/runtime-files.sha256" "$fixture/manifest/runtime-symlinks.tsv" >/dev/null
printf 'mutation\n' >"$fixture/manifest/runtime/root/usr/lib/x86_64-linux-gnu/extra.so"
expect_failure runtime-file-set "$verifier" "$fixture/manifest/runtime" "$fixture/manifest/runtime-files.sha256" "$fixture/manifest/runtime-symlinks.tsv"

make_runtime symlink-manifest
printf 'one\n' >"$fixture/symlink-manifest/runtime/root/usr/lib/x86_64-linux-gnu/libone.so"
printf 'two\n' >"$fixture/symlink-manifest/runtime/root/usr/lib/x86_64-linux-gnu/libtwo.so"
ln -s libone.so "$fixture/symlink-manifest/runtime/root/usr/lib/x86_64-linux-gnu/libcurrent.so"
"$manifest_writer" "$fixture/symlink-manifest" >/dev/null
rm "$fixture/symlink-manifest/runtime/root/usr/lib/x86_64-linux-gnu/libcurrent.so"
ln -s libtwo.so "$fixture/symlink-manifest/runtime/root/usr/lib/x86_64-linux-gnu/libcurrent.so"
expect_failure runtime-symlink-set "$verifier" "$fixture/symlink-manifest/runtime" "$fixture/symlink-manifest/runtime-files.sha256" "$fixture/symlink-manifest/runtime-symlinks.tsv"

actual=false
if [[ -n ${MYDASHBOARD_RUNTIME_PACKAGE_DIR:-} && -n ${MYDASHBOARD_WEBKIT_DRIVER:-} ]]; then
  actual=true
  "$builder" "$MYDASHBOARD_RUNTIME_PACKAGE_DIR" "$fixture/actual/runtime" >/dev/null
  "$manifest_writer" "$fixture/actual" >/dev/null
  "$verifier" "$fixture/actual/runtime" "$fixture/actual/runtime-files.sha256" "$fixture/actual/runtime-symlinks.tsv" >/dev/null
  runtime_lib="$fixture/actual/runtime/root/usr/lib/x86_64-linux-gnu"
  linkage=$(LD_LIBRARY_PATH="$runtime_lib" ldd "$MYDASHBOARD_WEBKIT_DRIVER")
  ! grep -q 'not found' <<<"$linkage"
  env -i HOME="$fixture/actual" PATH=/usr/bin:/bin LD_LIBRARY_PATH="$runtime_lib" \
    GST_PLUGIN_PATH="$fixture/actual/runtime/gst-min" \
    GST_PLUGIN_SYSTEM_PATH="$fixture/actual/runtime/gst-min" \
    GST_REGISTRY="$fixture/actual/gstreamer-registry.bin" \
    "$MYDASHBOARD_WEBKIT_DRIVER" --help >/dev/null
  if [[ -n ${MYDASHBOARD_TAURI_DRIVER:-} ]]; then
    LD_LIBRARY_PATH="$runtime_lib" \
      GST_PLUGIN_PATH="$fixture/actual/runtime/gst-min" \
      GST_PLUGIN_SYSTEM_PATH="$fixture/actual/runtime/gst-min" \
      GST_REGISTRY="$fixture/actual/gstreamer-registry.bin" \
      "$script_dir/test-phase-b-webdriver-integration.sh" \
        "$MYDASHBOARD_TAURI_DRIVER" "$MYDASHBOARD_WEBKIT_DRIVER" >/dev/null
  fi
fi

printf 'phase-b-runtime-closure-contract=passed tests=11 actual-webkit=%s dangling=0 escaping=0 mutation-detected=true\n' "$actual"
