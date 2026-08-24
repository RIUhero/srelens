import { useEffect, useMemo, useState, type ReactNode } from "react";
import { enabledWorkstationModules, type WorkstationModule } from "./WorkstationModule";

const BASE_MODULE_ID = "srelens";
export const WORKSTATION_NAV_HEIGHT_PX = 40;

export function WorkstationShell({
  baseView,
  modules,
}: {
  baseView: ReactNode;
  modules: readonly WorkstationModule[];
}) {
  const enabledModules = useMemo(() => enabledWorkstationModules(modules), [modules]);
  const [activeId, setActiveId] = useState(BASE_MODULE_ID);
  const activeModule = enabledModules.find((module) => module.id === activeId) ?? null;

  useEffect(() => {
    if (!activeModule) return;
    activeModule.lifecycle.onActivate?.();
    return () => activeModule.lifecycle.onDeactivate?.();
  }, [activeModule]);

  // AppGate never mounts this shell when no module is enabled. Keeping this
  // fail-safe preserves the same invariant for isolated callers and tests.
  if (enabledModules.length === 0) return baseView;

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-background text-foreground">
      <nav
        aria-label="Workstation modules"
        className="flex shrink-0 items-center gap-1 border-b border-border bg-card px-3"
        style={{ height: WORKSTATION_NAV_HEIGHT_PX }}
      >
        <button
          type="button"
          aria-current={activeId === BASE_MODULE_ID ? "page" : undefined}
          className="rounded-md px-3 py-1 text-sm font-medium hover:bg-muted aria-[current=page]:bg-muted"
          onClick={() => setActiveId(BASE_MODULE_ID)}
        >
          SRELens
        </button>
        {enabledModules.map((module) => (
          <button
            key={module.id}
            type="button"
            aria-label={module.navigationContribution.ariaLabel}
            aria-current={activeId === module.id ? "page" : undefined}
            className="rounded-md px-3 py-1 text-sm font-medium hover:bg-muted aria-[current=page]:bg-muted"
            onClick={() => setActiveId(module.id)}
          >
            {module.navigationContribution.label}
          </button>
        ))}
      </nav>
      <div className="fl-workstation__content min-h-0 flex-1 overflow-auto">
        {activeModule ? activeModule.render() : baseView}
      </div>
    </div>
  );
}
