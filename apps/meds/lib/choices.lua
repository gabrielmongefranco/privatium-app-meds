-- This file is part of Prescription Tracker
-- apps/meds/lib/choices.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-03
-- Summary: The starter choices for the drop-down lists, and the merge of a starter list
--          with the values that records already use. Pure Lua with no framework calls,
--          so plain Lua can test it.
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

local text = require 'text'

local choices = {}

--- Starter lists ---
-- Plain words a label or a pharmacist would use. A household adds its own by typing
-- them into a form; nothing here has to be complete.

choices.ROUTES = {
  'Oral', 'Inhalation', 'Nasal', 'Eye', 'Ear', 'Topical', 'Rectal', 'Vaginal',
  'Subcutaneous Injection', 'Intramuscular Injection', 'Other',
}

choices.FORMS = {
  'Tablet', 'Capsule', 'Gummy', 'Liquid', 'Suspension', 'Drops', 'Cream', 'Ointment', 'Gel',
  'Patch', 'Inhaler', 'Nebulizer Solution', 'Spray', 'Injection', 'Powder',
  'Suppository', 'Device', 'Supplies', 'Other',
}

choices.PACKAGE_TYPES = {
  'Pack', 'Bottle', 'Box', 'Blister Pack', 'Tube', 'Vial', 'Pen', 'Packet', 'Inhaler', 'Other',
}

choices.MEDICATION_TYPES = {
  'Prescription Medication - Long Term', 'Prescription Medication - Short Term',
  'Prescription Medication - As Needed', 'Over-the-Counter Medication - Long Term',
  'Over-the-Counter Medication - Short Term', 'Over-the-Counter Medication - As Needed',
  'Medical Supplies and Consumables', 'Medical Equipment and Accessories', 'Other',
}

choices.TIMES_TO_TAKE = {
  'Anytime', 'Morning', 'Noon', 'Evening', 'Night - At Bedtime', 'Morning and Evening',
  'Before Meals', 'With Meals', 'After Meals', 'As Needed',
}

-- The five statuses of the schema, in the order the screens show them.
choices.STATUSES = {
  { value = 'taking_regularly', label = 'Taking regularly' },
  { value = 'taking_as_needed', label = 'Taking as needed' },
  { value = 'on_hold',          label = 'On hold' },
  { value = 'not_started',      label = 'Not started' },
  { value = 'not_taking',       label = 'No longer taking' },
}

--- The words for a status.
-- @param status string  A status as stored.
-- @return string|nil  The words, or nil for a value that is not a status.
function choices.status_label(status)
  for _, entry in ipairs(choices.STATUSES) do
    if entry.value == status then return entry.label end
  end
  return nil
end

--- Merge a starter list with the values in use.
-- A value in use that differs from a starter choice only by case or punctuation is
-- the same choice, and the spelling of the starter list wins. Values in use that are
-- new follow the starter list, sorted without regard to case.
-- @param starter table  A list of strings, in the order to show them.
-- @param in_use table   A list of strings read from the records.
-- @return table  A list of strings with no repeats.
function choices.merge(starter, in_use)
  local merged, seen, extra = {}, {}, {}
  for _, choice in ipairs(starter) do
    local key = text.key(choice)
    if not seen[key] then
      seen[key] = true
      merged[#merged + 1] = choice
    end
  end
  for _, value in ipairs(in_use) do
    local key = text.key(value)
    if key ~= '' and not seen[key] then
      seen[key] = true
      extra[#extra + 1] = value
    end
  end
  table.sort(extra, function(a, b) return text.key(a) < text.key(b) end)
  for _, value in ipairs(extra) do merged[#merged + 1] = value end
  return merged
end

return choices
