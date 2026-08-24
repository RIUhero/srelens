#!/usr/bin/env bash
set -euo pipefail

expected_head=${MYDASHBOARD_EXPECTED_HEAD:?set MYDASHBOARD_EXPECTED_HEAD to the exact candidate SHA}
receipt_dir=${MYDASHBOARD_RECEIPT_DIR:?set MYDASHBOARD_RECEIPT_DIR to a bounded output directory}
repo_root=$(git rev-parse --show-toplevel)
image=ubuntu@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517

actual_head=$(git -C "$repo_root" rev-parse HEAD)
if [[ "$actual_head" != "$expected_head" ]]; then
  printf 'candidate mismatch: expected=%s actual=%s\n' "$expected_head" "$actual_head" >&2
  exit 2
fi
git -C "$repo_root" diff --quiet
git -C "$repo_root" diff --cached --quiet

mkdir -p "$receipt_dir"
receipt_dir=$(cd "$receipt_dir" && pwd)

docker run --rm \
  --env DEBIAN_FRONTEND=noninteractive \
  --env HOST_UID="$(id -u)" \
  --env HOST_GID="$(id -g)" \
  --env MYDASHBOARD_EXPECTED_HEAD="$expected_head" \
  --env MYDASHBOARD_RECEIPT_DIR=/receipt \
  --volume "$repo_root:/source:ro" \
  --volume "$receipt_dir:/receipt" \
  --workdir /work \
  "$image" \
  bash -ceu '
    apt-get update
    apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl file git libayatana-appindicator3-dev \
      librsvg2-dev libssl-dev libwebkit2gtk-4.1-dev libxdo-dev pkg-config wget xz-utils

    node_archive=node-v24.19.0-linux-x64.tar.xz
    curl --fail --silent --show-error --location --remote-name \
      "https://nodejs.org/dist/v24.19.0/${node_archive}"
    curl --fail --silent --show-error --location --remote-name \
      https://nodejs.org/dist/v24.19.0/SHASUMS256.txt
    grep " ${node_archive}$" SHASUMS256.txt | sha256sum --check --strict
    mkdir -p /opt/node
    tar -xJf "$node_archive" -C /opt/node --strip-components=1

    curl --fail --silent --show-error --location --remote-name \
      https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
    curl --fail --silent --show-error --location --remote-name \
      https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init.sha256
    printf "%s  rustup-init\n" "$(cat rustup-init.sha256)" | sha256sum --check --strict
    chmod +x rustup-init
    export CARGO_HOME=/opt/cargo RUSTUP_HOME=/opt/rustup
    export PATH=/opt/node/bin:/opt/cargo/bin:$PATH
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain 1.98.0
    npm install --global --ignore-scripts pnpm@9.15.9

    cp -a /source/. /work/
    git config --global --add safe.directory /work
    scripts/mydashboard/build-linux-desktop.sh
    dpkg-query --show > /receipt/ubuntu-packages.tsv
    sha256sum /receipt/ubuntu-packages.tsv > /receipt/ubuntu-packages.tsv.sha256
    chown -R "$HOST_UID:$HOST_GID" /receipt
  '
