# MyDashboard Workstation Slice Acceptance

These states are independent and must not be collapsed into “done”:

| State | Current slice disposition | Required evidence |
|---|---|---|
| `sourceVerified` | verified at the starting baseline | exact fork/upstream head, tree, and 0/0 divergence |
| `supplyChainVerified` | **true** for this candidate | vulnerability-free exact lockfile without advisory allowlisting |
| `workstationSeamVerified` | locally testable | default-off behavior, module lifecycle, projection redaction, accessibility |
| `desktopCompileVerified` | **unverified** | locked `srelens-desktop` Rust compile on the accepted host or an explicitly isolated build environment |
| `desktopPackageVerified` | **unverified** | production Tauri package plus digest bound to exact source HEAD/tree |
| `desktopRuntimeSmokeVerified` | **false** | clean start/interaction/shutdown in an actual `ai-worker` graphical session |
| `desktopBuildVerified` | **false** | compile, package, and actual graphical runtime-smoke gates all pass |
| `runtimeEmpiricalVerified` | **false** | separately approved bounded runtime campaign; fixtures never qualify |

## Provider-free seam gate

- feature flag absent or any value other than exact `1`: no module navigation,
  module lifecycle, network call, process, or persistence;
- feature flag enabled: SRELens remains selectable and Tasks/Workspaces are
  read-only;
- module deactivation balances activation and retains no canonical state;
- projection envelope and task fields use exact allowlists;
- every prohibited field and every unknown field is rejected;
- raw reader errors and private values are not rendered;
- static fixture and UI are visibly marked non-production/non-empirical;
- CSP is non-null and production policy contains no wildcard or unsafe eval;
- Vite production output has no chunk above the configured 500 kB warning;
- existing frontend typecheck, tests, and build pass.

## Supply-chain gate

- `rkyv 0.7.46` and its unused transitive chain are absent;
- `fix-path-env` has an exact manifest revision and matching lock revision;
- no `rkyv` or `rsa` vulnerability suppression remains;
- the exact lockfile contains no `rsa`, `sqlx-mysql`, or `sqlx-postgres` package;
- the source-vendored `openidconnect` 4.0.1 compatibility fork uses exact
  `ring 0.17.14` for its RSA algorithms and retains its upstream test suite;
- the source-vendored SQLx facade/macro-core packages differ from their exact
  crates.io archives only in the SQLite-scoped normalized manifests;
- `cargo metadata --locked` succeeds;
- Rust workspace build/test and `cargo audit` are recorded independently;
- RUSTSEC-2023-0071 is closed only when the empirical audit confirms both
  former lock paths are absent and `cargo audit --file Cargo.lock` passes.

The 2026-08-24 candidate audit met that condition: locked metadata passed,
`cargo tree --locked -i rsa` found no package, the active SQLx feature tree was
SQLite-only, and `cargo audit 0.22.2` scanned 744 lock dependencies with zero
vulnerabilities. Its 18 non-vulnerability warnings remain reported separately
and are not treated as advisory suppressions.

## Unverified boundaries

Frontend build success and `cargo check` are not a Tauri desktop build.
Container or CI compilation may close compile/package evidence, but cannot
replace an actual graphical-session smoke on `ai-worker`. No live provider,
local model, sandbox, service installation, release, deployment, restart, or
rollback is authorized or implied by this slice.
