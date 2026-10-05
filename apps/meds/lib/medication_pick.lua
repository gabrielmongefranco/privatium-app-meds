-- This file is part of Prescription Tracker
-- apps/meds/lib/medication_pick.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Reads the medication box of a form: a name typed to search the catalog, a choice
--          among several, a product carried by its id, or a new medication.
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
local medication_name   = require 'medication_name'
local medication_search = require 'medication_search'
local reference_words   = require 'reference_words'
local text              = require 'text'

local medication_pick = {}

--- Configuration ---
medication_pick.NEW   = 'new'     -- The choice that adds a medication from the fields under it
medication_pick.OTHER = 'other'   -- The choice that finds a medication by a typed name
local CANDIDATES_MAX  = 8         -- Medications offered when a typed name fits several
medication_pick.RESULTS_MAX = 25  -- Products one search of the box lists, best first
medication_pick.STEP  = 'step'    -- The field that names what a button of the form asks for
-- The fields of a new medication, by the ending of their names in the form.
medication_pick.NEW_FIELDS = {
  'brand', 'generic', 'strength', 'package_size', 'package_type', 'package_type_new',
  'route', 'route_new', 'route_ref', 'dose_form', 'dose_form_new', 'dose_form_ref',
  'rxcui', 'source', 'controlled', 'specialty',
}

--- Reads ---

--- The medication with an id.
-- @param id string|nil  The id a form carried or a checkbox named.
-- @return table  { id = id }, or { problem = a message } when no medication has it.
function medication_pick.by_id(id)
  if id and pv.get_row('medication', id) then return { id = id } end
  return { problem = 'Choose a medication from the list.' }
end
local by_id = medication_pick.by_id

-- A choice from its drop-down or its typed box, else the hint a drug reference gave in
-- _route_ref or _dose_form_ref, so the person's own choice always wins.
local function chosen_or_hint(form, prefix, ending, from_hint)
  local typed = text.clean(form[prefix .. '_' .. ending .. '_new'])
  local listed = text.clean(form[prefix .. '_' .. ending])
  if listed == 'new' then listed = nil end
  if typed or listed then return typed or listed end
  return from_hint(form[prefix .. '_' .. ending .. '_ref'])
end

--- A new medication from the fields of the box.
-- The reference fields come from the lookup in the browser and pass the same checks as
-- typed ones, because the browser is not trusted.
-- @param form table  The posted form.
-- @param prefix string  The prefix of the box's field names.
-- @return table  { id } when a medication with the same short name or RxNorm identifier
--         exists, so a product is never added twice; { new_row } for a new one; or
--         { problem, open_new } when a field is refused.
function medication_pick.as_new(form, prefix)
  local route = chosen_or_hint(form, prefix, 'route', reference_words.route)
  local dose_form = chosen_or_hint(form, prefix, 'dose_form', function(hint)
    return reference_words.form(hint, route)
  end)
  local row, errors, same_as = catalog_entry.read({
    brand_name   = form[prefix .. '_brand'],
    generic_name = form[prefix .. '_generic'],
    strength     = form[prefix .. '_strength'],
    is_specialty = form[prefix .. '_specialty'],
    is_controlled = form[prefix .. '_controlled'],
    package_size = form[prefix .. '_package_size'],
    package_type = form[prefix .. '_package_type'],
    package_type_new = form[prefix .. '_package_type_new'],
    rxcui        = form[prefix .. '_rxcui'],
    source       = form[prefix .. '_source'],
    route        = route,
    dose_form    = dose_form,
  }, nil, catalog_entry.options())
  if same_as then return { id = same_as } end
  for _, field in ipairs({ 'brand_name', 'generic_name', 'strength', 'package_size',
                           'package_type', 'short_name', 'rxcui' }) do
    if errors[field] then return { problem = errors[field], open_new = true } end
  end
  return { new_row = row }
end
local as_new = medication_pick.as_new

-- The medication that answers to a typed name. Only a name that exactly one medication
-- answers to picks it. Anything else is a question for the person.
local function by_name(raw)
  local typed = medication_search.typed(raw)
  if typed == '' then
    return { problem = 'Type the name of the medication, or add it as a new one.' }
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
             problem = 'No medication found with this name. Check the spelling, or add it as a new medication.' }
  end
  return { candidates = candidates,
           problem = 'Choose the medication you mean from the choices under the name.' }
end

--- Read the medication box of a form.
-- The box holds a name to type (`prefix`_name), choices (`prefix`_choice), the fields
-- of a new medication (`prefix`_brand, _generic, _strength, _package_size,
-- _package_type, _controlled, _specialty and the fields of a drug reference), and may
-- carry a product by its id (`prefix`_id). A choice wins. Without one, the fields of a
-- new medication win over a typed name, and a typed name wins over the carried id.
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
  if id then return by_id(id) end
  if required then
    return { problem = 'Choose a medication: type its name, or add a new one.' }
  end
  return {}
end

--- Whether the fields of a new medication hold a name.
-- @return boolean
function medication_pick.filled_new(form, prefix)
  return text.clean(form[prefix .. '_brand']) ~= nil
    or text.clean(form[prefix .. '_generic']) ~= nil
end

--- Whether anything at all was typed into the fields of a new medication, a name or not.
-- A strength typed alone is a mistake worth a message of its own.
-- @return boolean
function medication_pick.touched_new(form, prefix)
  return medication_pick.filled_new(form, prefix)
    or text.clean(form[prefix .. '_strength']) ~= nil
    or text.clean(form[prefix .. '_package_size']) ~= nil
end

--- Search the catalog for the products a typed name fits.
-- @param typed string  What was typed, already cleaned by medication_search.typed.
-- @return table  Up to RESULTS_MAX rows of { medication_id, short_name, full_name, close }, the
--         ones that hold the name first and the close ones after them. `close` is true
--         for a name that is near what was typed, which a person must confirm.
function medication_pick.search(typed)
  local results = {}
  if typed == '' then return results end
  local found = medication_search.find(typed)
  for _, group in ipairs({ found.matches, found.close }) do
    for _, row in ipairs(group) do
      if #results >= medication_pick.RESULTS_MAX then break end
      results[#results + 1] = {
        medication_id = row.medication_id,
        short_name    = row.short_name,
        full_name     = row.full_name,
        close         = group == found.close,
      }
    end
  end
  return results
end

--- What the search box of a form asked, when it asked anything.
-- A name typed into the box with nothing chosen and no new medication counts as a
-- search, whichever button was pressed, so Enter in the box never saves the form.
-- @return table|nil  { term, results, problem, open_new, searching = true } when the form
--         must come back with the results, or nil when the box asked nothing.
function medication_pick.searched(form, prefix)
  local term = medication_search.typed(form[prefix .. '_q'])
  local asked = text.clean(form[medication_pick.STEP]) == 'find_' .. prefix
  if not asked and (term == '' or text.clean(form[prefix .. '_choice'])
                    or medication_pick.filled_new(form, prefix)) then
    return nil
  end
  local pick = { term = term, searching = true }
  if term == '' then
    pick.problem = 'Type a name to search for.'
    return pick
  end
  pick.results = medication_pick.search(term)
  if #pick.results == 0 then
    pick.problem = 'No medication found with this name. Check the spelling, or add it to the catalog below.'
    pick.open_new = true
  end
  return pick
end

--- Whether a box holds anything to read: a typed name, a choice or a new medication.
-- @return boolean
function medication_pick.filled(form, prefix)
  return text.clean(form[prefix .. '_choice']) ~= nil
    or text.clean(form[prefix .. '_name']) ~= nil
    or text.clean(form[prefix .. '_brand']) ~= nil
    or text.clean(form[prefix .. '_generic']) ~= nil
end

--- The names of a picked medication, for the screens.
-- @param pick table  What medication_pick.read returned, with no problem.
-- @return string|nil, string|nil  The short name and the full name. For a new
--         medication, both are built from its fields the way the catalog builds them.
function medication_pick.names(pick)
  if pick.new_row then
    local row = pick.new_row
    return row.short_name, medication_name.full(row.generic_name, row.brand_name, row.strength,
                                                row.route, row.form, row.package_size, row.package_type)
  end
  if not pick.id then return nil, nil end
  local row = pv.query1('SELECT short_name, full_name FROM v_medication WHERE medication_id = ?', { pick.id })
  if not row then return nil, nil end
  return row.short_name, row.full_name
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
