# Exact SRELens Upstream Baseline

The implementation began from the following live-verified source on
2026-08-24:

| Item | Exact value |
|---|---|
| controlled fork | `https://github.com/RIUhero/srelens` |
| upstream | `https://github.com/srelens/srelens` |
| branch | `dev` |
| fork HEAD | `b355c719c538c03898a0d6a82a93af14978d24cd` |
| upstream HEAD | `b355c719c538c03898a0d6a82a93af14978d24cd` |
| source tree | `bbea7927bef2777959e837c70ebf1261c1b21364` |
| divergence | `0 ahead / 0 behind` |
| license | MIT |

The remote return point is
`return/mydashboard-workstation-pre-v1-20260824` at the exact starting HEAD.
Implementation occurs on `feat/mydashboard-workstation-v1`, never directly on
`dev`.

Upstream SRELens remains authoritative for Kubernetes UI, capability registry,
server, transport, terminal, and desktop behavior. This fork adds only a
disabled-by-default workstation composition seam, a non-production redacted
projection fixture, focused security hardening, and provenance documents. It
does not delete or reinterpret Kubernetes capability state.

Reference audit: [MyDashBoard-Clean upstream report](https://github.com/RIUhero/MyDashBoard-Clean/blob/bb873ba5e87beb2a30b36077b83c26ec3a39199d/references/UPSTREAM_BASELINE_REPORT.md).
