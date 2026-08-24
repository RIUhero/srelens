// @vitest-environment node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = join(__dirname, "../../../..");
const workflow = readFileSync(
  join(root, ".github/workflows/mydashboard-acceptance.yml"),
  "utf8",
);
const checkScript = readFileSync(
  join(root, "scripts/mydashboard/check-linux-desktop-prerequisites.sh"),
  "utf8",
);
const buildScript = readFileSync(
  join(root, "scripts/mydashboard/build-linux-desktop.sh"),
  "utf8",
);
const containerScript = readFileSync(
  join(root, "scripts/mydashboard/build-linux-desktop-container.sh"),
  "utf8",
);

describe("MyDashboard desktop acceptance contract", () => {
  it.each([
    "frontend-typecheck-test-build",
    "rust-non-desktop-build-test",
    "desktop-linux-build",
    "cargo-audit",
    "projection-security-tests",
  ])("keeps the %s CI gate", (job) => {
    expect(workflow).toContain(`  ${job}:`);
  });

  it("pins every GitHub action and keeps top-level permissions read-only", () => {
    const uses = workflow.match(/^\s*- uses:.*$/gm) ?? [];
    expect(uses.length).toBeGreaterThan(0);
    for (const line of uses) {
      expect(line).toMatch(/@[0-9a-f]{40}(?:\s|$)/);
    }
    expect(workflow).toContain("permissions:\n  contents: read");
    expect(workflow).not.toContain("secrets.");
  });

  it("binds caches and build receipts to locked inputs and exact source", () => {
    expect(workflow).toContain("hashFiles('Cargo.lock')");
    expect(workflow).toContain("cache-dependency-path: pnpm-lock.yaml");
    expect(workflow).toContain("MYDASHBOARD_EXPECTED_HEAD");
    expect(checkScript).toContain("git rev-parse HEAD");
    expect(checkScript).toContain("git rev-parse 'HEAD^{tree}'");
    expect(buildScript).toContain("pnpm install --frozen-lockfile --ignore-scripts");
    expect(buildScript).toContain("cargo build --locked");
    expect(buildScript).toContain(
      "pnpm --filter @srelens/desktop tauri build --bundles deb",
    );
    expect(buildScript).not.toContain("tauri build -- --bundles");
    expect(buildScript).toContain("artifactSha256");
    expect(containerScript).toContain("ubuntu@sha256:");
    expect(containerScript).toContain('${BASH_SOURCE[0]}');
    expect(containerScript).toContain("sha256sum --check --strict");
    expect(containerScript).toContain("--default-toolchain 1.98.0");
    expect(containerScript).toContain("pnpm@9.15.9");
    expect(containerScript).toContain("docker run --rm");
  });

  it("does not run a provider or consume signing/provider credentials", () => {
    expect(buildScript).toContain("unset OPENAI_API_KEY ANTHROPIC_API_KEY");
    expect(buildScript).toContain("unset TAURI_SIGNING_PRIVATE_KEY");
    expect(buildScript).not.toMatch(/^\s*(codex|claude|opencode|qwen)(?:\s|$)/im);
    expect(workflow).not.toMatch(/provider[_ -]dispatch|provider[_ -]login/i);
  });
});
