import type { ReactNode } from "react";

/**
 * A workstation contribution is composition metadata only. It never owns
 * canonical product state; state must come from the declared projection
 * source and operations must remain in SRELens' Rust capability registry.
 */
export interface WorkstationModule {
  readonly id: string;
  readonly label: string;
  readonly featureFlag: boolean;
  readonly navigationContribution: {
    readonly label: string;
    readonly ariaLabel: string;
  };
  readonly capabilityRegistration: {
    /** The existing Rust registry is the sole operation registry. */
    readonly owner: "srelens-capability::Registry";
    readonly capabilityIds: readonly string[];
  };
  readonly projectionSource: {
    readonly kind: "static-redacted-fixture" | "core-read-only-capability";
    readonly productionUsable: boolean;
  };
  readonly lifecycle: {
    readonly onActivate?: () => void;
    readonly onDeactivate?: () => void;
  };
  render(): ReactNode;
}

export function enabledWorkstationModules(
  modules: readonly WorkstationModule[],
): readonly WorkstationModule[] {
  return modules.filter((module) => module.featureFlag);
}
