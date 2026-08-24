# MyDashboard Workstation Slice Acceptance

These states are independent and must not be collapsed into “done”:

| State | Current slice disposition | Required evidence |
|---|---|---|
| `sourceVerified` | verified at the starting baseline | exact fork/upstream head, tree, and 0/0 divergence |
| `supplyChainVerified` | **false** | vulnerability-free exact lockfile without advisory allowlisting |
| `workstationSeamVerified` | locally testable | default-off behavior, module lifecycle, projection redaction, accessibility |
| `desktopBuildVerified` | **unverified** | successful Tauri GTK/WebKit desktop build on a provisioned host |
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
- `cargo metadata --locked` succeeds;
- Rust workspace build/test and `cargo audit` are recorded independently;
- RUSTSEC-2023-0071 remains a blocker until the active `openidconnect → rsa`
  path is safely removed, replaced, or fixed upstream.

## Unverified boundaries

Frontend build success is not a Tauri desktop build. This host previously
lacked GTK/WebKit/GLib development packages, so no desktop PASS may be claimed
without a new successful native build. No live provider, local model, sandbox,
service installation, release, deployment, restart, or rollback is authorized
or implied by this slice.
