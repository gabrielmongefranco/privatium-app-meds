-- This file is part of Medication Tracker
-- apps/meds/lib/fills.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Checks the values of a fill and writes it. The form and the reader of pasted fills
--          both save through here, so a fill is checked the same way however it arrives, and a
--          fill for a product on no list adds the tracked medication beside it.
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
local refill   = require 'refill'
local store    = require 'store'
local text     = require 'text'
local validate = require 'validate'

local fills = {}

--- Configuration ---
fills.DAYS_SUPPLY_MAX = 999
fills.REFILLS_MAX     = 99
local QUANTITY_PLACES, QUANTITY_WHOLE = 3, 15   -- The column is DECIMAL(18,3)
local AMOUNT_PLACES, AMOUNT_WHOLE     = 2, 16   -- The column is DECIMAL(18,2)
local RX_NUMBER_MAX, CLAIM_MAX, NOTES_MAX = 40, 60, 500

-- An id must name a record of its table.
local function read_id(raw, tbl, label)
  local id = text.clean(raw)
  if not id then return nil, 'Choose ' .. label .. '.' end
  if not pv.get_row(tbl, id) then return nil, 'Choose ' .. label .. ' from the list.' end
  return id
end

--- Check the values of a fill.
-- @param form table  The values as typed or as read from pasted text, keyed by column.
--        `product_id` names the product that was dispensed; it must be a product of the
--        tracked medication.
-- @param pending table|nil  The columns whose record is added or resolved in the same
--        batch as the fill, as { pharmacy_id = true }. Such a record cannot be looked up
--        yet, so the caller checks it and sets the column before the fill is written.
-- @return table, table  The row for the log, and the problems keyed by column. The row
--         is complete only when the second table is empty.
function fills.read(form, pending)
  local row, errors = {}, {}
  pending = pending or {}
  if not pending.person_medication_id then
    row.person_medication_id, errors.entry_id =
      read_id(form.person_medication_id, 'person_medication', 'a medication')
  end
  if not pending.medication_id and text.clean(form.product_id) then
    row.medication_id = text.clean(form.product_id)
    local entry_id = row.person_medication_id or text.clean(form.person_medication_id)
    local known = entry_id and pv.query1([[
      SELECT count(*) AS products FROM person_medication_product
       WHERE person_medication_id = ? AND medication_id = ?]], { entry_id, row.medication_id })
    if not known or known.products == 0 then
      row.medication_id, errors.product_id = nil, 'Choose a product of this medication from the list.'
    end
  end
  if not pending.pharmacy_id then
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
  if not pending.plan_id and text.clean(form.plan_id) then
    row.plan_id, errors.plan_id = read_id(form.plan_id, 'plan', 'a plan')
  end
  row.insurance_claim_number, errors.insurance_claim_number =
    validate.text(form.insurance_claim_number, 'the claim number', CLAIM_MAX)
  row.notes, errors.notes = validate.text(form.notes, 'the notes', NOTES_MAX)
  return row, errors
end

--- The form of a prescription number that two ways of writing it share.
-- A label prints '1234-567', a portal prints '1234567', and a person types '1234 567'.
-- Hyphens and spaces are left out, and letters are compared in capitals.
-- @param rx_number any
-- @return string|nil  The number to compare by, or nil when there is none.
function fills.rx_key(rx_number)
  local cleaned = text.clean(rx_number)
  if not cleaned then return nil end
  local key = cleaned:gsub('[%s%-]', ''):upper()
  if key == '' then return nil end
  return key
end

--- Whether a person already has a fill with a prescription number on a date.
-- A portal lists the same fill on every visit, so this is what keeps a second paste
-- from adding it again.
-- @return boolean
function fills.recorded(person_id, rx_number, filled_on)
  local key = fills.rx_key(rx_number)
  if not key then return false end
  local found = pv.query1([[
    SELECT count(*) AS fills
      FROM fill f
      JOIN person_medication pm ON pm.id = f.person_medication_id   -- many:1
     WHERE pm.person_id = ?
       AND upper(replace(replace(f.rx_number, '-', ''), ' ', '')) = ?
       AND f.filled_on = ?]],
    { person_id, key, filled_on })
  return found.fills > 0
end

--- Whether a tracked medication already has a fill on a date.
-- Many fills carry no prescription number, such as the ones a person typed from
-- memory. The tracked medication and the date name the fill then.
-- @return boolean
function fills.on_day(person_medication_id, filled_on)
  if not person_medication_id or not filled_on then return false end
  local found = pv.query1([[
    SELECT count(*) AS fills
      FROM fill
     WHERE person_medication_id = ?
       AND filled_on = ?]],
    { person_medication_id, filled_on })
  return found.fills > 0
end

--- The tracked medications a person filled under a prescription number.
-- A prescription is for one medication, so a number that is known names it.
-- @return table  A list of person_medication ids. Grain: one per tracked medication,
--         most often one.
function fills.entries_of_rx(person_id, rx_number)
  local key = fills.rx_key(rx_number)
  if not key then return {} end
  local ids = {}
  for _, row in ipairs(pv.query([[
      SELECT DISTINCT f.person_medication_id
        FROM fill f
        JOIN person_medication pm ON pm.id = f.person_medication_id   -- many:1
       WHERE pm.person_id = ?
         AND upper(replace(replace(f.rx_number, '-', ''), ' ', '')) = ?
       ORDER BY f.person_medication_id]], { person_id, key })) do
    ids[#ids + 1] = row.person_medication_id
  end
  return ids
end

--- Add fills inside a batch, with the tracked medications that go with them.
-- A fill names its tracked medication in `person_medication_id`, or carries
-- `new_entry` = { person_id, medication_id, display_name, status, pharmacy_id } when the
-- product is on no list of the person; the tracked medication is then added first.
-- Several fills of one tracked medication share one row of it, which is written once,
-- after every fill has lowered its count. A medication that was not started or no
-- longer taken becomes taken regularly when one of its new fills still lasts, unless
-- `statuses` names its status.
-- @param tx table    The batch.
-- @param rows table  Rows that fills.read returned with no problems.
-- @param refills_left integer|nil  The refills left after the fill, when the person
--        typed them. Nil lowers the count by one for each fill.
-- @param statuses table|nil  The status a person chose for a tracked medication, by its
--        id. Each value must be a status of choices.STATUSES.
-- @return table  The ids of the fills, in the order of `rows`.
function fills.add_all(tx, rows, refills_left, statuses)
  statuses = statuses or {}
  local today = clock.today()
  local ids, touched, order = {}, {}, {}
  for _, row in ipairs(rows) do
    local key = row.person_medication_id
      or ('new ' .. row.new_entry.person_id .. ' ' .. tostring(row.new_entry.medication_id))
    local state = touched[key]
    if not state then
      state = { id = row.person_medication_id, fills = 0, rows = {} }
      if not state.id then
        -- A tracked medication added here starts with the refills typed, or none.
        local fields = row.new_entry
        fields.refills_left = refills_left or 0
        state.id, state.added = entries.add(tx, fields), true
      end
      touched[key] = state
      order[#order + 1] = key
    end
    row.person_medication_id, row.new_entry = state.id, nil
    state.fills = state.fills + 1
    state.rows[#state.rows + 1] = row
    ids[#ids + 1] = tx.append('fill', row)
  end
  for _, key in ipairs(order) do
    local state = touched[key]
    if not state.added then
      local entry = entries.stored(state.id)
      local id = entry.id
      entry.id = nil
      -- With no count given, each fill uses up one refill.
      entry.refills_left = refills_left or math.max(entry.refills_left - state.fills, 0)
      local status = statuses[id]
      if not status then
        status = entry.status
        for _, fill in ipairs(state.rows) do
          status = refill.status_after_fill(status, fill.filled_on, fill.days_supply, today)
        end
      end
      entry.status = status
      tx.append('person_medication', id, entry)
    end
  end
  return ids
end

--- Add one fill.
-- @param row table  A row that fills.read returned with no problems.
-- @param refills_left integer|nil  The refills left after the fill. Nil lowers the
--        count by one.
-- @param before function|nil  Receives the batch and the row before the fill is
--        written. It adds the records the fill points to that are new, and sets their
--        ids on the row.
-- @return string|nil, string|nil  The id of the fill, or nil and a message. Writes the
--         fill, its tracked medication and the new records in one batch.
function fills.save_new(row, refills_left, before)
  local ids
  local saved, refusal = store.together('fill', function(tx)
    if before then before(tx, row) end
    ids = fills.add_all(tx, { row }, refills_left)
  end)
  if not saved then return nil, refusal end
  return ids[1]
end

return fills
