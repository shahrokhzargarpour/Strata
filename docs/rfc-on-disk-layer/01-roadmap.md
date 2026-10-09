# Roadmap — on-disk conversation-cache layer

Three tramos. **Tramos 1 and 2 are in progress. Tramo 3 is intent, not a plan.**

| Tramo | Scope | Status |
| --- | --- | --- |
| [1](#tramo-1--the-layer-on-the-latest-version) | The layer, re-anchored onto the latest upstream version | 🟡 in progress — submitted as PR #1331 |
| [2](#tramo-2--delta-5a-ownership-guard-umbrella-flag-large-pages) | Archive-instead-of-delete, the ownership-guard fix, an umbrella flag, large-page docs | 🟡 in progress — this branch |
| [3](#tramo-3--roadmap-no-approved-plan) | Multi-GPU, real async continuous batching, continuous expert cache, pipeline parallelism | ⚪ **intent — no design plan yet** |

Marked 🟡 deliberately: per the producing project's convention, 🟡 means "in
progress / not yet verified end-to-end" and is meant to read as unfinished.

---

## Tramo 1 — the layer on the latest version

**Status: 🟡 in progress — submitted.**

The on-disk layer, clean and tested against the current upstream version.

- Submitted as **PR #1331**.
- Verified **`clean` against `fb58e0d`** — the series applies without conflicts
  at that point, checked mechanically rather than assumed from "no conflicts
  shown".
- That PR is the delivery series: contiguous commits, no emitter tooling mixed
  in, everything inert behind off-by-default flags.

If you want something to merge, merge from PR #1331. This branch exists because
PR #1331 does not show the earlier work or the reasoning.

---

## Tramo 2 — delta 5a: ownership guard, umbrella flag, large pages

**Status: 🟡 in progress.** Four pieces, at different stages.

### 2.1 Archive instead of delete the parked copy — `04985f7`, done on this branch

Three paths discard the parked on-disk copy today and destroy state in the
process: the compaction path (`discard_diverged`), the supersede pass
(`drop_superseded`), and the provisional park of a cancelled request.

With `--conversation-cache-archive-mode ids|state` the copy is **moved** into
the archive instead of removed. `off` (the default) is byte-for-byte the
previous behaviour. The archive has its own budget
(`--conversation-cache-archive-mib`), its own GC (`--conversation-cache-archive-keep`,
then the budget, plus optional `--conversation-cache-archive-max-age-days`),
and is never a reuse candidate. A copy larger than the whole budget is not
archived, and a failed move leaves the tier entry intact.

Related flags on this branch: `--conversation-cache-archive-dir`,
`--conversation-cache-archive-keep`, `--conversation-cache-archive-max-age-days`,
`--conversation-cache-archive-mib`, `--conversation-cache-archive-mode`.

### 2.2 The ownership-guard correction — `6090b37` + `85b9f16`, done on this branch

Archiving exposed a second defect: the compaction discard was not confined to
one conversation, so a conversation could discard another conversation's
parking copy.

- `6090b37` is a **red test that reproduces the cross-session parking discard**.
- `85b9f16` keeps the compaction discard inside one conversation.

The red test landed before the fix on purpose.

### 2.3 The umbrella flag — designed, not implemented

One percentage of the on-disk parking pool, expressed as a single flag:

- The percentage is the share of the parking pool reserved for the **system
  prompt**.
- **Turning it on** switches on the defaults `--conversation-cache-spill-on park`
  plus system-prompt caching.
- **Turning it off** switches everything off.
- **The granular flags still configure separately** — each fine flag keeps its
  own meaning and overrides the derived value.
- Derived values, over the existing pool flag `--conversation-cache-disk-mib`:
  `--system-prompt-cache-mib` = P% of the pool,
  `--conversation-cache-archive-mib` = the remainder, and the VRAM tier's own
  `--conversation-cache-mib` = pool − sysprompt% − archive.
- Invariant that must hold in every state (on / off / partial override / full
  override / conflicting override): **no state over-allocates the pool**, and
  "flag absent behaves exactly as today" is testable.

The point is a single knob a person can actually reason about, without removing
the fine control for anyone who wants it.

### 2.4 Documenting large-page elevation — not written

On Windows, `MEM_LARGE_PAGES` needs `SeLockMemoryPrivilege`, and **having the
privilege assigned to the account is not enough** — the process must enable it
in its own token (`AdjustTokenPrivileges`) before `VirtualAlloc`, and a
non-elevated token cannot. See the comment block in
`sycl/src/core/pinned.dp.cpp`, and note that `STRATA_NO_LARGEPAGES=1` is the A/B
switch that skips the attempt on the same run and boot.

The failure is silent and the fallback is correct, which is exactly why it goes
undocumented: on a desktop, 4 KB pages are the *expected* outcome, not an error.
`docs/DETAILS.md` already records the adjacent operational finding — a Task
Scheduler job "run with highest privileges" off means a limited user token,
which strips `SeLockMemoryPrivilege`, and measured model load goes from ~35 s
to ~820–840 s.

What is missing is a document that states the elevation requirement, how to
check whether large pages were actually granted, and what the fallback costs.

---

## Tramo 3 — roadmap, no approved plan

> **No design plan yet — this is intent, written to invite input.**
>
> Nothing below has an approved design, an agreed API, a flag name, or a
> commitment. It is here because the direction is worth arguing about and
> because someone reading this branch may already know better than we do.
> Treat every line as a question.

The on-disk tier is a step toward a serving stack that stops treating memory as
a hard wall. The four directions:

### Multi-GPU, N of them

Not "a second GPU as an overflow target" but a real N-device story: placement,
what a device-identities cache means once state can live on disk per device,
and what breaks when a device disappears mid-session.

### Real asynchronous continuous batching

Continuous batching that is actually asynchronous — admission and decode not
serialized behind each other, control lines not held while a request waits for
a slot.

### Continuous expert cache

A cache of experts with two knobs: **x GB of VRAM** and **w experts** resident,
continuously maintained rather than recomputed per step. The open question is
what the eviction policy should be when the on-disk tier is underneath it.

### Pipeline parallelism

Splitting a forward pass across devices by layer range, and what that costs once
the conversation state is partly on disk.

### Related code already on this branch

This is not a blank page. Three delta4-d7 commits on this branch are already
pointed at the continuous-batching problem, and all three are opt-in:

| Commit | What it already does |
| --- | --- |
| `d96ff79` | The **continuous agenda**: fine admission chunk, a decode-first token budget, fine STOP, aging. |
| `af9f86f` | The **server-side admission queue**: release the control lines while waiting for a slot, FIFO + aging, per-state `BADM`. |
| `59929be` | Fixes the **crossed responses** those paths exposed: demuxes the control stream by prompt length and slot, and keeps each request's own figures. |

Plus `--batch-mtp` (see `docs/BATCHING.md`, `docs/FLAGS.md`), the opt-in
batched-MTP path, which is the current shape of speculative decoding under
batching and the thing a real async scheduler has to coexist with.

Whoever wants to argue about tramo 3 should start from those four, not from
this document.

---

## How to respond to this RFC

The useful responses are the negative and the corrective ones:

- "Tramo 3 direction X is wrong because the codebase already does Y."
- "Your umbrella flag conflicts with a flag you did not look at."
- "The archive-instead-of-delete design breaks under Z."
- "The ownership guard belongs at a different layer."

See [`README.md`](README.md) for provenance and for what this branch does not
claim.
