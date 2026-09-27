-- This file is part of Prescription Tracker
-- apps/meds/lib/medication_search.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Finds the medications of the catalog that a typed name matches. Every screen that
--          asks for a medication searches here, so all of them find the same things.
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

local pv    = require 'privatium'
local match = require 'match'
local text  = require 'text'

local medication_search = {}

--- Configuration ---
local TYPED_MAX = 100   -- Longer than any name a person would type to search

--- Clean what a person typed into a search box.
-- @param raw any
-- @return string  The cleaned text, or '' when it is empty or too long to be a name.
function medication_search.typed(raw)
  local typed = text.clean(raw) or ''
  if (text.length(typed) or TYPED_MAX + 1) > TYPED_MAX then return '' end
  return typed
end

--- Search the catalog.
-- @param typed string  What the person typed, already cleaned.
-- @return table  { matches = list, close = list, exact = boolean }. Each list entry is a
--         medication row with `matched_name`, the name that matched. `matches` holds the
--         medications whose name is or contains what was typed. `close` holds the ones
--         that are near it, which a person must confirm. `exact` says whether a name is
--         exactly what was typed.
function medication_search.find(typed)
  local found = { matches = {}, close = {}, exact = false }
  if typed == '' then return found end

  -- Grain: one row per medication per distinct name.
  local names = pv.query([[
    SELECT medication_id, name
      FROM v_medication_name
     ORDER BY name COLLATE NOCASE, medication_id]])
  local ranked = match.rank(typed, names)
  if #ranked == 0 then return found end

  -- Grain: one row per medication.
  local medications = {}
  for _, row in ipairs(pv.query([[
      SELECT medication_id, short_name, full_name, is_specialty
        FROM v_medication]])) do
    medications[row.medication_id] = row
  end

  for _, result in ipairs(ranked) do
    local medication = medications[result.medication_id]
    -- A name can outlive its medication for a moment while another device syncs.
    if medication then
      medication.matched_name = result.name
      if result.kind == match.CLOSE then
        found.close[#found.close + 1] = medication
      else
        found.matches[#found.matches + 1] = medication
        if result.kind == match.EXACT then found.exact = true end
      end
    end
  end
  return found
end

return medication_search
