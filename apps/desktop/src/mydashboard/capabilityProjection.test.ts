import { describe, expect, it, vi } from "vitest";
import { CapabilityCoreProjectionReader, CORE_PROJECTION_CAPABILITY_ID } from "./capabilityProjection";

describe("CapabilityCoreProjectionReader", () => {
  it("uses the one read-only capability and accepts a live empty projection", async () => {
    const invoke = vi.fn(async () => ({ tasks: [] }));
    const reader = new CapabilityCoreProjectionReader(invoke);

    await expect(reader.read()).resolves.toEqual({ tasks: [] });
    expect(invoke).toHaveBeenCalledWith(CORE_PROJECTION_CAPABILITY_ID, null);
    expect(reader.source).toBe("core-read-only-capability");
    expect(reader.productionUsable).toBe(true);
  });

  it.each([
    { tasks: [], rawPrompt: "secret" },
    { tasks: [], canonicalState: true },
    { tasks: [{ rawProviderError: "secret" }] },
  ])("fails closed on unknown or sensitive payloads", async (payload) => {
    const reader = new CapabilityCoreProjectionReader(async () => payload);
    await expect(reader.read()).rejects.toThrow("Core projection unavailable");
  });

  it("replaces raw capability failures with a fixed browser-safe error", async () => {
    const reader = new CapabilityCoreProjectionReader(async () => {
      throw new Error("token=private raw provider error /private/path");
    });
    const error = await reader.read().catch((reason: unknown) => reason);
    expect(error).toBeInstanceOf(Error);
    expect((error as Error).message).toBe("Core projection unavailable");
    expect((error as Error).message).not.toContain("private");
  });
});
