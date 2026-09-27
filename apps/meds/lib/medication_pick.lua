-- This file is part of Prescription Tracker
-- apps/meds/lib/medication_pick.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Reads the medication box of a form: a medication in use, a name typed to
--          search the catalog, or a new medication.
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

local pv                = require 'privatium'
local catalog_entry     = require 'catalog_entry'
local medication_search = require 'medication_search'
local reference_words   = require 'reference_words'
local text              = require 'text'

local medication_pick = {}

--- Configuration ---
medication_pick.NEW   = 'new'     -- The choice that adds a medication from the fields under it
medication_pick.OTHER = 'other'   -- The choice that finds a medication by a typed name
local CANDIDATES_MAX  = 8         -- Medications offered when a typed name fits several
local NO_CHOICES      = { route = {}, dose_form = {}, package_type = {} }

--- Reads ---

--- The medications a household uses: on a list, or filled at least once.
-- These fill the drop-down of the medication box, so the common case is one choice.
-- @param also string|nil  The id of one more medication to offer, such as the one a
--        stored record names.
-- @return table  A list of { value = id, label = short name }, ordered by name.
--         Grain: one row per medication.
function medication_pick.in_use(also)
  local options = {}
  for _, row in ipairs(pv.query([[
      SELECT m.id, m.short_name
        FROM medication m
       WHERE m.id = ?1
          OR EXISTS (SELECT 1 FROM person_medication pm WHERE pm.medication_id = m.id)
          OR EXISTS (SELECT 1 FROM fill f WHERE f.medication_id = m.id)
       ORDER BY m.short_name COLLATE NOCASE, m.id]], { also or '' })) do
    options[#options + 1] = { value = row.id, label = row.short_name }
  end
  return options
end

-- The medication with an id, or a message.
local function by_id(id)
  if pv.get_row('medication', id) then return { id = id } end
  return { problem = 'Choose a medication from the list.' }
end

-- A new medication from the fields of the box. A medication that already has the same
-- short name or the same RxNorm identifier is picked instead, so a product is never
-- added twice. The fields that name a drug reference are filled in by the lookup in
-- the browser. They are untrusted like any other field, and pass the same checks.
local function as_new(form, prefix)
  local route = reference_words.route(form[prefix .. '_route'])
  local row, errors, same_as = catalog_entry.read({
    brand_name   = form[prefix .. '_brand'],
    generic_name = form[prefix .. '_generic'],
    strength     = form[prefix .. '_strength'],
    is_specialty = form[prefix .. '_specialty'],
    package_size = form[prefix .. '_package_size'],
    package_type = form[prefix .. '_package_type'],
    rxcui        = form[prefix .. '_rxcui'],
    source       = form[prefix .. '_source'],
    route        = route,
    dose_form    = reference_words.form(form[prefix .. '_dose_form'], route),
  }, nil, NO_CHOICES)
  if same_as then return { id = same_as } end
  for _, field in ipairs({ 'brand_name', 'generic_name', 'strength', 'package_size',
                           'package_type', 'short_name', 'rxcui' }) do
    if errors[field] then return { problem = errors[field], open_new = true } end
  end
  return { new_row = row }
end

-- The medication that answers to a typed name. Only a name that exactly one medication
-- answers to picks it. Anything else is a question for the person.
local function by_name(raw)
  local typed = medication_search.typed(raw)
  if typed == '' then
    return { problem = 'Type the name of the medication, or pick one from the list.' }
  end
  local found = medication_search.find(typed)
  local exact = {}
  for _, medication in ipairs(found.matches) do
    if medication.exact then exact[#exact + 1] = medication end
  end
  if #exact == 1 then return { id = exact[1].medication_id } end

  local candidates = {}
  for _, group in ipairs(#exact > 1 and { exact } or { found.matches, found.close }) do
    for _, medication in ipairs(group) do
      if #candidates < CANDIDATES_MAX then candidates[#candidates + 1] = medication end
    end
  end
  if #candidates == 0 then
    return { open_new = true, candidates = candidates,
             problem = 'No medication answers to this name. Check the spelling, or add it as a new medication.' }
  end
  return { candidates = candidates,
           problem = 'Choose the medication you mean from the choices under the name.' }
end

--- Read the medication box of a form.
-- The box holds a drop-down (`prefix`_id), a name to type (`prefix`_name), choices
-- (`prefix`_choice) and the fields of a new medication (`prefix`_brand, _generic,
-- _strength, _package_size, _package_type, _specialty). A choice wins. Without one,
-- the fields of a new medication
-- win over a typed name, and a typed name wins over the drop-down.
-- @param form table     The values of the form.
-- @param prefix string  The start of the field names, such as 'medication'.
-- @param required boolean|nil
-- @param explicit boolean|nil  True when the box starts with its fields filled in by
--        the app, as the review of pasted fills does. Only a choice counts then, so a
--        value the person never looked at picks nothing.
-- @return table  { id = the medication picked } or { new_row = the row of a medication
--         to add } or { problem = a message, candidates = medications to choose from,
--         open_new = whether to show the fields of a new medication }. An empty
--         optional box returns an empty table. Reads only; writes nothing.
function medication_pick.read(form, prefix, required, explicit)
  local choice = text.clean(form[prefix .. '_choice'])
  if choice == medication_pick.NEW then return as_new(form, prefix) end
  if choice == medication_pick.OTHER then return by_name(form[prefix .. '_name']) end
  if choice then return by_id(choice) end
  if explicit then
    if not required then return {} end
    return { problem = 'Choose a medication: pick one of the choices, or add a new one.' }
  end

  if text.clean(form[prefix .. '_brand']) or text.clean(form[prefix .. '_generic']) then
    return as_new(form, prefix)
  end
  if text.clean(form[prefix .. '_name']) then return by_name(form[prefix .. '_name']) end
  local id = text.clean(form[prefix .. '_id'])
  if id == medication_pick.NEW then
    return { open_new = true,
             problem = 'Type the name of the medication to find it, or add it as a new medication.' }
  end
  if id then return by_id(id) end
  if required then
    return { problem = 'Choose a medication: pick one from the list, type its name, or add a new one.' }
  end
  return {}
end

--- Add the new medication of a box inside a batch.
-- @param tx table    The batch.
-- @param pick table  What medication_pick.read returned, with no problem.
-- @return string|nil  The id of the medication: the one picked, or the one just added.
function medication_pick.write(tx, pick)
  if pick.new_row then return tx.append('medication', pick.new_row) end
  return pick.id
end

return medication_pick
