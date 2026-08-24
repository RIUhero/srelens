import { describe, expect, it } from "vitest";
import { createMyDashboardModule, myDashboardFeatureEnabled } from "../mydashboard/module";
import { enabledWorkstationModules } from "./WorkstationModule";

describe("WorkstationModule", () => {
  it("fails closed unless the exact feature flag value is 1", () => {
    expect(myDashboardFeatureEnabled(undefined)).toBe(false);
    expect(myDashboardFeatureEnabled("true")).toBe(false);
    expect(myDashboardFeatureEnabled("1")).toBe(true);
  });

  it("keeps disabled modules out of navigation", () => {
    expect(enabledWorkstationModules([createMyDashboardModule(false)])).toEqual([]);
  });

  it("declares the existing Rust registry and no fake provider capability", () => {
    const module = createMyDashboardModule(true);
    expect(module.capabilityRegistration).toEqual({
      owner: "srelens-capability::Registry",
      capabilityIds: [],
    });
    expect(module.projectionSource).toEqual({
      kind: "static-redacted-fixture",
      productionUsable: false,
    });
  });
});
