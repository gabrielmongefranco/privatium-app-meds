-- This file is part of Prescription Tracker
-- apps/meds/lib/entries.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Reads what people take: each entry of a person's medication list with its refill
--          dates, its refill status in words, and its group on the Refills page.
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

local pv       = require 'privatium'
local choices  = require 'choices'
local refill   = require 'refill'
local validate = require 'validate'

local entries = {}

local GROUP_BY_KEY = {}
for _, group in ipairs(refill.GROUPS) do GROUP_BY_KEY[group.key] = group end

-- Adds to a row what the screens show beside the stored values.
local function dressed(row)
  row.status_label = choices.status_label(row.status)
  row.group        = refill.group(row.status, row.refill_status, row.days_supply_missing)
  row.phrase       = refill.phrase(row.refill_status, row.days_until_next_fill)
  local group      = GROUP_BY_KEY[row.group]
  -- A medication that raises no alert shows its status in a quiet badge.
  local shown      = group and group.alert and group or GROUP_BY_KEY[row.group or 'paused']
  row.badge, row.icon_name = shown.badge, shown.icon
  row.prescriber_href = validate.tel_href(row.prescriber_phone)
  row.pharmacy_href   = validate.tel_href(row.pharmacy_phone)
  return row
end

--- The entries of the medication lists.
-- @param person_id string  The id of one person, or '' for everyone.
-- @return table  Grain: one row per person_medication row, ordered by person and then
--         by medication.
function entries.list(person_id)
  local rows = pv.query([[
    SELECT pm.id, pm.person_id, pm.medication_id, pm.medication_type, pm.status,
           pm.prescribed_for, pm.instructions, pm.when_to_take, pm.refills_left,
           p.display_name  AS person_name,
           m.short_name    AS medication_name,
           m.is_specialty,
           pr.name         AS prescriber_name,
           pr.phone        AS prescriber_phone,
           ph.name         AS pharmacy_name,
           ph.phone        AS pharmacy_phone,
           lph.name        AS last_fill_pharmacy_name,
           s.last_fill_id, s.last_filled_on, s.last_days_supply, s.days_supply_missing,
           s.next_fill_on, s.recommended_next_fill_on,
           coalesce(a.refill_status, CASE WHEN s.next_fill_on IS NULL THEN 'no_fill' ELSE 'not_due' END) AS refill_status,
           CAST(julianday(s.next_fill_on) - julianday(date('now', 'localtime')) AS INTEGER) AS days_until_next_fill
      FROM person_medication pm
      JOIN person p     ON p.id = pm.person_id        -- many:1
      JOIN medication m ON m.id = pm.medication_id    -- many:1
      JOIN v_supply s   ON s.person_medication_id = pm.id          -- 1:1
      LEFT JOIN v_active_medication a ON a.person_medication_id = pm.id   -- 1:0..1; absent when no longer taken
      LEFT JOIN prescriber pr ON pr.id = pm.prescriber_id          -- many:0..1
      LEFT JOIN pharmacy ph   ON ph.id = pm.pharmacy_id            -- many:0..1
      LEFT JOIN pharmacy lph  ON lph.id = s.last_pharmacy_id       -- many:0..1
     WHERE ?1 = '' OR pm.person_id = ?1
     ORDER BY p.display_name COLLATE NOCASE, m.short_name COLLATE NOCASE, pm.id]], { person_id })
  for _, row in ipairs(rows) do dressed(row) end
  return rows
end

--- One entry of a medication list.
-- @param id string
-- @return table|nil  The row as entries.list returns it, or nil when there is none.
function entries.one(id)
  local stored = pv.get_row('person_medication', id)
  if not stored then return nil end
  for _, row in ipairs(entries.list(stored.person_id)) do
    if row.id == id then return row end
  end
  return nil
end

--- The entry of one person for one medication.
-- @return table|nil  Every column of the person_medication row, or nil.
function entries.of(person_id, medication_id)
  return pv.query1([[
    SELECT id, person_id, medication_id, medication_type, status, pharmacy_id,
           prescriber_id, prescribed_for, instructions, when_to_take, refills_left
      FROM person_medication
     WHERE person_id = ? AND medication_id = ?
     ORDER BY id
     LIMIT 1]], { person_id, medication_id })
end

return entries
