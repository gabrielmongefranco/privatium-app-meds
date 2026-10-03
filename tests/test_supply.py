#!/usr/bin/env python3
# This file is part of Prescription Tracker
# tests/test_supply.py
# Author(s): Gabriel Mongefranco
# Created: 2026-10-01
# Last Modified: 2026-10-03
# Summary: Synthetic SQLite checks of supply, payer rules, and row grain.
# Notes: See README file for documentation and full license information.
#
# Copyright © 2026 Gabriel Mongefranco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

import datetime as dt
import pathlib
import random
import sqlite3
import unittest

SCHEMA = pathlib.Path(__file__).resolve().parents[1] / 'apps/meds/schema.sql'
DAY = dt.timedelta(days=1)


def stack(fills):
    """Carry supply forward without crediting gaps; return its exhaustion date."""
    end = None
    for date, days, _ in fills:
        end = max(date, end or date) + DAY * (1 if days is None else days)
    return end


class SupplyTests(unittest.TestCase):
    """Check the shipped views in memory with invented records and no network access."""

    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.row_factory = sqlite3.Row
        self.db.create_function('decimal_cmp', 2, lambda one, two: 0)
        self.db.executescript(SCHEMA.read_text())
        self.db.execute("INSERT INTO person(id, display_name) VALUES ('person', 'Example Person')")
        self.db.execute("INSERT INTO medication(id, short_name, generic_name, is_specialty) "
                        "VALUES ('med', 'Example Drug', 'Example Ingredient', 0)")
        self.db.execute("INSERT INTO person_medication(id, person_id, display_name, status, refills_left) "
                        "VALUES ('entry', 'person', 'Example Drug', 'taking_regularly', 1)")
        self.db.execute("INSERT INTO person_medication_product(id, person_medication_id, medication_id) "
                        "VALUES ('link', 'entry', 'med')")

    def tearDown(self):
        self.db.close()

    def result(self, fills, percent=25, frame=180, controlled=False, early=0):
        """Return one supply row for a synthetic history and check each view's grain."""
        self.db.execute('DELETE FROM fill')
        self.db.execute('DELETE FROM plan')
        self.db.execute('DELETE FROM profile')
        self.db.execute("UPDATE medication SET is_controlled = ? WHERE id = 'med'", (controlled,))
        self.db.execute("INSERT INTO profile(id, early_fill_percent, supply_frame_days, controlled_early_days) "
                        "VALUES ('settings', ?, ?, ?)", (percent, frame, early))
        self.db.execute("INSERT INTO plan(id, name) VALUES ('A', 'Example Plan A')")
        self.db.execute("INSERT INTO plan(id, name) VALUES ('B', 'Example Plan B')")
        self.db.executemany("INSERT INTO fill(id, person_medication_id, medication_id, pharmacy_id, filled_on, "
                            "days_supply, plan_id) VALUES (?, 'entry', 'med', 'pharmacy', ?, ?, ?)",
                            [(str(i).zfill(6), date.isoformat(), days, payer)
                             for i, (date, days, payer) in enumerate(fills)])
        self.assertEqual(self.db.execute('SELECT count(*) FROM v_fill_order').fetchone()[0], len(fills))
        self.assertEqual(self.db.execute('SELECT count(*) FROM v_supply_fill').fetchone()[0], len(fills))
        self.assertEqual(self.db.execute('SELECT count(*) FROM v_supply').fetchone()[0], 1)
        self.assertEqual(self.db.execute('SELECT count(*) FROM v_active_medication').fetchone()[0], 1)
        return self.db.execute('SELECT next_fill_on, lasts_until, allowance FROM v_supply').fetchone()

    def test_worked_examples(self):
        fills = [(dt.date.fromisoformat(date), days, 'A') for date, days in
                 [('2026-07-01', 30), ('2026-07-28', 30), ('2026-08-25', 30), ('2026-08-25', 90)]]
        self.assertEqual(tuple(self.result(fills)), ('2026-12-06', '2026-12-28', 22))
        fills = [(dt.date.fromisoformat(date), 30, 'A') for date in
                 ['2026-01-01', '2026-02-10', '2026-03-05']]
        self.assertEqual(tuple(self.result(fills)), ('2026-04-04', '2026-04-11', 7))

    def test_empty_zero_and_missing_supply(self):
        self.assertEqual(tuple(self.result([])), (None, None, None))
        date = dt.date(2026, 1, 1)
        self.assertEqual(tuple(self.result([(date, None, None)])), ('2026-01-02', '2026-01-02', 0))
        self.assertEqual(tuple(self.result([(date, 0, None)])), ('2026-01-01', '2026-01-01', 0))

    def test_frame_sentinels_and_cash(self):
        date = dt.date(2026, 1, 1)
        fills = [(date, 30, 'A'), (date, 30, 'A')]
        self.assertEqual(tuple(self.result(fills, frame=0)), ('2026-01-24', '2026-03-02', 7))
        self.assertEqual(tuple(self.result(fills, frame=3650)), ('2026-02-23', '2026-03-02', 7))
        fills = [(date, 30, 'A'), (date + DAY * 20, 30, 'B')]
        self.assertEqual(tuple(self.result(fills, percent=0)), ('2026-03-02', '2026-03-02', 0))
        fills = [(date - DAY * 4000, 5000, 'A'), (date, 30, 'B')]
        self.assertEqual(tuple(self.result(fills, controlled=True)), ('2028-10-27', '2028-10-27', 0))

    def test_status_boundaries(self):
        today = dt.date.fromisoformat(self.db.execute("SELECT date('now', 'localtime')").fetchone()[0])
        cases = [(33, 'overdue', -10, -3), (30, 'due', -7, 0),
                 (26, 'due', -3, 4), (21, 'due', 2, 9), (18, 'due_soon', 5, 12), (10, 'not_due', 13, 20)]
        for ago, status, next_days, supply_days in cases:
            self.result([(today - DAY * ago, 30, 'A')])
            row = self.db.execute('SELECT refill_status, days_until_next_fill, days_until_runs_out '
                                  'FROM v_active_medication').fetchone()
            self.assertEqual(tuple(row), (status, next_days, supply_days))
        self.db.execute("UPDATE medication SET is_specialty = 1 WHERE id = 'med'")
        self.result([(today - DAY * 16, 28, 'A')])
        self.assertEqual(self.db.execute('SELECT refill_status FROM v_active_medication').fetchone()[0], 'due')

    def test_payer_overrides_and_intervening_cash(self):
        date = dt.date(2026, 1, 1)
        fills = [(date, 30, 'A'), (date + DAY * 10, 30, 'B'), (date + DAY * 20, 30, 'A')]
        self.assertEqual(tuple(self.result(fills)), ('2026-02-23', '2026-04-01', 7))
        self.db.execute("UPDATE plan SET early_fill_percent = 50 WHERE id = 'A'")
        self.assertEqual(tuple(self.db.execute('SELECT next_fill_on, lasts_until, allowance FROM v_supply').fetchone()),
                         ('2026-02-15', '2026-04-01', 15))
        self.db.execute("UPDATE plan SET supply_frame_days = 0 WHERE id = 'A'")
        self.assertEqual(self.db.execute('SELECT next_fill_on FROM v_supply').fetchone()[0], '2026-02-05')
        fills[1] = (date + DAY * 10, 30, None)
        self.assertEqual(tuple(self.result(fills)), ('2026-03-25', '2026-04-01', 7))
        self.result(fills, controlled=True, early=2)
        self.db.execute("UPDATE plan SET early_fill_percent = 100, supply_frame_days = 0 WHERE id = 'A'")
        self.assertEqual(tuple(self.db.execute('SELECT next_fill_on, lasts_until, allowance FROM v_supply').fetchone()),
                         ('2026-03-30', '2026-04-01', 2))

    def test_constraints_reject_invalid_rules(self):
        for column, values in [('early_fill_percent', [-1, 101]), ('supply_frame_days', [-1, 3651])]:
            for value in values:
                with self.assertRaises(sqlite3.IntegrityError):
                    self.db.execute(f"INSERT INTO plan(id, name, {column}) VALUES ('bad', 'Example', ?)", (value,))

    def test_random_histories_against_daily_simulation(self):
        rng = random.Random(20261001)
        for _ in range(3000):
            date = dt.date(2025, 1, 1)
            fills = []
            for _ in range(rng.randint(1, 12)):
                date += DAY * rng.randint(0, 100)
                fills.append((date, rng.choice([None, 0, 1, 28, 30, 90]), rng.choice(['A', 'B', None])))
            percent, frame = rng.choice([0, 25, 30, 50, 100]), rng.choice([0, 30, 180, 3650])
            controlled, early = rng.choice([False, True]), rng.choice([0, 2, 30])
            last_date, last_days, payer = fills[-1]
            allowance = early if controlled else (1 if last_days is None else last_days) * percent // 100
            physical_end = stack(fills)
            if not controlled and percent == 0:
                eligible = physical_end
            else:
                counted = [fill for fill in fills if controlled or payer is None
                           or fill[2] is None or fill[2] == payer]
                eligible = last_date - DAY * (early if controlled else 0)
                while True:
                    window = counted if controlled or frame == 3650 else (
                        [fills[-1]] if frame == 0 else
                        [fill for fill in counted if fill[0] >= eligible - DAY * frame])
                    end = stack(window)
                    if end is None or end - DAY * allowance <= eligible:
                        break
                    eligible += DAY
            row = self.result(fills, percent, frame, controlled, early)
            self.assertEqual(tuple(row), (eligible.isoformat(), physical_end.isoformat(), allowance),
                             (fills, percent, frame, controlled, early))


if __name__ == '__main__':
    unittest.main()
