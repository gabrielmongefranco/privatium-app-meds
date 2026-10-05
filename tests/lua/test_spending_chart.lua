-- This file is part of Prescription Tracker
-- tests/lua/test_spending_chart.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Unit tests for apps/meds/lib/spending_chart.lua.
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

local spending_chart = require 'spending_chart'

return function(equal)
  local function money(amount) return '$' .. amount end
  local function years(list)
    local rows = {}
    for _, pair in ipairs(list) do rows[#rows + 1] = { year = pair[1], amount_paid = pair[2] } end
    return rows
  end

  equal('no year draws no chart', spending_chart.layout({}, '2026', money), nil)

  local only_now = spending_chart.layout(years({ { '2026', '12.50' } }), '2026', money)
  equal('the year so far is marked', only_now.bars[1].year_label, '2026 so far')
  equal('the year so far is drawn apart', only_now.bars[1].is_partial, true)
  equal('one year has no average', only_now.average, nil)
  equal('one year says what the average needs', only_now.description,
    'Total paid in 2026. 2026 is the year so far. The average needs at least 2 full years of fills.')

  local chart = spending_chart.layout(years({ { '2023', '1000.00' }, { '2024', '1200.50' },
    { '2025', '1400' }, { '2026', '300.10' } }), '2026', money)
  equal('the average leaves out the year so far', chart.average.label, '$1200.17')
  equal('a bar shows its amount', chart.bars[2].value_label, '$1200.50')
  equal('a full year is not marked', chart.bars[3].year_label, '2025')
  equal('the scale tops at a round number', chart.ticks[#chart.ticks].label, '$2000')
  equal('the scale starts at zero', chart.ticks[1].label, '$0')
  equal('the words say what the chart shows', chart.description,
    'Total paid each year from 2023 to 2026. 2026 is the year so far. '
    .. 'The average of the full years is $1200.17.')

  local full = spending_chart.layout(years({ { '2024', '5.00' }, { '2025', '5.50' } }), '2026', money)
  equal('full years only have no year so far', full.has_partial, false)
  equal('an average rounds half a cent up', full.average.label, '$5.25')
  equal('a small total gets a scale of a few dollars', full.ticks[#full.ticks].label, '$8')

  local missing = spending_chart.layout(years({ { '2024', nil }, { '2025', '10' } }), '2026', money)
  equal('a year with no amount says so', missing.bars[1].value_label, 'Not given')
  equal('a year with no amount has no bar', missing.bars[1].height, '0.0')
  equal('a year with no amount is not averaged', missing.average, nil)
end
