// @vitest-environment node
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const root = join(__dirname, "../../../..");
const sandbox = readFileSync(join(root, "scripts/mydashboard/run-phase-b-bwrap.sh"), "utf8");
const contract = readFileSync(join(root, "scripts/mydashboard/test-phase-b-bwrap-contract.sh"), "utf8");
const harness = readFileSync(join(root, "scripts/mydashboard/phase-b-physical-root-harness.sh"), "utf8");
const readiness = readFileSync(join(root, "scripts/mydashboard/wait-webdriver-ready.sh"), "utf8");
const readinessContract = readFileSync(join(root, "scripts/mydashboard/test-phase-b-webdriver-readiness.sh"), "utf8");
const xauthorityRootContract = readFileSync(join(root, "scripts/mydashboard/test-phase-b-xauthority-root.sh"), "utf8");
const runtimeVerifier = readFileSync(join(root, "scripts/mydashboard/verify-phase-b-runtime-closure.sh"), "utf8");
const runtimeBuilder = readFileSync(join(root, "scripts/mydashboard/build-phase-b-runtime-closure.sh"), "utf8");
const runtimeContract = readFileSync(join(root, "scripts/mydashboard/test-phase-b-runtime-closure.sh"), "utf8");

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
    expect(sandbox).toContain("--setenv LD_LIBRARY_PATH /campaign/source/runtime/root/usr/lib/x86_64-linux-gnu");
    expect(sandbox).toContain("--setenv GST_PLUGIN_SYSTEM_PATH /campaign/source/runtime/gst-min");
    expect(sandbox).not.toMatch(/--bind \/ \/|--share-net/);
  });

  it("requires a campaign-pinned runtime closure before touching Xorg", () => {
    expect(harness).toContain("safe_fail runtime-closure");
    expect(harness).toContain("safe_fail webdriver-linkage");
    expect(harness).toContain("safe_fail webdriver-executable");
    expect(harness).toContain("safe_fail runner-readiness-contract");
    expect(harness).toContain("safe_fail runtime-file-digest");
    expect(harness).toContain("safe_fail runtime-symlink-digest");
    expect(harness).toContain("safe_fail runtime-symlink-escape");
    expect(harness).toContain("tools/verify-phase-b-runtime-closure.sh");
    expect(harness).toContain("safe_fail runtime-closure-integrity");
    expect(harness.indexOf("safe_fail webdriver-executable")).toBeLessThan(harness.indexOf("/usr/bin/openvt"));
  });

  it("builds a portable closure and rejects every dangling, escaping, absolute, or mutated link graph", () => {
    expect(runtimeBuilder).toContain("documentation and packaging metadata are not executable WebKit inputs");
    expect(runtimeBuilder).toContain('install -m 0700 "$plugin_source"');
    for (const classification of [
      "absolute-symlink",
      "dangling-or-cyclic-symlink",
      "escaping-symlink",
      "documentation-tree-present",
      "runtime-file-set",
      "runtime-symlink-set",
    ]) {
      expect(runtimeVerifier).toContain(classification);
      expect(runtimeContract).toContain(classification);
    }
    expect(runtimeContract).toContain("actual-webkit");
  });

  it("classifies bounded process, listener, empty-reply, and protocol readiness failures", () => {
    for (const classification of [
      "child-premature-exit",
      "listener-timeout",
      "empty-reply",
      "protocol-not-ready",
      "readiness-timeout",
    ]) {
      expect(readiness).toContain(classification);
    }
    expect(readiness).toContain(".value.ready == true");
    expect(readinessContract).toContain("phase-b-webdriver-readiness-contract=passed tests=5");
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
