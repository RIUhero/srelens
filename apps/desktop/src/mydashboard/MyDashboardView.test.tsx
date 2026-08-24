import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import type { CoreProjectionReader } from "./coreProjection";
import { MyDashboardView } from "./MyDashboardView";
import { staticCoreProjectionReader } from "./staticProjection";

describe("MyDashboardView", () => {
  it("renders read-only task and workspace projections", async () => {
    render(<MyDashboardView reader={staticCoreProjectionReader} />);
    expect(await screen.findByRole("heading", { name: "task_public_001" })).toBeTruthy();
    expect(screen.getByText("Static fixture · not runtime evidence")).toBeTruthy();
    expect(screen.queryByRole("button", { name: /run|dispatch|provider/i })).toBeNull();
    fireEvent.click(screen.getByRole("tab", { name: "workspaces" }));
    expect(screen.getByText("workspace_alpha")).toBeTruthy();
    expect(screen.getByText("workspace_beta")).toBeTruthy();
  });

  it("fails closed without rendering a raw reader error", async () => {
    const reader: CoreProjectionReader = {
      source: "core-read-only-capability",
      productionUsable: false,
      read: async () => {
        throw new Error("token=private raw provider error");
      },
    };
    render(<MyDashboardView reader={reader} />);
    await waitFor(() => expect(screen.getByRole("alert")).toBeTruthy());
    expect(screen.getByRole("alert").textContent).toContain("failed closed");
    expect(document.body.textContent).not.toContain("token=private");
  });

  it("renders a live empty Core projection without inventing canonical state", async () => {
    const reader: CoreProjectionReader = {
      source: "core-read-only-capability",
      productionUsable: true,
      read: async () => ({ tasks: [] }),
    };
    render(<MyDashboardView reader={reader} />);
    expect(await screen.findByText("Live Core · read-only")).toBeTruthy();
    expect(screen.getByText("No tasks are projected. Phase B creates no canonical task state.")).toBeTruthy();
    fireEvent.click(screen.getByRole("tab", { name: "workspaces" }));
    expect(screen.getByText("No workspaces are projected. Phase B creates no canonical workspace state.")).toBeTruthy();
    expect(screen.queryByRole("button", { name: /run|dispatch|provider/i })).toBeNull();
  });
});
