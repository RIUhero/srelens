# MyDashboard Workstation Slice Architecture

## Composition boundary

`AppGate` continues to render the existing SRELens `App` directly when the
feature flag is off. With the exact build-time value
`VITE_SRELENS_MYDASHBOARD=1`, `WorkstationShell` adds a small module navigation
surface. SRELens remains the default selected contribution; MyDashboard can be
opened and closed without replacing the Kubernetes application.

`WorkstationModule` contains composition metadata only:

- `id` and `label`;
- a fail-closed feature flag;
- a navigation contribution;
- capability registration ownership and capability IDs;
- a projection source classification;
- activation/deactivation lifecycle hooks;
- a render contribution.

It has no mutable product state. Module-local React state is limited to view
selection and already-redacted display data.

## Capability authority

`srelens-capability::Registry` remains the single operation registry. The
prototype declares that owner and registers no capability ID because it has no
real Core transport yet. A future Core reader must add one explicitly read-only
capability to the existing Rust registry and list that exact ID in the module.
It must not add a TypeScript registry, a second Rust registry, or treat the
Kubernetes capability catalog as MyDashboard canonical state.

## Projection boundary

`CoreProjectionReader` is deliberately skeletal. This slice uses a static,
provider-free redacted fixture marked `productionUsable=false`. Its parser
accepts only this exact task projection:

- `taskPublicId`;
- `state` (`UNVERIFIED`, `BLOCKED`, or `PASS`);
- `providerFamily` (`native-cli` or `local-openai-compatible`);
- `workspacePublicRef`;
- `parentPublicRef`;
- canonical UTC `updatedAt`;
- allowlisted `safeEvent`.

Unknown envelope or task keys fail closed. Public references reject slashes,
email-like values, and private paths. Raw reader errors are replaced with a
generic unavailable state before rendering.

The later production adapter must read only current Core redacted receipts,
provider-runtime acceptance, session projection, and restart/cold-start/
rollback receipts. It may never send operator credentials, provider/OAuth
tokens, cookies, account identity, raw session IDs, prompts, outputs, private
paths, raw provider errors, environment values, or PIDs to the browser.

## Provider and isolation boundary

`native-cli` and `local-openai-compatible` are distinct provider families; the
latter does not impersonate native Codex or Claude session semantics. The
current architecture hypothesis is host-side inference with separately
sandboxed workloads. Lens Sandbox adoption and local Qwen execution require
their own accepted future gates and are not part of this slice.
