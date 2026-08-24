import { useEffect, useMemo, useRef, useState } from "react";
import type { CoreProjection, CoreProjectionReader, TaskState } from "./coreProjection";

type View = "tasks" | "workspaces";

const STATE_CLASS: Record<TaskState, string> = {
  PASS: "border-emerald-500/30 bg-emerald-500/10 text-emerald-700 dark:text-emerald-300",
  BLOCKED: "border-red-500/30 bg-red-500/10 text-red-700 dark:text-red-300",
  UNVERIFIED: "border-amber-500/30 bg-amber-500/10 text-amber-700 dark:text-amber-300",
};

function Status({ state }: { state: TaskState }) {
  return <span className={`rounded-full border px-2 py-0.5 text-xs font-semibold ${STATE_CLASS[state]}`}>{state}</span>;
}

export function MyDashboardView({ reader }: { reader: CoreProjectionReader }) {
  const [view, setView] = useState<View>("tasks");
  const [projection, setProjection] = useState<CoreProjection | null>(null);
  const [failed, setFailed] = useState(false);
  const headingRef = useRef<HTMLHeadingElement>(null);

  useEffect(() => {
    let active = true;
    void reader.read().then(
      (value) => active && setProjection(value),
      () => active && setFailed(true),
    );
    headingRef.current?.focus();
    return () => {
      active = false;
    };
  }, [reader]);

  const workspaces = useMemo(() => {
    const counts = new Map<string, Record<TaskState, number>>();
    for (const task of projection?.tasks ?? []) {
      const current = counts.get(task.workspacePublicRef) ?? { PASS: 0, BLOCKED: 0, UNVERIFIED: 0 };
      current[task.state] += 1;
      counts.set(task.workspacePublicRef, current);
    }
    return [...counts.entries()];
  }, [projection]);

  return (
    <main className="min-h-full bg-muted/20 p-6" aria-labelledby="mydashboard-title">
      <div className="mx-auto max-w-6xl space-y-5">
        <header className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">Read-only workstation module</p>
            <h1 id="mydashboard-title" ref={headingRef} tabIndex={-1} className="mt-1 text-2xl font-semibold outline-none">
              MyDashboard
            </h1>
            <p className="mt-1 text-sm text-muted-foreground">
              Redacted Core projection. No provider controls or canonical state are present here.
            </p>
          </div>
          <span className="rounded-md border border-amber-500/30 bg-amber-500/10 px-3 py-1.5 text-xs font-medium text-amber-800 dark:text-amber-200">
            Static fixture · not runtime evidence
          </span>
        </header>

        <div role="tablist" aria-label="MyDashboard views" className="flex gap-1 border-b border-border">
          {(["tasks", "workspaces"] as const).map((candidate) => (
            <button
              key={candidate}
              type="button"
              role="tab"
              id={`mydashboard-tab-${candidate}`}
              aria-controls={`mydashboard-panel-${candidate}`}
              aria-selected={view === candidate}
              className="border-b-2 border-transparent px-3 py-2 text-sm font-medium capitalize text-muted-foreground aria-selected:border-foreground aria-selected:text-foreground"
              onClick={() => setView(candidate)}
            >
              {candidate}
            </button>
          ))}
        </div>

        {failed && (
          <section role="alert" className="rounded-lg border border-red-500/30 bg-red-500/10 p-4 text-sm">
            Projection unavailable. The read-only view failed closed.
          </section>
        )}
        {!failed && !projection && <p className="text-sm text-muted-foreground">Loading redacted projection…</p>}

        {projection && view === "tasks" && (
          <section
            id="mydashboard-panel-tasks"
            role="tabpanel"
            aria-labelledby="mydashboard-tab-tasks"
            tabIndex={0}
            className="grid gap-3 outline-none focus-visible:ring-2 focus-visible:ring-ring"
          >
            {projection.tasks.map((task) => (
              <article key={task.taskPublicId} className="rounded-lg border border-border bg-card p-4 shadow-sm">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <h2 className="font-mono text-sm font-semibold">{task.taskPublicId}</h2>
                    <p className="mt-1 text-xs text-muted-foreground">{task.workspacePublicRef} · {task.providerFamily}</p>
                  </div>
                  <Status state={task.state} />
                </div>
                <dl className="mt-4 grid gap-2 text-xs sm:grid-cols-3">
                  <div><dt className="text-muted-foreground">Safe event</dt><dd className="mt-0.5 font-medium">{task.safeEvent}</dd></div>
                  <div><dt className="text-muted-foreground">Parent</dt><dd className="mt-0.5 font-mono">{task.parentPublicRef ?? "—"}</dd></div>
                  <div><dt className="text-muted-foreground">Updated</dt><dd className="mt-0.5">{task.updatedAt}</dd></div>
                </dl>
              </article>
            ))}
          </section>
        )}

        {projection && view === "workspaces" && (
          <section
            id="mydashboard-panel-workspaces"
            role="tabpanel"
            aria-labelledby="mydashboard-tab-workspaces"
            tabIndex={0}
            className="grid gap-3 outline-none focus-visible:ring-2 focus-visible:ring-ring sm:grid-cols-2"
          >
            {workspaces.map(([workspace, counts]) => (
              <article key={workspace} className="rounded-lg border border-border bg-card p-4 shadow-sm">
                <h2 className="font-mono text-sm font-semibold">{workspace}</h2>
                <div className="mt-4 flex flex-wrap gap-2">
                  {(["PASS", "BLOCKED", "UNVERIFIED"] as const).map((state) => (
                    <span key={state} className="flex items-center gap-1.5"><Status state={state} /><span className="text-sm">{counts[state]}</span></span>
                  ))}
                </div>
              </article>
            ))}
          </section>
        )}
      </div>
    </main>
  );
}
