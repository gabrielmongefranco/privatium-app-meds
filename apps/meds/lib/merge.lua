-- This file is part of Prescription Tracker
-- apps/meds/lib/merge.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-03
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

--- Reads ---

-- Grain: one row per fill that names one product, with every column of the table.
local function fills_of(id)
  return pv.query([[
    SELECT id, person_medication_id, medication_id, pharmacy_id, filled_on, rx_number, quantity,
           days_supply, amount_paid, plan_id, insurance_claim_number, notes
      FROM fill
     WHERE medication_id = ?]], { id })
end

-- Grain: one row per link between a tracked medication and one product, with the
-- person of the tracked medication.
local function links_of(id)
  return pv.query([[
    SELECT tp.id, tp.person_medication_id, tp.medication_id, pm.person_id
      FROM person_medication_product tp
      JOIN person_medication pm ON pm.id = tp.person_medication_id   -- many:1
     WHERE tp.medication_id = ?]], { id })
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
-- @return table  The plan: the fills to point at the target, the links of tracked
--         medications to move or to drop, the people who end up with the target on two
--         tracked medications, and the names the target gains.
function merge.plan(source, target)
  local plan = {
    source = source, target = target,
    fills = fills_of(source.medication_id),
    links_moved = {}, links_dropped = {}, shared = {},
    aliases_moved = {}, aliases_dropped = {}, names_added = {},
  }

  -- A tracked medication that holds both products keeps one link. A person whose
  -- other tracked medication holds the target would hold it twice afterwards; the
  -- plan says so, and the person takes it off one of them.
  local has_target, people_with_target = {}, {}
  for _, link in ipairs(links_of(target.medication_id)) do
    has_target[link.person_medication_id] = true
    people_with_target[link.person_id] = (people_with_target[link.person_id] or 0) + 1
  end
  local shared = {}
  for _, link in ipairs(links_of(source.medication_id)) do
    if has_target[link.person_medication_id] then
      plan.links_dropped[#plan.links_dropped + 1] = link
    else
      plan.links_moved[#plan.links_moved + 1] = link
      if people_with_target[link.person_id] and not shared[link.person_id] then
        shared[link.person_id] = true
        plan.shared[#plan.shared + 1] = link.person_id
      end
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
    for _, link in ipairs(plan.links_dropped) do tx.delete('person_medication_product', link.id) end
    for _, link in ipairs(plan.links_moved) do
      tx.append('person_medication_product', link.id,
        { person_medication_id = link.person_medication_id, medication_id = target_id })
    end
    for _, fill in ipairs(plan.fills) do tx.append('fill', fill.id, without_id(fill, moved)) end
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
