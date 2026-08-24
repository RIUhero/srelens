# Phase B Provider-Free Core Seam

Phase B adds one live, read-only path without introducing product state or a
provider execution plane:

```text
MyDashboard Workstation
  -> existing Tauri invoke_capability command
  -> srelens-capability::Registry
  -> mydashboard.readProjection (read-only, non-sensitive)
  -> exact current srelens executable --mydashboard-core-stdio
  -> strict redacted CoreProjection
```

The Core is `crates/mydashboard-core`, a repository-owned Rust crate whose only
dependencies are `serde` and `serde_json`. It opens no network listener, reads
no environment credential, resolves no home/config path, imports no provider,
and writes no file. The Phase B projection is intentionally `{ "tasks": [] }`:
it proves the real process and transport without inventing canonical Tasks or
Workspaces.

## Transport contract

- newline-delimited JSON over inherited stdin/stdout only;
- protocol version `1` and exact operations `read_projection` and `shutdown`;
- every request and projection struct uses `deny_unknown_fields`;
- malformed, unknown, or version-mismatched requests return fixed safe codes;
- raw request, process error, stderr, PID, executable path, and provider error
  never cross the capability boundary;
- the child receives `env_clear`, null stderr, piped stdin/stdout, a five-second
  operation timeout, and `kill_on_drop` fail-closed cleanup;
- graceful shutdown requires a typed acknowledgement and child exit; timeout
  or protocol failure falls back to kill-and-wait.

The Core command-line mode is selected before master-password lookup, PATH
repair, Kubernetes initialization, AppImage/GTK setup, config resolution,
keychain access, or any provider-capable surface.

## Workstation contract

The existing feature flag remains default OFF. OFF registers no MyDashboard
capability and spawns no Core process. Exact value `1` registers only
`mydashboard.readProjection` in the existing Rust registry. The browser thin
adapter invokes it with `null`, then re-applies the Phase A strict projection
parser. It has no static-fixture fallback and replaces every raw error with the
fixed message `Core projection unavailable`.

No Phase B path creates canonical state, dispatches a provider, reads a
credential, starts an HTTP/MCP server, or enables Phase C behavior.

## Implementation authority and verification

The Phase B implementation is commit
`11976fea25a36e798efc3ddbd742d4852d9a657b`, tree
`d87e7a086c7f94a13ab2c640a9caac0eb3a6e610`. Its pre-change return point is
`refs/return/mydashboard-workstation-pre-phase-b-v1-20260825`, resolving to
commit `d89b9d8d40b38ea4e441858130f5f9299fe02965`, tree
`ab9a4c7d42e9b80c199af493f994c93d9e691e22`.

Local and `ai-worker` verification for that exact implementation tree:

- 1,491 frontend tests and all four TypeScript package checks passed;
- feature-OFF and feature-ON Vite production builds passed at 2,410 modules,
  with the largest chunk below 500 kB;
- Core protocol tests passed 5/5 and desktop bridge tests passed 3/3;
- the exact built desktop executable returned only the empty projection and
  shutdown acknowledgement through the real manager, then left manager state
  empty and zero matching orphan Core processes;
- desktop Rust tests passed 185/185 when run as the non-root acceptance user;
- the non-desktop locked workspace suite passed with its required shell path;
- locked server build and metadata passed;
- cargo-audit 0.22.2 scanned 745 dependencies with zero vulnerabilities and
  retained the 18 previously documented non-vulnerability warnings;
- no `rsa` package or new external dependency entered the lock closure.

The first root-container regression attempt is diagnostic only: three
permission-denial tests correctly required a non-root user, and two terminal
tests required an explicit shell. The authoritative non-root reruns passed.

## Strict runtime acceptance status

The implementation and verification above establish the Core process,
protocol, registry, strict projection, manager lifecycle, and headless package
behavior. They do not substitute for an actual physical Workstation campaign.

Until the exact current candidate passes feature-OFF and feature-ON execution,
live empty-state interaction, bounded fail-closed fault injection, Core restart
recovery, and complete physical Xorg/VT cleanup on `ai-worker`:

- `phaseBState=awaiting-physical-runtime-smoke`;
- `phaseBRuntimeEmpiricalVerified=false`;
- `phaseBVerified=false`.

Phase A remains accepted, Phase C has not started, and
`wholeProductComplete=false`.
