# Migration and Evidence Provenance

## Authority chain

1. current approved workstation implementation instruction;
2. `RIUhero/MyDashBoard-Clean` Draft PR #4 exact reviewed head
   `bb873ba5e87beb2a30b36077b83c26ec3a39199d`;
3. live-equal `RIUhero/srelens` / `srelens/srelens` `dev` starting head
   `b355c719c538c03898a0d6a82a93af14978d24cd` and tree
   `bbea7927bef2777959e837c70ebf1261c1b21364`;
4. this feature candidate's code, tests, and exact verification results.

## Preserved verified-provider evidence

MyDashBoard-Clean is a reference/evidence repository, not this implementation
base. No Python adapter, provider wrapper, daemon, browser server, installer,
session repository, mock, fixture, or state file was copied from it.

- Phase 1 accepted empirical source:
  [`d7b5b3e6663568c820f879f198f3bc8a07100a0d`](https://github.com/RIUhero/MyDashBoard-Clean/tree/d7b5b3e6663568c820f879f198f3bc8a07100a0d),
  as recorded in
  [`PHASE2.md`](https://github.com/RIUhero/MyDashBoard-Clean/blob/bb873ba5e87beb2a30b36077b83c26ec3a39199d/PHASE2.md).
- Phase 2 frozen empirical head:
  [`483f168b10936b440007b8219759f6abb981615d`](https://github.com/RIUhero/MyDashBoard-Clean/tree/483f168b10936b440007b8219759f6abb981615d),
  as bound by
  [`PHASE3.md`](https://github.com/RIUhero/MyDashBoard-Clean/blob/bb873ba5e87beb2a30b36077b83c26ec3a39199d/PHASE3.md).
- Current architecture/reference review:
  [Draft PR #4](https://github.com/RIUhero/MyDashBoard-Clean/pull/4).

These historical results do not set this repository's workstation, desktop,
supply-chain, or runtime empirical state.

## Thin adaptation, not code migration

The implemented seam follows the audited contract—default-off module
composition, single SRELens capability-registry ownership, strict redacted
projection, and read-only Tasks/Workspaces—but is newly implemented against the
current SRELens frontend and domain boundaries. MyDashboard-specific canonical
state remains absent.

The separate historical Lab Console ZIP, mock-only providers, fixed workspace
paths, old build outputs, checkpoints, and independent navigation state are not
used. Lens Sandbox and local Qwen were neither integrated nor executed.
