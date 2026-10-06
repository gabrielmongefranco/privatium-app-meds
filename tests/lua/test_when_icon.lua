-- This file is part of Medication Tracker
-- tests/lua/test_when_icon.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Tests for when_icon: every time of day of the starter list, the two that
--          households often type, case and punctuation, and a time of their own.
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

local choices   = require 'choices'
local when_icon = require 'when_icon'

return function(equal)
  local function icons(value) return table.concat(when_icon.of(value), ' ') end

  local expected = {
    ['Anytime'] = 'clock', ['Morning'] = 'sunrise', ['Noon'] = 'sun', ['Evening'] = 'sunset',
    ['Night - At Bedtime'] = 'moon-stars', ['Morning and Evening'] = 'sunrise sunset',
    ['Before Meals'] = 'hourglass-top', ['With Meals'] = 'egg-fried',
    ['After Meals'] = 'hourglass-bottom', ['As Needed'] = 'activity',
  }
  for _, time in ipairs(choices.TIMES_TO_TAKE) do
    equal('the starter time ' .. time, icons(time), expected[time])
  end

  equal('night alone', icons('Night'), 'moon')
  equal('morning after breakfast', icons('Morning - After Breakfast'), 'brightness-alt-high')
  equal('case and punctuation do not matter', icons('  night-at  BEDTIME '), 'moon-stars')
  equal('a time of the household has no icon', icons('Every other Tuesday'), '')
  equal('no time has no icon', icons(nil), '')
  equal('an empty time has no icon', icons(''), '')
end
