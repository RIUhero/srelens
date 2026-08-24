// @vitest-environment node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = join(__dirname, "../../../..");
const sandbox = readFileSync(join(root, "scripts/mydashboard/run-phase-b-bwrap.sh"), "utf8");
const contract = readFileSync(join(root, "scripts/mydashboard/test-phase-b-bwrap-contract.sh"), "utf8");
const harness = readFileSync(join(root, "scripts/mydashboard/phase-b-physical-root-harness.sh"), "utf8");
const xauthorityRootContract = readFileSync(join(root, "scripts/mydashboard/test-phase-b-xauthority-root.sh"), "utf8");

describe("Phase B physical Bubblewrap incident regression", () => {
  it("constructs mountpoints before sealing a minimal root", () => {
    expect(sandbox).not.toContain("--ro-bind / /");
    expect(sandbox.indexOf("--tmpfs /campaign")).toBeLessThan(sandbox.indexOf("--dir /campaign/source"));
    expect(sandbox.indexOf("--dir /campaign/source")).toBeLessThan(sandbox.indexOf('--ro-bind "$campaign_real" /campaign/source'));
    expect(sandbox.indexOf("--dir /results")).toBeLessThan(sandbox.indexOf('--bind "$results_real" /results'));
    expect(sandbox.indexOf("--remount-ro /")).toBeGreaterThan(sandbox.indexOf('--bind "$results_real" /results'));
    for (const systemPath of ["/usr", "/etc", "/sys"]) {
      expect(sandbox).toContain(`--ro-bind ${systemPath} ${systemPath}`);
    }
  });

  it("keeps home hidden, network isolated, artifacts read-only, and output bounded", () => {
    expect(sandbox).toContain("--tmpfs /home");
    expect(sandbox).toContain("--unshare-net");
    expect(sandbox).toContain("--tmpfs /campaign");
    expect(sandbox).toContain('--ro-bind "$campaign_real" /campaign/source');
    expect(sandbox).toContain('--bind "$results_real" /results');
    expect(sandbox).toContain('--ro-bind "$xauthority" /run/Xauthority');
    expect(sandbox).not.toMatch(/--bind \/ \/|--share-net/);
  });

  it("covers the incident, escape attempts, early exit, and zero-side-effect cleanup", () => {
    for (const evidence of [
      "missing-campaign-not-reproduced",
      "symlink-escape",
      "Xauthority-hardlink",
      "invalid-campaign-source",
      "outside-root",
      "system-mutation",
      "provider-dispatch=false",
      "core-started=false",
      "residue=0",
    ]) {
      expect(contract).toContain(evidence);
    }
  });

  it("precreates Xauthority and restores Xorg, STOP, watchdog, and VT boundaries", () => {
    expect(harness).toContain('install -m 0600 -o "$run_user"');
    expect(harness).toContain("xauthority-metadata");
    expect(harness).toContain("safe_remove_xauthority");
    expect(harness).toContain("watchdog_seconds=600");
    expect(harness).toContain('touch "$results/STOP"');
    expect(harness).toContain('/usr/bin/chvt "${original_vt:-1}"');
    expect(harness).toContain("xorg-orphan");
    expect(harness).toContain("vt-restore");
    expect(harness).toContain('/usr/sbin/runuser -u "$run_user" -- env -i');
    expect(harness).toContain("unset cookie");
    expect(harness).toContain("xauthorityEntryReadable");
    expect(harness).toContain("capture_xauthority_cleanup_identity");
    expect(xauthorityRootContract).toContain("Xauthority-root-writer");
    expect(xauthorityRootContract).toContain("Xauthority-user-writer");
    expect(xauthorityRootContract).toContain("xauthority-root-contract=passed");
  });
});
