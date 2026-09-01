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

  it("declares one read-only Core capability in the existing Rust registry", () => {
    const module = createMyDashboardModule(true);
    expect(module.capabilityRegistration).toEqual({
      owner: "srelens-capability::Registry",
      capabilityIds: ["mydashboard.readProjection"],
    });
    expect(module.projectionSource).toEqual({
      kind: "core-read-only-capability",
      productionUsable: true,
    });
  });

  it("keeps the disabled path process- and capability-free", () => {
    const module = createMyDashboardModule(false);
    expect(module.capabilityRegistration.capabilityIds).toEqual([]);
    expect(module.projectionSource).toEqual({
      kind: "static-redacted-fixture",
      productionUsable: false,
    });
  });
});
