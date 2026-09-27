-- This file is part of Prescription Tracker
-- apps/meds/lib/fills.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Checks the values of a fill and writes it. The form and the reader of pasted fills
--          both save through here, so a fill is checked the same way however it arrives.
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
local clock    = require 'clock'
local entries  = require 'entries'
local store    = require 'store'
local text     = require 'text'
local validate = require 'validate'

local fills = {}

--- Configuration ---
fills.DAYS_SUPPLY_MAX = 999
fills.REFILLS_MAX     = 99
local QUANTITY_PLACES, QUANTITY_WHOLE = 3, 15   -- The column is DECIMAL(18,3)
local AMOUNT_PLACES, AMOUNT_WHOLE     = 2, 16   -- The column is DECIMAL(18,2)
local RX_NUMBER_MAX, PLAN_MAX, CLAIM_MAX, NOTES_MAX = 40, 80, 60, 500

-- An id must name a record of its table.
local function read_id(raw, tbl, label)
  local id = text.clean(raw)
  if not id then return nil, 'Choose ' .. label .. '.' end
  if not pv.get_row(tbl, id) then return nil, 'Choose ' .. label .. ' from the list.' end
  return id
end

--- Check the values of a fill.
-- @param form table  The values as typed or as read from pasted text, keyed by column.
-- @param new_pharmacy boolean|nil  True when the pharmacy is added in the same batch as
--        the fill, so it cannot be looked up yet.
-- @return table, table  The row for the log, and the problems keyed by column. The row
--         is complete only when the second table is empty.
function fills.read(form, new_pharmacy)
  local row, errors = {}, {}
  row.person_id, errors.person_id = read_id(form.person_id, 'person', 'a person')
  row.medication_id, errors.medication_id = read_id(form.medication_id, 'medication', 'a medication')
  if new_pharmacy then
    row.pharmacy_id = form.pharmacy_id
  else
    row.pharmacy_id, errors.pharmacy_id = read_id(form.pharmacy_id, 'pharmacy', 'a pharmacy')
  end
  row.filled_on, errors.filled_on = validate.date(form.filled_on, 'the date filled', true)
  if row.filled_on then
    row.filled_on, errors.filled_on = validate.not_after(
      row.filled_on, clock.today(), 'Choose a date filled that is not in the future.')
  end
  row.days_supply, errors.days_supply =
    validate.whole_number(form.days_supply, 'the days supply', 0, fills.DAYS_SUPPLY_MAX)
  row.quantity, errors.quantity =
    validate.decimal(form.quantity, 'the quantity', QUANTITY_PLACES, QUANTITY_WHOLE)
  row.amount_paid, errors.amount_paid =
    validate.decimal(form.amount_paid, 'the amount you paid', AMOUNT_PLACES, AMOUNT_WHOLE)
  row.rx_number, errors.rx_number =
    validate.text(form.rx_number, 'the prescription number', RX_NUMBER_MAX)
  row.insurance_plan, errors.insurance_plan =
    validate.text(form.insurance_plan, 'the insurance plan', PLAN_MAX)
  row.insurance_claim_number, errors.insurance_claim_number =
    validate.text(form.insurance_claim_number, 'the claim number', CLAIM_MAX)
  row.notes, errors.notes = validate.text(form.notes, 'the notes', NOTES_MAX)
  return row, errors
end

--- Whether a person already has a fill with a prescription number on a date.
-- A portal lists the same fill on every visit, so this is what keeps a second paste
-- from adding it again.
-- @return boolean
function fills.recorded(person_id, rx_number, filled_on)
  if not rx_number then return false end
  local found = pv.query1([[
    SELECT count(*) AS fills
      FROM fill
     WHERE person_id = ? AND rx_number = ? AND filled_on = ?]],
    { person_id, rx_number, filled_on })
  return found.fills > 0
end

-- The list entry that goes with a new fill: the one the person has, with the new
-- refills left, or a new one when the medication is not on the list yet.
local function entry_for(row, refills_left)
  local entry = entries.of(row.person_id, row.medication_id)
  if not entry then
    return nil, {
      person_id = row.person_id, medication_id = row.medication_id,
      status = 'taking_regularly', pharmacy_id = row.pharmacy_id,
      refills_left = refills_left or 0,
    }
  end
  local id = entry.id
  entry.id = nil
  -- With no count given, a fill uses up one refill. The count never goes below zero.
  entry.refills_left = refills_left or math.max(entry.refills_left - 1, 0)
  return id, entry
end

--- Add fills inside a batch, with the list entries that go with them.
-- Several fills of one medication share one list entry, which is written once, after
-- every fill has lowered its count.
-- @param tx table    The batch.
-- @param rows table  Rows that fills.read returned with no problems.
-- @param refills_left integer|nil  The refills left after the fill, when the person
--        typed them. Nil lowers the count by one for each fill.
-- @return table  The ids of the fills, in the order of `rows`.
function fills.add_all(tx, rows, refills_left)
  local ids, touched, order = {}, {}, {}
  for _, row in ipairs(rows) do
    ids[#ids + 1] = tx.append('fill', row)
    local key = row.person_id .. ' ' .. row.medication_id
    local state = touched[key]
    if state then
      state.entry.refills_left = math.max(state.entry.refills_left - 1, 0)
    else
      local id, entry = entry_for(row, refills_left)
      touched[key] = { id = id, entry = entry }
      order[#order + 1] = key
    end
  end
  for _, key in ipairs(order) do
    tx.append('person_medication', touched[key].id, touched[key].entry)
  end
  return ids
end

--- Add one fill.
-- @return string|nil, string|nil  The id of the fill, or nil and a message. Writes the
--         fill and its list entry in one batch.
function fills.save_new(row, refills_left)
  local ids
  local saved, refusal = store.together('fill', function(tx)
    ids = fills.add_all(tx, { row }, refills_left)
  end)
  if not saved then return nil, refusal end
  return ids[1]
end

return fills
