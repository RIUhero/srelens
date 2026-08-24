# MyDashboard Workstation Slice Acceptance

These states are independent and must not be collapsed into “done”:

| State | Current slice disposition | Required evidence |
|---|---|---|
| `sourceVerified` | **true** for the accepted runtime candidate | exact fork/upstream head, tree, and reviewed descendant lineage |
| `supplyChainVerified` | **true** for this candidate | vulnerability-free exact lockfile without advisory allowlisting |
| `workstationSeamVerified` | **true** for the accepted runtime candidate | default-off behavior, module lifecycle, projection redaction, accessibility, and physical interaction |
| `desktopCompileVerified` | **true** | locked `srelens-desktop` Rust compile on the accepted Ubuntu build environment |
| `desktopPackageVerified` | **true** | feature-OFF and feature-ON production Tauri packages plus digests bound to exact source HEAD/tree |
| `desktopRuntimeSmokeVerified` | **true** | clean start/interaction/shutdown on an `ai-worker`-owned physical Xorg display |
| `desktopBuildVerified` | **true** | compile, package, and actual graphical runtime-smoke gates all pass |
| `runtimeEmpiricalVerified` | **true for the Phase A desktop-runtime scope** | approved bounded execution of the production packages; the static projection remains non-production and proves no live Core/provider behavior |

Phase A remains accepted. Phase B is evaluated independently and does not
reinterpret the accepted Phase A physical-runtime receipt.

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

## Phase A physical runtime receipt

The accepted production artifacts and physical runtime campaign are bound to:

| Field | Accepted value |
|---|---|
| source HEAD | `0acfc7ee8ad596b93211c5501c824dc278ac09e4` |
| source tree | `d2d6ef05d6ebc219f4bd5d45ea69b6785f9afa6e` |
| host/display | `ai-worker`, Xorg `:77`, VT7, connected `DP-1` at 1920x1080 |
| feature-OFF package | `14dbcfc635ada6213a8c676456b85afeea931827885b2c7c42970741ce366830` |
| feature-ON package | `7a6ba5c7389839b31a096b9306cf10c7b3d798f087fa4ed55133a26446cba9cf` |
| feature-OFF binary | `bf214b363ac240ea0f02070a1d3a64dbeead0f89dca42df50844a75f89974a08` |
| feature-ON binary | `443d1e3a01cafc867985abdd5bae2a3e36c9baaf352ba486d6e34a118e6b0023` |

The authoritative final campaign is `campaign-v4`. Earlier campaigns are
retained only as failed harness diagnostics and do not contribute acceptance.
The final campaign proved:

- feature OFF rendered the upstream SRELens vault and did not render
  MyDashboard; the recovery-checkbox interaction changed the image and the app
  shut down cleanly;
- feature ON rendered the workstation navigation, Tasks, Workspaces,
  `PASS`/`BLOCKED`/`UNVERIFIED`, and the visible
  `Static fixture · not runtime evidence` disclosure;
- Tasks → Workspaces → Tasks was exercised through keyboard focus navigation;
- both executions used separate empty XDG state directories inside a
  no-home, `--unshare-net` bubblewrap boundary;
- the observed process family contained `srelens`, `WebKitNetworkProcess`, and
  `WebKitWebProcess` and left zero matching orphan processes;
- OCR-sensitive-field scans and an independent second scan passed before the
  transient OCR text was removed;
- all retained screenshots and receipts are owner-only regular files with one
  hard link, and their recomputed SHA-256 values match the redacted receipts;
- `providerDispatch=false`, `credentialsRead=false`, no canonical state was
  created, and the enabled fixture retains `productionUsable=false`;
- the STOP sentinel ended Xorg, the watchdog reported `orphan=false`, the X11
  socket disappeared, and the original `tty1` was restored.

Screenshot digests:

| Mode/view | SHA-256 |
|---|---|
| OFF initial | `100a0a5d6f22954e57b6238cf741afab0ff9f984f1198fc5cc23efb7a24c56ac` |
| OFF toggled | `bf0fdf80825db34b1639e329f63b9fe4095dc6a7f9afb8dbfa08bf4f5cd512e1` |
| OFF restored | `cb2f36b719db8a8ad1641f06f76b1488401b54acd64d59ef1ba8100373392c86` |
| ON initial | `332b8eafa75931cd59f3794b8473028a433379bb2a4a4d922b87ef28cb0f0561` |
| ON Tasks | `d6474b47319996e53e74a00950d9a3b62bc1e2e575ce868fc460ee88e3ebc447` |
| ON Workspaces | `bd9bd06950a0addf6c7d6b8492527c84da96752ef7ced9d6e146a21dbf6f1f85` |
| ON Tasks return | `14d87c6458f900fa6e189e5612c800ab93ed103e0070884df96dbc09c4095fad` |

The physical-Xorg supervisor used the already-present immutable Ubuntu image
`ubuntu@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517`
with Docker networking disabled and a read-only container root. The host user
home was hidden behind an empty tmpfs and only the owner-only campaign
directory was re-exposed. The supervisor exited zero after the redacted runner
receipt, Xorg shutdown, and VT restoration all completed.

## Phase B provider-free Core gate

The implementation at
`11976fea25a36e798efc3ddbd742d4852d9a657b` (tree
`d87e7a086c7f94a13ab2c640a9caac0eb3a6e610`) closes the local Phase B gates:

| Phase B state | Disposition | Evidence |
|---|---|---|
| `coreProcessVerified` | **true** | exact desktop executable served the versioned stdio protocol in an empty environment |
| `coreProjectionVerified` | **true** | live empty projection, exact allowlist, unknown/sensitive fail-closed tests |
| `workstationCoreTransportVerified` | **true** | existing Tauri command and Registry invoked the real child, acknowledged shutdown, and retained no manager state |
| `providerDispatch` | **false** | no provider dependency, operation, process, or network transport exists in the Core path |
| `credentialAccess` | **false** | Core dispatch precedes credential lookup and the child environment is cleared |
| `canonicalMutation` | **false** | Phase B returns an empty projection and exposes no mutation operation |
| `phaseCStarted` | **false** | no provider execution plane, orchestration, scheduler, or canonical state was added |

These dispositions preserve the implementation, protocol, registry, strict
projection, exact-binary manager smoke, and remote CI evidence. They do not by
themselves close strict Phase B acceptance. The current Phase B state is:

| Strict Phase B state | Disposition |
|---|---|
| `phaseBState` | **awaiting-physical-runtime-smoke** |
| `phaseBRuntimeEmpiricalVerified` | **false** |
| `phaseBVerified` | **false** |

Strict acceptance additionally requires an actual `ai-worker` physical-Xorg
campaign for the exact current candidate: feature-OFF absence, feature-ON live
Core rendering, fail-closed unavailable/malformed behavior, restart recovery,
and complete Workstation/Core/WebKit/Xorg/VT cleanup. Phase A physical evidence
cannot substitute for that Phase B candidate-bound campaign.

The Phase A static fixture remains available only in the feature-OFF module
construction path for its existing tests and is still non-production. The
feature-ON product path has no fixture fallback and uses the live read-only
Core capability.

## Unverified boundaries

Phase B is not yet strictly accepted and does not claim provider execution,
canonical Task/Workspace mutation,
account/session lifecycle, local-model execution, sandboxing, service
installation, release, deployment, restart, or rollback. Those remain outside
the accepted Phase A and current Phase B scope. Phase C has not started, and
`wholeProductComplete` remains false.
