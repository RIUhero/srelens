# Supply-Chain Decisions

Audit date: 2026-08-24. Build success, lockfile audit, and graphical runtime
acceptance remain independent.

## Previously resolved controls

### RUSTSEC-2026-0235 (`rkyv`)

The former lock path was `tauri-plugin-log 2.8.0 → byte-unit 5.2.3 →
rust_decimal 1.42.1 → rkyv 0.7.46`. Exact `tauri-plugin-log =2.9.0` removes
that unused chain. The former OSV suppression remains deleted.

### Mutable Git dependency

`fix-path-env` remains pinned to exact revision
`c4c45d503ea115a839aae718d02f79e7c7f0f673`, matching its lock entry. The
inspected crate declares `Apache-2.0 OR MIT` and retains both license texts.

### Tauri CSP and production chunks

The existing non-null, fail-closed CSP and bounded production chunking are
unchanged. The Workstation feature remains default-off; its strict projection
allowlist and all existing SRELens behavior remain in force.

## RUSTSEC-2023-0071 closure

### Corrected lock paths

The starting lockfile had two sources of `rsa 0.9.10`, not one:

1. active runtime path: `openidconnect 4.0.1 → rsa 0.9.10`;
2. resolved but inactive backend path: `sqlx 0.8.6 → sqlx-mysql 0.8.6 →
   rsa 0.9.10`.

SRELens uses OIDC discovery, authorization code plus PKCE, nonce-bound ID-token
verification, token/refresh handling, and provider metadata. It uses SQLx only
with `default-features = false` and the exact `runtime-tokio`, `sqlite`,
`migrate`, and `macros` features. Removing authentication or SQL persistence
would therefore be a product regression, while leaving the inactive MySQL
package in the lockfile would keep `cargo audit` fail-closed.

### Upstream disposition

`openidconnect` 4.0.1 is still the latest stable release and depends on the
affected RSA series unconditionally. RustSec lists no patched RSA release, and
the upstream constant-time padding work remains open. An open OpenID Connect
pull request targets an RSA 0.10 prerelease; it is not a stable, advisory-closing
upgrade. No official fixed version or feature-removal path is currently
available.

### Bounded compatibility fork

`third_party/openidconnect-rs` is source-vendored from exact upstream tag 4.0.1:

- commit: `b639b5d39eac6903238867aeb2b29326502e6b26`;
- tree: `0e89785a3008b9461ed2b35a2b949bfb742907d1`;
- license: MIT, retained unchanged.

Only the RSA backend and its focused tests are changed. Exact `ring 0.17.14`
now performs RS256/384/512 and PS256/384/512 signing and verification;
`pem-rfc7468 0.7` decodes PKCS#1 `RSA PRIVATE KEY` input and rejects other PEM
labels. Discovery, PKCE, nonce, token, refresh, claims, metadata, and transport
semantics are untouched. Leading-zero JWK modulus/exponent compatibility is
retained, and non-legacy RSA verification keeps `ring`'s 2048-bit minimum.

### SQLite-only lock closure

Cargo resolves optional backend declarations into the lockfile even though the
product does not compile SQLx MySQL or PostgreSQL. Two exact crates.io packages
are therefore source-vendored with normalized-manifest-only changes:

| package | version | original archive SHA-256 |
| --- | --- | --- |
| `sqlx` | 0.8.6 | `1fefb893899429669dcdd979aff487bd78f4064e5e7907e4269081e0ef7d97dc` |
| `sqlx-macros-core` | 0.8.6 | `19a9c1841124ac5a61741f96e1d9e2ec77424bf323962dd894bdb93f37d5219b` |

Their optional `sqlx-mysql` and `sqlx-postgres` dependency declarations and
feature edges are removed. Empty `mysql` and `postgres` markers fail closed
instead of silently acquiring another backend. No SQLx Rust source is changed;
SQLite, migration, macro, runtime, and type edges used by SRELens remain.
Upstream-only CI, benchmarks, examples, database integration tests, test
certificates/keys, and historical documents are not vendored because they are
not compilation inputs.

## Fail-closed acceptance

No advisory is ignored or allowlisted. The repository contract test requires:

- exact repository-owned patch paths and immutable upstream provenance;
- no `rsa`, `sqlx-mysql`, or `sqlx-postgres` package in `Cargo.lock`;
- exact OIDC `ring 0.17.14` backend and no `rsa` dependency;
- exact SQLx archive checksums and SQLite-only application features;
- plain `cargo audit --file Cargo.lock` with no ignore argument.

The empirical gate additionally requires locked metadata, dependency-tree
inspection, the complete vendored OIDC test suite, the SRELens Rust/frontend
regressions, locked desktop compile/package, and `cargo audit`. A clean audit is
recorded as supply-chain evidence only after those commands pass on the exact
candidate; it does not substitute for actual graphical runtime smoke.

## Candidate empirical receipt

The 2026-08-24 bounded ai-worker verification used Rust/Cargo 1.98.0 and
`cargo-audit 0.22.2`:

- `cargo metadata --locked --no-deps`: passed;
- `cargo tree --locked -i rsa`: no matching package;
- active `srelens-server` SQLx tree: SQLite only, no MySQL/PostgreSQL;
- vendored OIDC tests: 70 unit tests passed, 7 doc tests passed, 2 doc tests and
  21 network certification tests retained their upstream-default ignore state;
- `cargo build --locked -p srelens-server`: passed;
- `cargo test --locked --workspace --exclude srelens-desktop`: passed;
- `cargo audit --file Cargo.lock`: 744 dependencies scanned, zero
  vulnerabilities, 18 non-vulnerability warnings.

The SQLx archive SHA-256 values were rechecked. Recursive comparison of every
retained product compilation source file against both original crates.io
archives found no source difference; only the two normalized `Cargo.toml`
files are patched. Therefore `supplyChainVerified=true` for this candidate.
Exact-head desktop compile/package and graphical runtime remain independent
gates.
