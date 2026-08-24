import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import type { WorkstationModule } from "./WorkstationModule";
import { WORKSTATION_NAV_HEIGHT_PX, WorkstationShell } from "./WorkstationShell";

function module(featureFlag: boolean, onActivate = vi.fn(), onDeactivate = vi.fn()): WorkstationModule {
  return {
    id: "test-module",
    label: "Test module",
    featureFlag,
    navigationContribution: { label: "Test module", ariaLabel: "Open test module" },
    capabilityRegistration: { owner: "srelens-capability::Registry", capabilityIds: [] },
    projectionSource: { kind: "static-redacted-fixture", productionUsable: false },
    lifecycle: { onActivate, onDeactivate },
    render: () => <p>Module view</p>,
  };
}

describe("WorkstationShell", () => {
  it("renders the unwrapped base view when every module is disabled", () => {
    const { container } = render(<WorkstationShell baseView={<p>Base view</p>} modules={[module(false)]} />);
    expect(screen.getByText("Base view")).toBeTruthy();
    expect(screen.queryByRole("navigation", { name: "Workstation modules" })).toBeNull();
    expect(container.firstElementChild?.tagName).toBe("P");
  });

  it("contributes navigation and balances lifecycle hooks", () => {
    const onActivate = vi.fn();
    const onDeactivate = vi.fn();
    render(<WorkstationShell baseView={<p>Base view</p>} modules={[module(true, onActivate, onDeactivate)]} />);
    expect(screen.getByRole("navigation", { name: "Workstation modules" }).style.height).toBe(
      `${WORKSTATION_NAV_HEIGHT_PX}px`,
    );
    fireEvent.click(screen.getByRole("button", { name: "Open test module" }));
    expect(screen.getByText("Module view")).toBeTruthy();
    expect(onActivate).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("button", { name: "SRELens" }));
    expect(screen.getByText("Base view")).toBeTruthy();
    expect(onDeactivate).toHaveBeenCalledTimes(1);
  });
});
