-- This file is part of Prescription Tracker
-- tests/lua/test_choices.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Unit tests for apps/meds/lib/choices.lua.
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

local choices = require 'choices'

return function(equal)
  local merged = choices.merge({ 'Oral', 'Eye' }, { 'oral', 'Sublingual', 'Buccal', 'EYE', '' })
  equal('starter choices come first, in their order', merged[1] .. ',' .. merged[2], 'Oral,Eye')
  equal('a value that differs only by case is not repeated', #merged, 4)
  equal('new values follow, sorted', merged[3] .. ',' .. merged[4], 'Buccal,Sublingual')

  equal('an empty starter list keeps the values in use', #choices.merge({}, { 'Oral' }), 1)
  equal('no values in use keeps the starter list', #choices.merge(choices.ROUTES, {}), #choices.ROUTES)

  local seen, repeats = {}, 0
  for _, list in ipairs({ choices.ROUTES, choices.FORMS, choices.PACKAGE_TYPES }) do
    seen = {}
    for _, choice in ipairs(list) do
      if seen[choice] then repeats = repeats + 1 end
      seen[choice] = true
    end
  end
  equal('no starter list repeats a choice', repeats, 0)
end
