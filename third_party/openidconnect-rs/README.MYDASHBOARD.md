# MyDashboard OpenID Connect security fork

This directory is a narrowly scoped, source-vendored fork of
`openidconnect` 4.0.1. The application-facing OpenID Connect API and protocol
implementation remain upstream-native.

## Exact upstream provenance

- repository: `https://github.com/ramosbugs/openidconnect-rs`
- tag: `4.0.1`
- commit: `b639b5d39eac6903238867aeb2b29326502e6b26`
- tree: `0e89785a3008b9461ed2b35a2b949bfb742907d1`
- license: MIT; the unmodified upstream `LICENSE` is retained here

Files that only support the upstream repository's own CI or historical MSRV
lock were omitted from the vendored package. Product source, tests, examples,
license, and README are retained.

## Bounded patch

The upstream `rsa 0.9.x` backend is replaced with exact `ring 0.17.14` for
RS256/RS384/RS512 and PS256/PS384/PS512 signing and verification. PEM decoding
uses `pem-rfc7468 0.7`. No discovery, authorization-code, PKCE, nonce, token,
refresh, claims, provider metadata, or HTTP transport semantics are changed.

The compatibility behavior for RSA JWK modulus/exponent values with leading
zero octets is retained. RSA private-key loading still accepts PKCS#1
`RSA PRIVATE KEY` PEM and rejects other labels fail closed. `ring` enforces a
2048-bit minimum for these non-legacy RSA verification algorithms.

This removes `rsa` from the exact product lockfile instead of suppressing
RUSTSEC-2023-0071. There is no `cargo audit` ignore or advisory allowlist.

## Verification contract

Before updating this fork:

1. diff the new upstream tag against the provenance above;
2. reapply or delete only the bounded backend patch;
3. run `cargo test --all-features` in this directory;
4. run the SRELens full Rust workspace test suite and desktop locked build;
5. run `cargo audit --file Cargo.lock` at the SRELens repository root;
6. confirm `cargo tree --locked -i rsa` has no package to display.

The initial patch passed all 70 upstream unit tests and all 7 enabled doc tests
with the 21 network certification tests left ignored by upstream defaults.
