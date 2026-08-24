# MyDashboard SQLx SQLite-only lock closure

SRELens uses only SQLx's SQLite backend. Cargo lockfiles nevertheless resolve
the optional MySQL and PostgreSQL dependencies declared by the published SQLx
facade and macro-core packages. `sqlx-mysql 0.8.6` depends on the vulnerable
`rsa 0.9.10`, even though that backend is not compiled by SRELens.

This directory contains exact crates.io package sources for two manifest-only,
SQLite-scoped forks:

| package | version | exact crates.io archive SHA-256 |
| --- | --- | --- |
| `sqlx` | 0.8.6 | `1fefb893899429669dcdd979aff487bd78f4064e5e7907e4269081e0ef7d97dc` |
| `sqlx-macros-core` | 0.8.6 | `19a9c1841124ac5a61741f96e1d9e2ec77424bf323962dd894bdb93f37d5219b` |

The only changes are to the two normalized `Cargo.toml` files:

- remove optional `sqlx-mysql` and `sqlx-postgres` dependency declarations;
- remove their transitive feature edges;
- retain SQLite, migration, derive, macro, runtime, and type feature edges;
- leave `mysql` and `postgres` as empty compatibility markers, so this product
  fork never silently acquires a non-SQLite backend.

No SQLx Rust source is modified. The original MIT/Apache-2.0 license files,
crate metadata, and product compilation source are retained. Upstream-only CI,
benchmarks, examples, database integration tests, test certificates/keys, and
historical documents are omitted because they are not package build inputs.
The application dependency remains
`default-features = false` with exactly `runtime-tokio`, `sqlite`, `migrate`,
and `macros` enabled.

Verification must prove all of the following on the root lockfile:

- the server database/migration tests pass unchanged;
- `cargo tree --locked -e features -p srelens-server` contains SQLite but not
  MySQL or PostgreSQL;
- `cargo tree --locked -i rsa` has no package to display;
- `cargo audit --file Cargo.lock` passes without an advisory ignore;
- the full Rust workspace and locked desktop build pass.

The repository `.gitattributes` disables whitespace normalization only for
retained immutable upstream source bytes. Product-owned manifests, contracts,
and documentation retain normal whitespace validation.
