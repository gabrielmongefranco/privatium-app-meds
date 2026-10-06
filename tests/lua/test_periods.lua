-- This file is part of Medication Tracker
-- tests/lua/test_periods.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Unit tests for apps/meds/lib/periods.lua.
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

local periods = require 'periods'

return function(equal)
  local function range(code, today)
    local from, to = periods.range(code, today)
    return tostring(from) .. ' ' .. tostring(to)
  end
  -- 2026-10-05 is a Monday, 2026-10-04 a Sunday and 2026-10-03 a Saturday.
  equal('this week starts on Sunday', range('this-week', '2026-10-05'), '2026-10-04 2026-10-05')
  equal('on a Sunday this week is one day', range('this-week', '2026-10-04'), '2026-10-04 2026-10-04')
  equal('on a Saturday this week began last Sunday', range('this-week', '2026-10-03'), '2026-09-27 2026-10-03')
  equal('last week runs Sunday to Saturday', range('last-week', '2026-10-05'), '2026-09-27 2026-10-03')
  equal('last week may start in the month before', range('last-week', '2026-10-01'), '2026-09-20 2026-09-26')
  equal('this month starts on the first', range('this-month', '2026-10-05'), '2026-10-01 2026-10-05')
  equal('last month in January is December', range('last-month', '2026-01-15'), '2025-12-01 2025-12-31')
  equal('last month knows a leap February', range('last-month', '2028-03-10'), '2028-02-01 2028-02-29')
  equal('last 90 days counts today', range('last-90-days', '2026-10-05'), '2026-07-08 2026-10-05')
  equal('a year runs January to December', range('2025', '2026-10-05'), '2025-01-01 2025-12-31')
  equal('any time has open ends', range('', '2026-10-05'), ' ')
  equal('an unknown period is refused', range('next-week', '2026-10-05'), 'nil nil')
  equal('a year of five digits is refused', range('20255', '2026-10-05'), 'nil nil')
  equal('a period that is not text is refused', range(nil, '2026-10-05'), 'nil nil')

  local options = periods.options({ '2026', '2025' })
  equal('the moving periods come first', options[1].label, 'This week')
  equal('the order of the moving periods', options[3].label, 'Last week')
  equal('each year follows', options[6].label, 'Year: 2026')
  equal('a year is its own value', options[7].value, '2025')
  equal('every period has a name', periods.label('last-90-days'), 'Last 90 days')
  equal('any time has a name', periods.label(''), 'Any time')
  equal('a year has a name', periods.label('2025'), 'Year: 2025')
end
