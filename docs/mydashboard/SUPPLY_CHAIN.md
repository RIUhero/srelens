# Supply-Chain Decisions

Audit date: 2026-08-24. Build success and supply-chain acceptance remain
separate.

## Resolved in this candidate

### RUSTSEC-2026-0235 (`rkyv`)

The exact lock path was `tauri-plugin-log 2.8.0 → byte-unit 5.2.3 →
rust_decimal 1.42.1 → rkyv 0.7.46`. `tauri-plugin-log 2.9.0` removes the unused
`byte-unit` dependency. The desktop manifest now pins exact `=2.9.0`; lockfile
regeneration removes `byte-unit`, `rust_decimal`, `rkyv`, and their archive
support chain. The former OSV suppression was deleted.

### Mutable Git dependency

`fix-path-env` previously named only the Git URL while Cargo.lock happened to
pin a commit. The manifest now pins exact revision
`c4c45d503ea115a839aae718d02f79e7c7f0f673`, matching the current upstream
`dev` head and lock entry. The inspected crate declares
`Apache-2.0 OR MIT` and contains both license texts.

### Tauri CSP

Production CSP is no longer `null`. Scripts are self-only; connections are
self plus Tauri IPC; objects, base replacement, and framing are denied. Images
retain only the protocols required by existing SRELens user-selected/custom
assets. Development exceptions are limited to the fixed Vite origin and are
not present in production CSP. Neither policy allows wildcard or unsafe eval.

### Vite production chunk

Explicit stable-library chunks split React, Radix, MobX, icons, and YAML.
There is no catch-all `node_modules` split. The baseline `AppGate` chunk was
625.28 kB; the first hardened build reported 439.50 kB and no >500 kB warning.

## Remaining blocker

RUSTSEC-2023-0071 remains active at `rsa 0.9.10 → openidconnect 4.0.1 →
srelens-server → srelens-desktop`. `openidconnect 4.0.1` depends on RSA
unconditionally, its current upstream source still uses the same RSA series,
and RustSec identifies no fixed upgrade. SRELens uses this path for public-key
OIDC signature verification rather than private-key decryption, but runtime
non-applicability is not a vulnerability fix and is not allowlisted here.

Replacing the OIDC/JWT implementation is security-sensitive and could regress
existing Kubernetes login. It is therefore not performed blindly in this
minimal seam. `supplyChainVerified=false` remains authoritative until an
upstream fixed release or a separately reviewed compatible replacement removes
the vulnerable crate from the exact lockfile.
