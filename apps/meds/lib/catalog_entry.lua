-- This file is part of Prescription Tracker
-- apps/meds/lib/catalog_entry.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The checks of a catalog entry, shared by the catalog form and by every form
--          that adds a medication beside its own record.
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

local pv              = require 'privatium'
local choices         = require 'choices'
local clock           = require 'clock'
local medication_name = require 'medication_name'
local text            = require 'text'
local validate        = require 'validate'

local catalog_entry = {}

--- Configuration ---
catalog_entry.NAME_MAX     = 200   -- Generic names of products with several drugs run long
catalog_entry.STRENGTH_MAX = 60
local CHOICE_MAX   = 60
local PACKAGE_MAX  = 40
local RXCUI_DIGITS = 8             -- RxNorm identifiers are whole numbers of up to 8 digits

-- The drug references a catalog row can be copied from. A row the owner typed has no
-- source. A value that is not listed here is refused, so a form cannot invent one.
catalog_entry.SOURCES = {
  rxterms     = 'RxTerms',
  rxnorm      = 'RxNorm',
  openfda_ndc = 'openFDA NDC Directory',
}

--- Reads ---

local function values_of(rows)
  local values = {}
  for _, row in ipairs(rows) do values[#values + 1] = row.value end
  return values
end

--- The choices of each drop-down of a catalog entry: the starter list, then every
-- value already in use.
-- @return table  { route = list, dose_form = list, package_type = list }
function catalog_entry.options()
  return {
    route = choices.merge(choices.ROUTES, values_of(pv.query(
      'SELECT DISTINCT route AS value FROM medication WHERE route IS NOT NULL'))),
    dose_form = choices.merge(choices.FORMS, values_of(pv.query(
      'SELECT DISTINCT form AS value FROM medication WHERE form IS NOT NULL'))),
    package_type = choices.merge(choices.PACKAGE_TYPES, values_of(pv.query(
      'SELECT DISTINCT package_type AS value FROM medication WHERE package_type IS NOT NULL'))),
  }
end

--- The medication that has a short name.
-- The schema cannot declare a short name unique, so forms ask here. Two names are the
-- same when they differ only by case, punctuation or spacing.
-- @param name string
-- @return string|nil  The id of the medication, or nil when no medication has the name.
function catalog_entry.with_short_name(name)
  local key = text.key(name)
  for _, row in ipairs(pv.query('SELECT id, short_name FROM medication ORDER BY id')) do
    if text.key(row.short_name) == key then return row.id end
  end
  return nil
end

--- The medication that was copied from a drug reference under an identifier.
-- @param rxcui string|nil
-- @return string|nil  The id of the medication, or nil.
function catalog_entry.with_rxcui(rxcui)
  if not rxcui then return nil end
  local found = pv.query1('SELECT id FROM medication WHERE rxcui = ? ORDER BY id LIMIT 1', { rxcui })
  return found and found.id
end

--- Validation ---

-- A choice comes from the drop-down or from the box under it. The box wins, because
-- typing is the more deliberate act. A typed value that matches a choice takes the
-- spelling of the choice, so 'oral' and 'Oral' stay one choice.
local function read_choice(form, name, label, offered)
  local value, problem = validate.text(form[name .. '_new'], label, CHOICE_MAX)
  if problem then return nil, problem end
  if not value then
    value, problem = validate.text(form[name], label, CHOICE_MAX)
    -- The choice to add, with nothing typed, adds nothing.
    if value == 'new' then value = nil end
    if not value then return nil, problem end
  end
  local key = text.key(value)
  for _, choice in ipairs(offered) do
    if text.key(choice) == key then return choice end
  end
  return value
end

local function read_rxcui(raw)
  local value = text.clean(raw)
  if not value then return nil end
  if not value:match('^%d+$') or #value > RXCUI_DIGITS then
    return nil, 'Write the RxNorm identifier with digits only, ' .. RXCUI_DIGITS .. ' or fewer.'
  end
  return value
end

--- Check the values of a catalog entry.
-- @param form table      The values as typed, keyed by field. The dose form is called
--        dose_form, because a field called form would shadow the form itself.
-- @param existing table|nil  The stored medication, as a row of v_medication, when the
--        form changes one.
-- @param offered table   What catalog_entry.options returned.
-- @return table, table, string|nil  The row for the log, with every column of the
--         table, and the problems keyed by field. The row is complete only when the
--         second table is empty. The third value is the id of the medication that
--         already has the short name or the RxNorm identifier, when one does; the
--         problems then say so under `short_name` or `rxcui`.
function catalog_entry.read(form, existing, offered)
  local row, errors = {}, {}
  local max = catalog_entry.NAME_MAX
  row.brand_name,   errors.brand_name   = validate.text(form.brand_name, 'the brand name', max)
  row.generic_name, errors.generic_name = validate.text(form.generic_name, 'the generic name', max)
  row.strength,     errors.strength     =
    validate.text(form.strength, 'the strength', catalog_entry.STRENGTH_MAX)
  row.package_size, errors.package_size = validate.text(form.package_size, 'the package size', PACKAGE_MAX)
  row.route, errors.route = read_choice(form, 'route', 'the route', offered.route)
  row.form,  errors.dose_form = read_choice(form, 'dose_form', 'the form', offered.dose_form)
  row.package_type, errors.package_type =
    read_choice(form, 'package_type', 'the package type', offered.package_type)
  row.is_specialty = form.is_specialty == 'yes'
  row.rxcui, errors.rxcui = read_rxcui(form.rxcui)

  -- Where the row came from travels with it, because an amendment replaces the whole
  -- row. A form can name a source only from the list above.
  local source = text.clean(form.source)
  if source and catalog_entry.SOURCES[source] then
    row.source, row.retrieved_on = source, clock.today()
  elseif existing then
    row.source, row.retrieved_on = existing.source, existing.retrieved_on
  end

  if not row.brand_name and not row.generic_name
     and not errors.brand_name and not errors.generic_name then
    errors.brand_name = 'Enter a brand name or a generic name.'
  end

  -- A short name that was built by the app follows the parts it was built from. One
  -- that a person typed stays as typed.
  local typed, problem = validate.text(form.short_name, 'the short name', max)
  local built_before = existing
    and medication_name.short(existing.brand_name, existing.generic_name, existing.strength)
  if problem then
    errors.short_name = problem
  elseif typed and typed ~= built_before then
    row.short_name = typed
  else
    row.short_name = medication_name.short(row.brand_name, row.generic_name, row.strength)
  end

  local own_id, same_as = existing and existing.medication_id, nil
  if row.short_name then
    local holder = catalog_entry.with_short_name(row.short_name)
    if holder and holder ~= own_id then
      errors.short_name = 'Choose another short name. A medication with this one is already in the catalog.'
      same_as = holder
    end
  end
  local copied = catalog_entry.with_rxcui(row.rxcui)
  if copied and copied ~= own_id then
    errors.rxcui = 'Check the RxNorm identifier. A medication with this one is already in the catalog.'
    same_as = copied
  end
  return row, errors, same_as
end

return catalog_entry
