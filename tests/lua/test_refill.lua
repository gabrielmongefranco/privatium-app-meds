-- This file is part of Prescription Tracker
-- tests/lua/test_refill.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
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
  equal('one day late', refill.phrase('overdue', -1), 'Overdue by 1 day')
  equal('four days late', refill.phrase('overdue', -4), 'Overdue by 4 days')
  equal('today', refill.phrase('due', 0), 'Due today')
  equal('tomorrow', refill.phrase('due', 1), 'Due tomorrow')
  equal('in three days', refill.phrase('due', 3), 'Due in 3 days')
  equal('no fill', refill.phrase('no_fill', nil), 'No fill recorded')
end
