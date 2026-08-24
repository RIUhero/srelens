import type { WorkstationModule } from "../workstation/WorkstationModule";
import { MyDashboardView } from "./MyDashboardView";
import { staticCoreProjectionReader } from "./staticProjection";

export function myDashboardFeatureEnabled(value: unknown = import.meta.env.VITE_SRELENS_MYDASHBOARD): boolean {
  return value === "1";
}

export function createMyDashboardModule(featureFlag = myDashboardFeatureEnabled()): WorkstationModule {
  return Object.freeze({
    id: "mydashboard",
    label: "MyDashboard",
    featureFlag,
    navigationContribution: {
      label: "MyDashboard",
      ariaLabel: "Open read-only MyDashboard",
    },
    // This slice registers no fake provider capability. Future Core access
    // must add a read-only Capability to the existing Rust Registry and list
    // that exact id here; this object is not a second registry.
    capabilityRegistration: {
      owner: "srelens-capability::Registry" as const,
      capabilityIds: [],
    },
    projectionSource: {
      kind: staticCoreProjectionReader.source,
      productionUsable: staticCoreProjectionReader.productionUsable,
    },
    lifecycle: {},
    render: () => <MyDashboardView reader={staticCoreProjectionReader} />,
  });
}
