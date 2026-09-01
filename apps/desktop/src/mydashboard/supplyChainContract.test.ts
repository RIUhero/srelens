// @vitest-environment node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = join(__dirname, "../../../..");
const readRoot = (path: string) => readFileSync(join(root, path), "utf8");

const workspaceManifest = readRoot("Cargo.toml");
const lockfile = readRoot("Cargo.lock");
const serverManifest = readRoot("crates/server/Cargo.toml");
const oidcManifest = readRoot("third_party/openidconnect-rs/Cargo.toml");
const oidcCrypto = readRoot("third_party/openidconnect-rs/src/core/crypto.rs");
const oidcJwk = readRoot("third_party/openidconnect-rs/src/core/jwk/mod.rs");
const sqlxManifest = readRoot(
  "third_party/sqlx-sqlite-only/sqlx/Cargo.toml",
);
const sqlxMacrosCoreManifest = readRoot(
  "third_party/sqlx-sqlite-only/sqlx-macros-core/Cargo.toml",
);
const workflow = readRoot(".github/workflows/mydashboard-acceptance.yml");

describe("MyDashboard supply-chain contract", () => {
  it("binds each security fork to an excluded, repository-owned path", () => {
    for (const path of [
      "third_party/openidconnect-rs",
      "third_party/sqlx-sqlite-only/sqlx",
      "third_party/sqlx-sqlite-only/sqlx-macros-core",
    ]) {
      expect(workspaceManifest).toContain(`"${path}"`);
      expect(workspaceManifest).toContain(`{ path = "${path}" }`);
    }
  });

  it("keeps the exact product lock closure free of RSA and unused SQL backends", () => {
    for (const packageName of ["rsa", "sqlx-mysql", "sqlx-postgres"]) {
      expect(lockfile).not.toMatch(
        new RegExp(`^name = "${packageName}"$`, "m"),
      );
    }

    for (const pathPackage of ["openidconnect", "sqlx", "sqlx-macros-core"]) {
      expect(lockfile).toMatch(
        new RegExp(`^name = "${pathPackage}"\\nversion = `, "m"),
      );
    }
  });

  it("pins the OIDC fork provenance and audited RSA backend", () => {
    expect(oidcManifest).toContain(
      'upstream-commit = "b639b5d39eac6903238867aeb2b29326502e6b26"',
    );
    expect(oidcManifest).toContain(
      'upstream-tree = "0e89785a3008b9461ed2b35a2b949bfb742907d1"',
    );
    expect(oidcManifest).toContain('ring = "=0.17.14"');
    expect(oidcManifest).not.toMatch(/^rsa\s*=/m);
    expect(oidcManifest).not.toMatch(/^dyn-clone\s*=/m);
    expect(oidcCrypto).toContain("ring::signature::RsaPublicKeyComponents");
    expect(oidcJwk).toContain("ring::signature::RsaKeyPair");
    expect(oidcCrypto).not.toMatch(/\brsa::/);
    expect(oidcJwk).not.toMatch(/\brsa::/);
  });

  it("keeps SQLx manifest changes SQLite-scoped and source-preserving", () => {
    expect(sqlxManifest).toContain(
      'upstream-crate-checksum = "1fefb893899429669dcdd979aff487bd78f4064e5e7907e4269081e0ef7d97dc"',
    );
    expect(sqlxMacrosCoreManifest).toContain(
      'upstream-crate-checksum = "19a9c1841124ac5a61741f96e1d9e2ec77424bf323962dd894bdb93f37d5219b"',
    );

    for (const manifest of [sqlxManifest, sqlxMacrosCoreManifest]) {
      expect(manifest).not.toMatch(/^\[dependencies\.sqlx-mysql\]$/m);
      expect(manifest).not.toMatch(/^\[dependencies\.sqlx-postgres\]$/m);
      expect(manifest).toMatch(/^mysql = \[\]$/m);
      expect(manifest).toMatch(/^postgres = \[\]$/m);
    }

    expect(serverManifest).toContain(
      'sqlx = { version = "0.8", default-features = false, features = ["runtime-tokio", "sqlite", "migrate", "macros"] }',
    );
  });

  it("keeps cargo audit fail-closed without an advisory allowlist", () => {
    expect(workflow).toContain("cargo audit --file Cargo.lock");
    expect(workflow).not.toMatch(/cargo audit[^\n]*(?:--ignore|-i\s+RUSTSEC)/);
    expect(workflow).not.toContain("RUSTSEC-2023-0071");
  });
});
