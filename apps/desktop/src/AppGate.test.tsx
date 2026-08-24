import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@srelens/core/platform", () => ({ isWeb: false }));
vi.mock("@srelens/core", () => ({ fetchMe: vi.fn() }));
vi.mock("./App", () => ({
  App: ({ vaultGateTopInsetPx = 0 }: { vaultGateTopInsetPx?: number }) => (
    <p data-testid="base-vault-inset">{vaultGateTopInsetPx}</p>
  ),
}));
vi.mock("./mydashboard/module", () => ({
  myDashboardFeatureEnabled: () => true,
  createMyDashboardModule: () => ({
    id: "mydashboard",
    label: "MyDashboard",
    featureFlag: true,
    navigationContribution: {
      label: "MyDashboard",
      ariaLabel: "Open read-only MyDashboard",
    },
    capabilityRegistration: {
      owner: "srelens-capability::Registry",
      capabilityIds: [],
    },
    projectionSource: {
      kind: "static-redacted-fixture",
      productionUsable: false,
    },
    lifecycle: {},
    render: () => <p>MyDashboard view</p>,
  }),
}));

import AppGate from "./AppGate";
import { WORKSTATION_NAV_HEIGHT_PX } from "./workstation/WorkstationShell";

describe("AppGate workstation vault boundary", () => {
  it("reserves exactly the visible workstation navigation height above the base vault gate", () => {
    render(<AppGate />);

    expect(screen.getByTestId("base-vault-inset").textContent).toBe(
      String(WORKSTATION_NAV_HEIGHT_PX),
    );
    expect(screen.getByRole("navigation", { name: "Workstation modules" })).toBeTruthy();
  });
});
