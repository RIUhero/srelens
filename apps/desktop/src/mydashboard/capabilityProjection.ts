import { invokeCapability } from "@srelens/core";
import { parseCoreProjection, type CoreProjection, type CoreProjectionReader } from "./coreProjection";

export const CORE_PROJECTION_CAPABILITY_ID = "mydashboard.readProjection";
type ProjectionInvoker = (id: string, input?: unknown) => Promise<unknown>;

/**
 * Thin Phase B adapter. The Rust capability owns process communication; this
 * browser boundary only invokes the exact read-only id and re-applies the
 * strict projection allowlist. It never falls back to the Phase A fixture.
 */
export class CapabilityCoreProjectionReader implements CoreProjectionReader {
  readonly source = "core-read-only-capability" as const;
  readonly productionUsable = true;

  constructor(private readonly invoke: ProjectionInvoker = invokeCapability) {}

  async read(): Promise<CoreProjection> {
    try {
      const raw = await this.invoke(CORE_PROJECTION_CAPABILITY_ID, null);
      return parseCoreProjection(raw);
    } catch {
      // Never expose a raw backend/process/provider error to the browser view.
      throw new Error("Core projection unavailable");
    }
  }
}

export const capabilityCoreProjectionReader = new CapabilityCoreProjectionReader();
