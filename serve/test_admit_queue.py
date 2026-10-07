"""serve/test_admit_queue.py - D4-7 fase 2: the pure admission queue, its FIFO + aging order and the
per-state `BADM` parser.  No engine, no threads, no GPU: the decisions the server relies on, asserted directly.

    python -m pytest serve/test_admit_queue.py -q
    python -m unittest serve.test_admit_queue -v
"""
from __future__ import annotations

import unittest

from serve import admit_queue as aq


class ParseProgress(unittest.TestCase):
    """`BADM <slot> <state> <read_to> <total>` is progress; `BADM <slot> <0|1>` is the terminal line."""

    def test_a_state_line_is_read(self):
        self.assertEqual(aq.parse_progress("BADM 2 reading 512 3000"), (2, "reading", 512, 3000))
        self.assertEqual(aq.parse_progress("BADM 0 wait_slot 0 64"), (0, "wait_slot", 0, 64))
        self.assertEqual(aq.parse_progress("BADM 3 ready 3000 3000"), (3, "ready", 3000, 3000))
        self.assertEqual(aq.parse_progress("BADM 1 active 4096 4096"), (1, "active", 4096, 4096))

    def test_the_terminal_line_is_not_progress(self):
        # the base tag's admission result: a numeric second field, exactly what a reader expects there
        self.assertIsNone(aq.parse_progress("BADM 2 1"))
        self.assertIsNone(aq.parse_progress("BADM 2 0"))

    def test_malformed_lines_are_ignored(self):
        for line in ("BADM 2 reading 5",            # too few fields
                     "BADM x reading 1 2",          # slot not a number
                     "BADM 2 reading x 2",          # read_to not a number
                     "BADM 2 bogus 1 2",            # an unknown state
                     "BADM", ""):
            self.assertIsNone(aq.parse_progress(line), line)

    def test_the_four_states_are_declared(self):
        self.assertEqual(set(aq.STATES), {"wait_slot", "reading", "ready", "active"})


class QueueOrder(unittest.TestCase):
    """FIFO by arrival, with aging on the head; `wait_lens` keeps the `[plen, t0]` shape the engine uses."""

    def test_fifo_order_is_kept(self):
        q = aq.AdmissionQueue()
        w1 = q.join(10, 100.0)
        w2 = q.join(20, 101.0)
        w3 = q.join(30, 102.0)
        self.assertEqual(q.lens(), [[10, 100.0], [20, 101.0], [30, 102.0]])
        self.assertIs(q.head(), w1)
        self.assertEqual(len(q), 3)

    def test_aging_promotes_only_the_aged_head(self):
        q = aq.AdmissionQueue()
        w1 = q.join(10, 100.0)
        w2 = q.join(20, 101.0)
        # the head, after the threshold: promoted
        self.assertTrue(q.is_head_and_aged(w1, 102.5, 2.0))
        self.assertFalse(q.is_head_and_aged(w1, 101.5, 2.0))    # head but not yet aged
        self.assertFalse(q.is_head_and_aged(w2, 105.0, 2.0))    # aged but not the head: never jumps the queue
        self.assertEqual(q.oldest_age(102.5), 2.5)

    def test_aging_off_is_pure_fifo(self):
        q = aq.AdmissionQueue()
        w1 = q.join(10, 100.0)
        self.assertFalse(q.is_head_and_aged(w1, 1000.0, 0.0))   # age_s <= 0: no time-based promotion

    def test_leave_removes_and_reorders(self):
        q = aq.AdmissionQueue()
        w1 = q.join(10, 100.0)
        w2 = q.join(20, 101.0)
        q.leave(w1)
        self.assertEqual(q.lens(), [[20, 101.0]])
        self.assertIs(q.head(), w2)
        q.leave(w1)                                             # leaving twice is a no-op
        self.assertEqual(len(q), 1)
        q.leave(w2)
        self.assertEqual((len(q), q.head(), q.oldest_age(999.0)), (0, None, 0.0))

    def test_aged_turn_is_the_rule_without_a_queue(self):
        # the pure form the engine also uses: only the head, only when aged
        w1, w2 = [10, 100.0], [20, 101.0]
        wait_lens = [w1, w2]
        self.assertTrue(aq.aged_turn(w1, wait_lens, 102.5, 2.0))
        self.assertFalse(aq.aged_turn(w2, wait_lens, 105.0, 2.0))
        self.assertFalse(aq.aged_turn(w1, wait_lens, 102.5, 0.0))


if __name__ == "__main__":
    unittest.main()
