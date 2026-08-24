import { describe, expect, it } from "vitest";
import { parseCoreProjection, StaticCoreProjectionReader } from "./coreProjection";

const validTask = {
  taskPublicId: "task_public_001",
  state: "PASS",
  providerFamily: "native-cli",
  workspacePublicRef: "workspace_alpha",
  parentPublicRef: null,
  updatedAt: "2026-08-24T00:00:00.000Z",
  safeEvent: "acceptance_passed",
};

describe("Core projection allowlist", () => {
  it("accepts only the redacted public projection", () => {
    expect(parseCoreProjection({ tasks: [validTask] })).toEqual({ tasks: [validTask] });
  });

  it.each([
    "operatorCredential",
    "providerToken",
    "oauthToken",
    "cookie",
    "accountEmail",
    "accountId",
    "rawSessionId",
    "rawPrompt",
    "rawOutput",
    "privateFilesystemPath",
    "rawProviderError",
    "environment",
    "pid",
  ])("fails closed when a sensitive field is present: %s", (field) => {
    expect(() => parseCoreProjection({ tasks: [{ ...validTask, [field]: "secret" }] })).toThrow(
      "task fields are not allowlisted",
    );
  });

  it("rejects unknown envelope fields", () => {
    expect(() => parseCoreProjection({ tasks: [validTask], canonicalState: true })).toThrow("invalid envelope");
  });

  it.each([
    ["state", "RUNNING"],
    ["providerFamily", "remote-mock"],
    ["safeEvent", "prompt: reveal"],
    ["updatedAt", "yesterday"],
    ["workspacePublicRef", "/private/workspace"],
  ])("rejects unsafe %s values", (field, value) => {
    expect(() => parseCoreProjection({ tasks: [{ ...validTask, [field]: value }] })).toThrow();
  });

  it("revalidates a fixture on every read and remains non-production", async () => {
    const fixture = { tasks: [{ ...validTask }] };
    const reader = new StaticCoreProjectionReader(fixture);
    expect(reader.productionUsable).toBe(false);
    await expect(reader.read()).resolves.toEqual({ tasks: [validTask] });
    Object.assign(fixture.tasks[0], { rawPrompt: "do not expose" });
    await expect(reader.read()).rejects.toThrow("task fields are not allowlisted");
  });
});
