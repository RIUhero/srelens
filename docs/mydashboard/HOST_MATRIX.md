# MyDashboard Desktop Host Matrix

| Host/environment | OS and architecture | Role | Native metadata | Graphical session | Accepted evidence |
|---|---|---|---|---|---|
| `ai-worker` | Ubuntu 24.04.4 LTS, x86_64 | initial desktop acceptance host | absent at initial inventory; isolated build closure used | dedicated host Xorg `:77`, VT7, connected DP-1 at 1920x1080; restored to tty1 | feature-OFF/ON production-package compile, package, and physical runtime smoke |
| pinned `ubuntu@sha256:33ceb7…7517` container on `ai-worker` | Ubuntu 24.04, x86_64 | reproducible native dependency isolation | installed inside disposable container | none | compile and package only |
| GitHub `ubuntu-24.04` runner | Ubuntu 24.04, x86_64 | secret-free PR regression | installed per workflow | virtual/headless | CI compile/package only |
| Linux Mint client | Linux Mint 21.3, x86_64 | Codex development and SSH access | not acceptance authority | X11 | no `ai-worker` desktop acceptance |

Only the actual `ai-worker` physical-display row sets
`desktopRuntimeSmokeVerified=true`. The accepted session used a bounded
600-second watchdog, no-network/no-home application isolation, redacted
receipts, clean shutdown, zero runtime orphans, and tty1 restoration. Provider
login/dispatch, live Core state, canonical mutation, and production
installation remain outside every row in this slice.
