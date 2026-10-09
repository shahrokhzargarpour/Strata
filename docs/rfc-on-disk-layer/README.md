# On-disk conversation-cache layer — RFC / reference drop

> ## DRAFT / RFC — not for merge.
>
> Nothing on this branch is meant to be merged as it stands. It is published so
> the code, the plans and the reasoning behind them are findable, and to raise
> a hand on the direction. If you landed here from a diff view, read
> [Why the diff looks wrong](#why-the-diff-looks-wrong-read-the-commits-not-the-diff)
> first.

---

## What this branch is

An additive **on-disk tier for the conversation cache** built on top of Strata:
parked conversation state goes to disk instead of being destroyed, and the
serving path can reuse it. Everything the layer does is behind flags that are
**off by default** — with the layer's flags absent, the binary behaves
identically to its base tag.

### Provenance

| | |
| --- | --- |
| Upstream base | `v0.1.40.1` |
| Layer version | `0.4.0` |
| Reference binary | built on `04985f7` |
| Binary version string | `0.1.40` |
| Source line declared in the build acta | `layer/delta5a (upstream v0.1.40.1 + capa 0.4.0)` |
| Layer base inside the branch | `layer/delta4-d7 @ 59929be` |
| Branch tip this document sits on | `85b9f16` |

`04985f7` is the commit that is actually running in production here. It is
**not** `0.1.39` — the `0.1.40` version string and the `v0.1.40.1` base tag are
both correct and both refer to the same build.

### Range carried

`228f7f6..85b9f16` is 13 commits: **6 of code** and **7 of layer tooling**
(`upstream.lock`, `apply-layer.ps1`, `verify-layer.ps1`, `patches/0001..0014`,
the hand-over note).

The tooling is normally kept out of a delivery series. It is left in here on
purpose: this is a reference drop, not a merge candidate, and the lock +
anchors + verifier are the most reusable part of the whole exercise. No history
was rewritten or squashed to make this branch tidy.

---

## Not compatible with `v0.1.41`

**This branch does not work against `v0.1.41`.** It is pinned to `v0.1.40.1`
and was never re-anchored.

The clean, re-anchored series — tested against `v0.1.41`, verified `clean`
against `fb58e0d` — lives in **PR #1331**. That is the one to read if you want
something to land.

This branch is the **earlier** work. It is published for two reasons:

1. as technical reference for the parts that took the most thinking (the
   archive-instead-of-delete paths, the anchor/verifier tooling, the admission
   queue), and
2. to raise a hand on the **direction** — see
   [01-roadmap.md](01-roadmap.md), especially tramo 3, which is intent and not
   a plan.

---

## Why the diff looks wrong (read the commits, not the diff)

The PR base is at `v0.1.41`. This branch is at `v0.1.40.1`. GitHub will
therefore show every `v0.1.41` change as *deleted* on this side, and the diff
will be dominated by unrelated churn.

**The diff is not the artifact here.** Read the commits in order instead:

| Commit | What it is |
| --- | --- |
| `d96ff79` | delta4-d7 — the continuous agenda: fine admission chunk, decode-first token budget, fine STOP, aging. Opt-in. |
| `af9f86f` | delta4-d7 fase 2 — server-side admission queue: release the control lines while waiting for a slot, FIFO + aging, per-state `BADM`. Opt-in. |
| `59929be` | delta4-d7 — fix the crossed responses: demux the control stream by prompt length and slot, keep each request's own figures. Opt-in. |
| `04985f7` | **delta 5a** — archive (not delete) the parking copy in the three paths that discard it. Opt-in. |
| `6090b37` | delta 5a — a red test that reproduces the cross-session parking discard. |
| `85b9f16` | delta 5a — keep the compaction discard inside one conversation (the ownership-guard fix). |

`git log --oneline 228f7f6..85b9f16` and `git show <sha>` are the intended
reading order.

---

## Index

### This folder

| Document | What it is |
| --- | --- |
| [`README.md`](README.md) | This file — status banner, provenance, index. |
| [`01-roadmap.md`](01-roadmap.md) | The three-tramo roadmap. Tramos 1–2 in progress, tramo 3 is intent with no approved plan. |

### [`context/`](context/) — sanitized internal working documents

Verbatim copies of internal working documents from the project that built this
layer. They are in Spanish (that project's working language), they carry **no
authority over this repository**, and local absolute paths were replaced with
`<local-path>` before publishing. Each file opens with its own provenance
header.

| Document | Notes |
| --- | --- |
| [`2026-10-07-plan-delta5a-archivo-de-parking-v1.0.0.md`](context/2026-10-07-plan-delta5a-archivo-de-parking-v1.0.0.md) | The plan behind the archive-instead-of-delete work (`04985f7`). |
| [`2026-10-08-plan-t2-delta5a-fix-y-paraguas-v1.0.0.md`](context/2026-10-08-plan-t2-delta5a-fix-y-paraguas-v1.0.0.md) | The ownership-guard fix plus the umbrella-flag design (tramo 2). |
| [`2026-10-08-plan-port-capa-a-0.1.40.3-v1.0.0.md`](context/2026-10-08-plan-port-capa-a-0.1.40.3-v1.0.0.md) | **OUT OF DATE.** A port plan targeting `v0.1.40.3`, superseded by the `v0.1.41` re-anchor that became PR #1331. Published as-is, including the parts later proved wrong, so the trail is visible. Do not follow it as instructions. |
| [`2026-10-07-plan-delta5a-curacion-bp-y-reevaluacion-v1.2.0.md`](context/2026-10-07-plan-delta5a-curacion-bp-y-reevaluacion-v1.2.0.md) | Which practices applied to delta 5a, which were re-evaluated, and why. |
| [`2026-10-01-hallazgos-bps-descomposicion-y-origen-axiomatico-v1.0.0.md`](context/2026-10-01-hallazgos-bps-descomposicion-y-origen-axiomatico-v1.0.0.md) | How the producing project decomposes a task and where its method comes from. Context for the shape of the other documents. |
| [`2026-10-09-t1-onda-e-evidencia-viva-v1.0.0.md`](context/2026-10-09-t1-onda-e-evidencia-viva-v1.0.0.md) | The live-serving evidence behind PR #1331. |

### [`bps/`](bps/) — internal best practices of the producing project

These are **internal best practices of the project that produced the layer, not
of this repository.** They are included because they explain *why* the layer is
shaped the way it is. Where they conflict with this repo's own conventions,
this repo's conventions win. Same sanitization as above.

| Document | Topic |
| --- | --- |
| [`966-gate-de-versionado-pre-push`](bps/966-gate-de-versionado-pre-push.md) | Versioning gate: a verified return point before touching a versioned system, a new versioned commit after. |
| [`967-mantenimiento-de-servers-llm-locales`](bps/967-mantenimiento-de-servers-llm-locales.md) | Operating local LLM servers: watchdog + lazy start + monitoring, config as a versioned configuration item. |
| [`978-fork-vs-upstream-capa-aditiva`](bps/978-fork-vs-upstream-capa-aditiva.md) | Keeping an additive local layer over a third party's releases: pinned base in a lock, pattern anchors, a verifier that fails loudly, scripted re-application. |
| [`979-entrega-de-un-aporte-a-terceros`](bps/979-entrega-de-un-aporte-a-terceros.md) | Delivering a contribution to a third party: explicit status, non-assertions, decisions left to the maintainer. |
| [`980-entrega-de-serie-merge-clean`](bps/980-entrega-de-serie-merge-clean.md) | Making "merges clean" a property you build and check mechanically: contiguous series on a pinned tag, tree parity by hash, frozen delivery point, verify before opening the PR. |

---

## Non-assertions

To keep this honest, what this branch does **not** claim:

- It does not claim to build, or to be compatible with, `v0.1.41`.
- It does not claim that anything here was exercised end-to-end on `v0.1.41`.
  The live-serving evidence in `context/` belongs to the `v0.1.41` series in
  PR #1331, not to this branch.
- It does not claim that the `v0.1.40.1`-pinned tooling (`upstream.lock`,
  anchors, verifier) still matches `v0.1.41`. It does not — that re-anchor is
  exactly what PR #1331 is.
- Tramo 3 in the roadmap is **intent**, written to invite input. There is no
  approved design behind it.
- The internal documents in `context/` are working documents. Some of them are
  stale, and the stale one is labelled as such above rather than quietly
  dropped.
