# Reproducible Linux Desktop Build

## Acceptance host

The initial desktop acceptance host is `ai-worker`, user `karasani`, running
Ubuntu 24.04 LTS on x86_64. Linux Mint is a Codex development/access client and
is not an additional canonical execution host.

Build, package, and runtime smoke are independent:

- `desktopCompileVerified`: locked `srelens-desktop` Rust compile succeeds;
- `desktopPackageVerified`: a production Tauri package is created and its
  SHA-256 is bound to the exact source HEAD and tree;
- `desktopRuntimeSmokeVerified`: the actual app is exercised on an
  `ai-worker`-owned physical graphical display with the feature flag both off
  and on;
- `desktopBuildVerified`: all three states above are true.

A pinned container on `ai-worker` may provide compile/package evidence. It
does not create a graphical session and cannot close runtime smoke or the
aggregate desktop-build gate.

## Official Ubuntu prerequisites

Tauri v2 documents these Debian/Ubuntu packages:

```text
build-essential
curl
wget
file
libxdo-dev
libssl-dev
libwebkit2gtk-4.1-dev
libayatana-appindicator3-dev
librsvg2-dev
```

`libwebkit2gtk-4.1-dev` brings the required GTK 3, GLib,
JavaScriptCoreGTK 4.1, and libsoup development closure. The accepted host's
Ubuntu archive additionally supplies `pkg-config` through `pkgconf`.

The 2026-08-24 `ai-worker` inventory found Ubuntu 24.04.4 LTS (`noble`), GCC
13.3, GNU ld 2.42, pkg-config 1.8.1, and 63 GiB available. The native
development metadata was absent. The candidate package versions included:

| Package | Ubuntu candidate |
|---|---|
| `libwebkit2gtk-4.1-dev` | `2.52.3-0ubuntu0.24.04.1` |
| `libssl-dev` | `3.0.13-0ubuntu3.12` |
| `libayatana-appindicator3-dev` | `0.5.93-1build3` |
| `librsvg2-dev` | `2.58.0+dfsg-1build1` |
| `libxdo-dev` | `1:3.20160805.1-5build1` |

The simulated `--no-install-recommends` host transaction would add 188
packages. Because non-interactive sudo is unavailable, this slice does not
mutate the host package database. Compile/package validation instead uses the
official Ubuntu image pinned to
`ubuntu@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517`.
Package maintainer scripts execute only inside that disposable container. The
container is removed after the build; host rollback consists of deleting the
bounded source/output directories and image when no longer required.

## Contract

From a clean exact candidate:

```bash
MYDASHBOARD_EXPECTED_HEAD=<exact-sha> \
  scripts/mydashboard/check-linux-desktop-prerequisites.sh

MYDASHBOARD_EXPECTED_HEAD=<exact-sha> \
MYDASHBOARD_RECEIPT_DIR=<bounded-output-directory> \
  scripts/mydashboard/build-linux-desktop.sh

# sudo-free isolated build on ai-worker
MYDASHBOARD_EXPECTED_HEAD=<exact-sha> \
MYDASHBOARD_RECEIPT_DIR=<bounded-output-directory> \
  scripts/mydashboard/build-linux-desktop-container.sh
```

All scripts reject a mismatched HEAD, unlocked inputs, missing packages, and
tracked worktree changes. They do not start the application, read credentials,
dispatch a provider, or write canonical state. The build script unsets common
provider/signing credential variables before spawning dependency/build tools.
It uses frozen JavaScript and Rust lockfiles, explicitly allows only the
repository-declared `esbuild` lifecycle, and emits a redacted receipt with
source HEAD/tree, lockfile digests, artifact basename, size, and SHA-256.
The container wrapper additionally verifies the official Node 24.19.0 and
rustup-init downloads against their published SHA-256 manifests, installs
Rust 1.98.0, records the complete Ubuntu package set, and removes the
container after the bounded build.

## Accepted physical runtime smoke

The exact candidate at HEAD
`0acfc7ee8ad596b93211c5501c824dc278ac09e4` and tree
`d2d6ef05d6ebc219f4bd5d45ea69b6785f9afa6e` was exercised on the real
`ai-worker` display path, not Xvfb:

- dedicated host Xorg `:77`, physical VT7, connected DP-1 at 1920x1080;
- 600-second fail-closed watchdog and STOP sentinel;
- separate isolated XDG state for feature-OFF and feature-ON production
  packages;
- no-home and no-network application sandbox;
- OFF vault interaction and clean shutdown;
- ON MyDashboard navigation and keyboard-driven Tasks/Workspaces/Tasks
  interaction;
- process-family, sensitive rendering, screenshot digest, receipt, orphan, and
  shutdown checks;
- Xorg socket removal and original `tty1` restoration.

The authoritative `campaign-v4` runner and its independent post-run audit both
passed with `providerDispatch=false`, `credentialsRead=false`, and zero runtime
orphans. The supervisor used the pinned Ubuntu image with Docker networking
disabled, a read-only container filesystem, and the host user home hidden; it
only invoked the audited physical-Xorg harness and waited for shutdown. Xvfb
diagnostics and the failed pre-v4 harness attempts remain non-acceptance
evidence.

Therefore `desktopCompileVerified=true`, `desktopPackageVerified=true`,
`desktopRuntimeSmokeVerified=true`, and `desktopBuildVerified=true` for this
Phase A candidate. The static Core projection remains visibly non-production;
no live provider or Core behavior is inferred from it.
