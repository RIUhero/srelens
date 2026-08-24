# MyDashboard Desktop Host Matrix

| Host/environment | OS and architecture | Role | Native metadata | Graphical session | Accepted evidence |
|---|---|---|---|---|---|
| `ai-worker` | Ubuntu 24.04.4 LTS, x86_64 | initial desktop acceptance host | absent at initial inventory | TTY only; no X11/Wayland display | isolated compile/package may count separately; runtime smoke does not |
| pinned `ubuntu@sha256:33ceb7…7517` container on `ai-worker` | Ubuntu 24.04, x86_64 | reproducible native dependency isolation | installed inside disposable container | none | compile and package only |
| GitHub `ubuntu-24.04` runner | Ubuntu 24.04, x86_64 | secret-free PR regression | installed per workflow | virtual/headless | CI compile/package only |
| Linux Mint client | Linux Mint 21.3, x86_64 | Codex development and SSH access | not acceptance authority | X11 | no `ai-worker` desktop acceptance |

No row other than the actual `ai-worker` graphical session may set
`desktopRuntimeSmokeVerified=true`. Provider login/dispatch, canonical state,
and production installation remain outside every row in this slice.
