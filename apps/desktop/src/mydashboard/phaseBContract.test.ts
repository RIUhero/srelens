// @vitest-environment node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = join(__dirname, "../../../..");
const readRoot = (path: string) => readFileSync(join(root, path), "utf8");

const workspaceManifest = readRoot("Cargo.toml");
const coreManifest = readRoot("crates/mydashboard-core/Cargo.toml");
const coreProcess = readRoot("crates/mydashboard-core/src/lib.rs");
const desktopMain = readRoot("apps/desktop/src-tauri/src/main.rs");
const desktopBridge = readRoot(
  "apps/desktop/src-tauri/src/mydashboard_core.rs",
);
const frontendAdapter = readRoot(
  "apps/desktop/src/mydashboard/capabilityProjection.ts",
);
const buildScript = readRoot("scripts/mydashboard/build-linux-desktop.sh");
const coreCheck = readRoot("scripts/mydashboard/check-core-read-only.sh");

describe("MyDashboard Phase B provider-free Core contract", () => {
  it("keeps the Core as a minimal repository-owned crate", () => {
    expect(workspaceManifest).toContain('"crates/mydashboard-core"');
    expect(coreManifest).toContain('name = "srelens-mydashboard-core"');
    expect(coreManifest).toContain('serde = { version = "1.0"');
    expect(coreManifest).toContain('serde_json = "1.0"');
    const dependencyLines = coreManifest
      .split("[dependencies]\n")[1]
      .trim()
      .split("\n");
    expect(dependencyLines).toHaveLength(2);
    expect(dependencyLines.join("\n")).not.toMatch(
      /reqwest|hyper|axum|sqlx|keyring|openidconnect|oauth/i,
    );
  });

  it("dispatches Core mode before config, keychain, provider, or GUI startup", () => {
    const coreDispatch = desktopMain.indexOf("--mydashboard-core-stdio");
    expect(coreDispatch).toBeGreaterThan(0);
    for (const laterSurface of [
      'std::env::var("SRELENS_MASTER_PASSWORD")',
      "fix_path_env",
      "init_timeout_from_env",
      'std::env::var("GIO_EXTRA_MODULES")',
      "srelens_desktop_lib::run()",
    ]) {
      expect(desktopMain.indexOf(laterSurface)).toBeGreaterThan(coreDispatch);
    }
    expect(coreProcess).toContain("CoreProjection { tasks: Vec::new() }");
    expect(coreProcess).toContain("deny_unknown_fields");
  });

  it("keeps transport local, read-only, lazy, and fixed-error", () => {
    expect(desktopBridge).toContain('"mydashboard.readProjection"');
    expect(desktopBridge).toContain("Capability::read_only");
    expect(desktopBridge).toContain("env_clear()");
    expect(desktopBridge).toContain("stderr(Stdio::null())");
    expect(desktopBridge).toContain("kill_on_drop(true)");
    expect(desktopBridge).not.toMatch(/TcpListener|UdpSocket|reqwest|hyper|axum/);
    expect(frontendAdapter).toContain("invokeCapability");
    expect(frontendAdapter).toContain("parseCoreProjection");
    expect(frontendAdapter).not.toContain("staticCoreProjection");
  });

  it("runs an empty-environment empirical check in every desktop package build", () => {
    expect(buildScript).toContain(
      "scripts/mydashboard/check-core-read-only.sh target/release/srelens",
    );
    expect(buildScript).toContain("SRELENS_PHASE_B_BINARY");
    expect(coreCheck).toContain(
      'env -i "$core_binary" --mydashboard-core-stdio',
    );
    expect(coreCheck).toContain("core-clean-shutdown=passed");
    expect(coreCheck).toContain("provider-dispatch=false");
    expect(coreCheck).toContain("credential-access=false");
  });
});
