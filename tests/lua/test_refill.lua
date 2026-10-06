-- This file is part of Medication Tracker
-- tests/lua/test_refill.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Unit tests for apps/meds/lib/refill.lua.
-- Notes: See README file for documentation and full license information.
--
-- Copyright © 2026 Gabriel Mongefranco
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program. If not, see <https://www.gnu.org/licenses/>.

local refill = require 'refill'

return function(equal)
  --- group ---
  equal('taken regularly and overdue', refill.group('taking_regularly', 'overdue', 0), 'overdue')
  equal('taken regularly and due', refill.group('taking_regularly', 'due', 0), 'due')
  equal('taken regularly and due soon', refill.group('taking_regularly', 'due_soon', 0), 'due_soon')
  equal('taken regularly and not due', refill.group('taking_regularly', 'not_due', 0), 'not_due')
  equal('taken regularly with no fill', refill.group('taking_regularly', 'no_fill', 0), 'missing')
  equal('taken regularly with no days supply', refill.group('taking_regularly', 'due', 1), 'missing')
  equal('taken as needed raises no alert', refill.group('taking_as_needed', 'overdue', 0), 'as_needed')
  equal('on hold raises no alert', refill.group('on_hold', 'overdue', 0), 'paused')
  equal('not started raises no alert', refill.group('not_started', 'no_fill', 0), 'paused')
  equal('no longer taken has no group', refill.group('not_taking', 'overdue', 0), nil)

  local keys = {}
  for _, group in ipairs(refill.GROUPS) do keys[group.key] = group end
  equal('every group a medication can land in exists',
    keys.overdue and keys.due and keys.due_soon and keys.as_needed and keys.missing
      and keys.not_due and keys.paused and true, true)
  equal('only the three dated groups raise an alert',
    (keys.overdue.alert and keys.due.alert and keys.due_soon.alert)
      and not (keys.as_needed.alert or keys.missing.alert or keys.not_due.alert or keys.paused.alert), true)

  --- phrase ---
  equal('one day late', refill.phrase('overdue', -8, -1), 'Overdue by 1 day')
  equal('four days late', refill.phrase('overdue', -11, -4), 'Overdue by 4 days')
  equal('today', refill.phrase('due', 0, 7), 'Due today')
  equal('tomorrow', refill.phrase('due', 1, 8), 'Due tomorrow')
  equal('in three days', refill.phrase('due', 3, 10), 'Due in 3 days')
  equal('no fill', refill.phrase('no_fill', nil), 'No fill recorded')

  equal('eligible with supply left', refill.phrase('due', -3, 4), 'Fill now. Runs out in 4 days')
  equal('one day of supply left', refill.phrase('due', -6, 1), 'Fill now. Runs out in 1 day')
  equal('runs out today', refill.phrase('due', -7, 0), 'Fill now. Runs out today')
  equal('missing physical supply', refill.phrase('due', 2, nil), 'No fill recorded')

  --- Asking for a new prescription ---
  equal('taken regularly, none left, due', refill.ask_for_more('taking_regularly', 0, 'due'), true)
  equal('taken regularly, none left, due soon', refill.ask_for_more('taking_regularly', 0, 'due_soon'), true)
  equal('taken regularly, none left, overdue', refill.ask_for_more('taking_regularly', 0, 'overdue'), true)
  equal('taken as needed, none left, due', refill.ask_for_more('taking_as_needed', 0, 'due'), true)
  equal('none left, and not due yet', refill.ask_for_more('taking_regularly', 0, 'not_due'), false)
  equal('none left, and no fill', refill.ask_for_more('taking_regularly', 0, 'no_fill'), false)
  equal('one left', refill.ask_for_more('taking_regularly', 1, 'due'), false)
  equal('on hold', refill.ask_for_more('on_hold', 0, 'due'), false)
  equal('no longer taken', refill.ask_for_more('not_taking', 0, 'overdue'), false)

  --- The status after a fill ---
  local today = '2026-10-05'
  equal('a stopped medication with a fill in use is taken again',
    refill.status_after_fill('not_taking', '2026-09-20', 30, today), 'taking_regularly')
  equal('a medication not started with a fill in use is taken',
    refill.status_after_fill('not_started', '2026-10-05', 1, today), 'taking_regularly')
  equal('a supply that ends today still counts',
    refill.status_after_fill('not_taking', '2026-09-05', 30, today), 'taking_regularly')
  equal('a supply that ended yesterday leaves it stopped',
    refill.status_after_fill('not_taking', '2026-09-04', 30, today), 'not_taking')
  equal('an old fill leaves it not started',
    refill.status_after_fill('not_started', '2025-01-10', 90, today), 'not_started')
  equal('no days supply counts as thirty days',
    refill.status_after_fill('not_taking', '2026-09-05', nil, today), 'taking_regularly')
  equal('no days supply, thirty-one days ago',
    refill.status_after_fill('not_taking', '2026-09-04', nil, today), 'not_taking')
  equal('a supply across the end of the year',
    refill.status_after_fill('not_taking', '2025-12-20', 30, '2026-01-19'), 'taking_regularly')
  equal('taken as needed stays as needed',
    refill.status_after_fill('taking_as_needed', '2026-10-01', 30, today), 'taking_as_needed')
  equal('on hold stays on hold',
    refill.status_after_fill('on_hold', '2026-10-01', 30, today), 'on_hold')
  equal('taken regularly stays so',
    refill.status_after_fill('taking_regularly', '2020-01-01', 30, today), 'taking_regularly')
end
