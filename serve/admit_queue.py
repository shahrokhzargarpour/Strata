"""serve/admit_queue.py - Delta 4 / node D4-7, phase 2: the server-side admission queue.

Two things live here, both pure (no threads, no engine, no clock of their own - the caller passes
the time):

1. `AdmissionQueue` - the FIFO waiters for the engine's control lines (`StrataEngine.ctl`), with
   AGING so a request that has waited long enough goes ahead of a stream of newcomers.  Today the
   control lines are a bare lock and the waiters are a plain list (server.py's `waiting`/`wait_lens`);
   the order they are taken in is whatever the OS gives the threads, and a request that had to wait
   for a free slot holds the lock while it waits, so everyone queues behind it.  This queue makes the
   order explicit: FIFO by arrival, and once the head of the queue has waited `age_s` seconds it is
   promoted past the `after_epoch` gate that would otherwise keep deferring it.

   The reference is our own MIT patch to llama.cpp, `--prefill-mixed-batch` (STUDIOZ/patches/0002):
   there the fairness lives in a round-robin cursor over the prompt slots; here there is ONE
   admission at a time, so the same idea becomes "FIFO + aging on the lock".  No vLLM code is copied
   (its scheduler is Python under Apache-2.0; we take only the running-before-waiting contract, which
   is an idea, and the `AdmissionQueue` is our own structure).

2. The four admission STATES of a request and the pure parser of the engine's per-state `BADM` line
   (`BADM <slot> <state> <read_to> <total>`), which only an engine started with `STRATA_BATCH_AGENDA`
   emits.  The terminal admission line stays `BADM <slot> <0|1>` (numeric), so a server with the
   switch off sees exactly the base tag's protocol and the parser returns None for it.
"""

from __future__ import annotations

# The admission state machine (mirror of include/strata/core/agenda.hpp's AdmState).
WAIT_SLOT = "wait_slot"   # waiting for the control lines and/or a free slot
READING = "reading"       # the engine is reading the prompt (one fine chunk per turn)
READY = "ready"           # the prompt is read; the first token is being produced
ACTIVE = "active"         # the slot owns the session (decoding)
STATES = (WAIT_SLOT, READING, READY, ACTIVE)


def parse_progress(line: str):
    """The engine's per-state admission line -> `(slot, state, read_to, total)`, or None.

    `BADM 2 reading 512 3000` is progress (STRATA_BATCH_AGENDA).  `BADM 2 1` is the terminal admission
    line (numeric second field) and returns None, as does anything else - so a reader that only knows
    the base tag's protocol is never confused by a state word where it expects 0/1."""
    f = line.split()
    if len(f) < 5 or f[0] != "BADM" or f[2] not in STATES:
        return None
    if not (f[1].lstrip("-").isdigit() and f[3].isdigit() and f[4].isdigit()):
        return None
    return int(f[1]), f[2], int(f[3]), int(f[4])


class AdmissionQueue:
    """FIFO waiters for the control lines, with aging.

    A waiter is the mutable list `[plen, t0]` the engine already keeps in `wait_lens` (`plen` first,
    so the #656 "a long read gives way to a shorter one" test - `e[0] * 2 <= plen` - keeps working).
    The queue preserves arrival order and hands out the turn fairly.
    """

    def __init__(self) -> None:
        self._q: list[list] = []

    def join(self, plen: int, t0: float) -> list:
        """Register a waiter (its prompt length and the monotonic time it started waiting)."""
        w = [int(plen), float(t0)]
        self._q.append(w)
        return w

    def leave(self, waiter: list) -> None:
        try:
            self._q.remove(waiter)
        except ValueError:
            pass

    def __len__(self) -> int:
        return len(self._q)

    def lens(self) -> list[list]:
        """The waiters in arrival order, as `[[plen, t0], ...]` (the server's `wait_lens` view)."""
        return self._q

    def head(self) -> list | None:
        return self._q[0] if self._q else None

    def is_head_and_aged(self, waiter: list, now: float, age_s: float) -> bool:
        """Aging: `waiter` is the oldest one and has waited at least `age_s` seconds.

        `age_s <= 0` disables the promotion (the switch off): then only the existing epoch rule makes
        the decision, exactly as before."""
        if age_s <= 0 or not self._q or self._q[0] is not waiter:
            return False
        return (now - waiter[1]) >= age_s

    def oldest_age(self, now: float) -> float:
        """Seconds the oldest waiter has waited (0.0 when the queue is empty)."""
        return (now - self._q[0][1]) if self._q else 0.0


def aged_turn(waiter: list, wait_lens: list, now: float, age_s: float) -> bool:
    """The turn rule as a pure function of the engine's `wait_lens` list: `waiter` goes when it is the
    oldest and its wait reaches `age_s`.  Used where a queue instance is not at hand."""
    if age_s <= 0 or not wait_lens or wait_lens[0] is not waiter:
        return False
    return (now - waiter[1]) >= age_s
