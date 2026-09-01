import type { WorkstationModule } from "../workstation/WorkstationModule";
import { capabilityCoreProjectionReader, CORE_PROJECTION_CAPABILITY_ID } from "./capabilityProjection";
import { MyDashboardView } from "./MyDashboardView";
import { staticCoreProjectionReader } from "./staticProjection";

export function myDashboardFeatureEnabled(value: unknown = import.meta.env.VITE_SRELENS_MYDASHBOARD): boolean {
  return value === "1";
}

export function createMyDashboardModule(featureFlag = myDashboardFeatureEnabled()): WorkstationModule {
  const reader = featureFlag ? capabilityCoreProjectionReader : staticCoreProjectionReader;
  return Object.freeze({
    id: "mydashboard",
    label: "MyDashboard",
    featureFlag,
    navigationContribution: {
      label: "MyDashboard",
      ariaLabel: "Open read-only MyDashboard",
    },
    // The exact read-only Core capability lives in the existing Rust Registry.
    // This module remains composition metadata, never a second registry.
    capabilityRegistration: {
      owner: "srelens-capability::Registry" as const,
      capabilityIds: featureFlag ? [CORE_PROJECTION_CAPABILITY_ID] : [],
    },
    projectionSource: {
      kind: reader.source,
      productionUsable: reader.productionUsable,
    },
    lifecycle: {},
    render: () => <MyDashboardView reader={reader} />,
  });
}
