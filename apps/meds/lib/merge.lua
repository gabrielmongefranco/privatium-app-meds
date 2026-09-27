-- This file is part of Prescription Tracker
-- apps/meds/lib/merge.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Merges one medication of the catalog into another when both are the same product.
--          The plan says what will move; applying it writes every change in one batch.
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
local store = require 'store'
local text  = require 'text'

local merge = {}

--- Configuration ---
-- When one person has both medications on their list, one entry is kept. The entry
-- with the status nearer the top of this list wins; a tie keeps the entry of the
-- medication that stays.
local STATUS_RANK = {
  taking_regularly = 1, taking_as_needed = 2, on_hold = 3, not_started = 4, not_taking = 5,
}

--- Reads ---

-- Grain: one row per fill of one medication, with every column of the table.
local function fills_of(id)
  return pv.query([[
    SELECT id, person_id, medication_id, pharmacy_id, filled_on, rx_number, quantity,
           days_supply, amount_paid, insurance_plan, insurance_claim_number, notes
      FROM fill
     WHERE medication_id = ?]], { id })
end

-- Grain: one row per list entry of one medication, with every column of the table.
local function entries_of(id)
  return pv.query([[
    SELECT id, person_id, medication_id, medication_type, status, pharmacy_id,
           prescriber_id, prescribed_for, instructions, when_to_take, refills_left
      FROM person_medication
     WHERE medication_id = ?]], { id })
end

-- Grain: one row per prior authorization of one medication, with every column.
local function authorizations_of(id)
  return pv.query([[
    SELECT id, person_id, medication_id, valid_from, valid_to
      FROM prior_authorization
     WHERE medication_id = ?]], { id })
end

-- Grain: one row per other name of one medication.
local function aliases_of(id)
  return pv.query('SELECT id, medication_id, alias FROM medication_alias WHERE medication_id = ?', { id })
end

-- Grain: one row per distinct name of one medication.
local function names_of(id)
  return pv.query('SELECT name FROM v_medication_name WHERE medication_id = ?', { id })
end

-- A row as the log wants it: every column but the id, which travels beside the row.
local function without_id(row, changes)
  local copy = {}
  for key, value in pairs(row) do
    if key ~= 'id' then copy[key] = value end
  end
  for key, value in pairs(changes) do copy[key] = value end
  return copy
end

--- Plan ---

--- Work out what a merge will do, without writing anything.
-- @param source table  The medication that goes away: a row of v_medication.
-- @param target table  The medication that stays: a row of v_medication.
-- @return table  The plan: the rows to move, the list entries to keep and to drop, and
--         the names the target gains.
function merge.plan(source, target)
  local plan = {
    source = source, target = target,
    fills = fills_of(source.medication_id),
    authorizations = authorizations_of(source.medication_id),
    entries_moved = {}, entries_dropped = {},
    aliases_moved = {}, aliases_dropped = {}, names_added = {},
  }

  local kept = {}
  for _, entry in ipairs(entries_of(target.medication_id)) do kept[entry.person_id] = entry end
  for _, entry in ipairs(entries_of(source.medication_id)) do
    local other = kept[entry.person_id]
    if not other then
      plan.entries_moved[#plan.entries_moved + 1] = entry
    elseif STATUS_RANK[entry.status] < STATUS_RANK[other.status] then
      -- The entry of the medication that goes away is the one in use, so it takes the
      -- place of the other.
      plan.entries_moved[#plan.entries_moved + 1] = entry
      plan.entries_dropped[#plan.entries_dropped + 1] = other
    else
      plan.entries_dropped[#plan.entries_dropped + 1] = entry
    end
  end

  local known = {}
  for _, row in ipairs(names_of(target.medication_id)) do known[text.key(row.name)] = true end
  for _, alias in ipairs(aliases_of(source.medication_id)) do
    local key = text.key(alias.alias)
    if known[key] then
      plan.aliases_dropped[#plan.aliases_dropped + 1] = alias
    else
      known[key] = true
      plan.aliases_moved[#plan.aliases_moved + 1] = alias
    end
  end
  for _, name in ipairs({ source.short_name, source.generic_name, source.brand_name }) do
    local key = text.key(name)
    if key ~= '' and not known[key] then
      known[key] = true
      plan.names_added[#plan.names_added + 1] = name
    end
  end
  return plan
end

--- Apply ---

--- Carry out a plan. Every change lands together, or none does.
-- @param plan table  What merge.plan returned.
-- @return boolean, string|nil  True, or false and a message. Writes one batch of events.
function merge.apply(plan)
  local target_id = plan.target.medication_id
  local moved = { medication_id = target_id }
  return store.together('medication', function(tx)
    for _, entry in ipairs(plan.entries_dropped) do tx.delete('person_medication', entry.id) end
    for _, entry in ipairs(plan.entries_moved) do
      tx.append('person_medication', entry.id, without_id(entry, moved))
    end
    for _, fill in ipairs(plan.fills) do tx.append('fill', fill.id, without_id(fill, moved)) end
    for _, authorization in ipairs(plan.authorizations) do
      tx.append('prior_authorization', authorization.id, without_id(authorization, moved))
    end
    for _, alias in ipairs(plan.aliases_dropped) do tx.delete('medication_alias', alias.id) end
    for _, alias in ipairs(plan.aliases_moved) do
      tx.append('medication_alias', alias.id, without_id(alias, moved))
    end
    for _, name in ipairs(plan.names_added) do
      tx.append('medication_alias', { medication_id = target_id, alias = name })
    end
    tx.delete('medication', plan.source.medication_id)
  end)
end

return merge
