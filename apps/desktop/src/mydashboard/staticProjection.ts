import { StaticCoreProjectionReader } from "./coreProjection";

// Provider-free, redacted design fixture. It demonstrates projection shape
// only and is never production or empirical acceptance evidence.
export const staticCoreProjectionReader = new StaticCoreProjectionReader({
  tasks: [
    {
      taskPublicId: "task_public_001",
      state: "PASS",
      providerFamily: "native-cli",
      workspacePublicRef: "workspace_alpha",
      parentPublicRef: null,
      updatedAt: "2026-08-24T00:00:00.000Z",
      safeEvent: "acceptance_passed",
    },
    {
      taskPublicId: "task_public_002",
      state: "BLOCKED",
      providerFamily: "local-openai-compatible",
      workspacePublicRef: "workspace_alpha",
      parentPublicRef: "task_public_001",
      updatedAt: "2026-08-24T00:05:00.000Z",
      safeEvent: "acceptance_pending",
    },
    {
      taskPublicId: "task_public_003",
      state: "UNVERIFIED",
      providerFamily: "native-cli",
      workspacePublicRef: "workspace_beta",
      parentPublicRef: null,
      updatedAt: "2026-08-24T00:10:00.000Z",
      safeEvent: "projection_observed",
    },
  ],
});
