# MyDashboard Workstation Slice Goal

This repository remains SRELens first. The goal of this slice is to prove the
smallest upstream-friendly seam through which a future MyDashboard Core can
contribute a redacted, read-only workstation view without taking over SRELens'
Kubernetes product or creating another source of truth.

The slice is complete only when all of the following are true:

- SRELens behavior is unchanged while `VITE_SRELENS_MYDASHBOARD` is absent;
- one `WorkstationModule` contract covers identity, feature gating, navigation,
  capability ownership, projection source, lifecycle, and rendering;
- the enabled prototype exposes only MyDashboard Tasks and Workspaces derived
  from an allowlisted Core projection;
- no task, provider, session, workspace, lease, queue, scheduler, release, or
  rollback authority is stored in the module;
- no provider request, model usage, service installation, deployment, or
  credential operation is performed;
- supply-chain, desktop-build, and empirical-runtime claims remain independent.

This slice does not implement Goal, Queue, Graph, Scheduler, native provider
execution, Lens Sandbox, Hermes, MemKraft, remote/mobile access, or local model
execution. The old MyDashboard repositories remain recoverable references.

The controlling architecture/reference source is
[`RIUhero/MyDashBoard-Clean` Draft PR #4](https://github.com/RIUhero/MyDashBoard-Clean/pull/4)
at exact reviewed head `bb873ba5e87beb2a30b36077b83c26ec3a39199d`.
