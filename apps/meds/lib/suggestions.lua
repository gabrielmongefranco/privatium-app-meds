-- This file is part of Prescription Tracker
-- apps/meds/lib/suggestions.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-01
-- Summary: The values already in use that text boxes offer while a person types.
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

local suggestions = {}

--- Configuration ---
-- The most values one text box offers. A browser shows a handful at a time, and a
-- longer list only makes the page heavier.
local LIMIT = 200

local function values_of(rows)
  local values = {}
  for _, row in ipairs(rows) do values[#values + 1] = row.value end
  return values
end

-- Every list below has the same grain: one row per distinct value in use, ordered
-- without regard to case. Each query is written out, because the framework accepts
-- literal SQL only.

--- Clinics that prescribers already name.
function suggestions.clinics()
  return values_of(pv.query([[
    SELECT DISTINCT clinic AS value FROM prescriber
     WHERE clinic IS NOT NULL ORDER BY 1 COLLATE NOCASE LIMIT ?]], { LIMIT }))
end

--- What medications on the lists are for.
function suggestions.purposes()
  return values_of(pv.query([[
    SELECT DISTINCT prescribed_for AS value FROM person_medication
     WHERE prescribed_for IS NOT NULL ORDER BY 1 COLLATE NOCASE LIMIT ?]], { LIMIT }))
end

--- Instructions that medications on the lists already have.
function suggestions.instructions()
  return values_of(pv.query([[
    SELECT DISTINCT instructions AS value FROM person_medication
     WHERE instructions IS NOT NULL ORDER BY 1 COLLATE NOCASE LIMIT ?]], { LIMIT }))
end

--- Brand names of the catalog.
function suggestions.brand_names()
  return values_of(pv.query([[
    SELECT DISTINCT brand_name AS value FROM medication
     WHERE brand_name IS NOT NULL ORDER BY 1 COLLATE NOCASE LIMIT ?]], { LIMIT }))
end

--- Generic names of the catalog.
function suggestions.generic_names()
  return values_of(pv.query([[
    SELECT DISTINCT generic_name AS value FROM medication
     WHERE generic_name IS NOT NULL ORDER BY 1 COLLATE NOCASE LIMIT ?]], { LIMIT }))
end

--- Strengths of the catalog.
function suggestions.strengths()
  return values_of(pv.query([[
    SELECT DISTINCT strength AS value FROM medication
     WHERE strength IS NOT NULL ORDER BY 1 COLLATE NOCASE LIMIT ?]], { LIMIT }))
end

--- Package sizes of the catalog.
function suggestions.package_sizes()
  return values_of(pv.query([[
    SELECT DISTINCT package_size AS value FROM medication
     WHERE package_size IS NOT NULL ORDER BY 1 COLLATE NOCASE LIMIT ?]], { LIMIT }))
end

--- The names a medication box offers while a person types.
-- Short names and other names only. A bare brand or generic name belongs to several
-- strengths, so picking it would not say which product is meant.
-- @return table  A list of { value = a name, label = the short name it belongs to }.
--         Grain: one row per medication per distinct short name or other name.
function suggestions.medication_names()
  return pv.query([[
    SELECT n.name AS value, m.short_name AS label
      FROM v_medication_name n
      JOIN medication m ON m.id = n.medication_id    -- many:1
     WHERE n.name_kind IN ('short_name', 'alias')
     ORDER BY n.name COLLATE NOCASE, n.medication_id]])
end

return suggestions
