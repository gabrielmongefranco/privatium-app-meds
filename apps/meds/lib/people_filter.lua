-- This file is part of Medication Tracker
-- apps/meds/lib/people_filter.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The person filter that list pages share: the people to choose from, and the one
--          the page address names.
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

local pv = require 'privatium'

local people_filter = {}

--- Read the person filter of a request.
-- @param req table  The request. Its `person` parameter may hold the id of a person.
-- @return table  { people = every person, selected = the chosen person or nil,
--         id = the id to filter by, or '' for everyone }. An id that names nobody
--         counts as everyone.
function people_filter.read(req)
  -- Grain: one row per person.
  local people = pv.query([[
    SELECT id, display_name, birth_date
      FROM person
     ORDER BY display_name COLLATE NOCASE, id]])
  local filter = { people = people, id = '' }
  for _, person in ipairs(people) do
    if person.id == req.query.person then
      filter.selected, filter.id = person, person.id
    end
  end
  return filter
end

return people_filter
