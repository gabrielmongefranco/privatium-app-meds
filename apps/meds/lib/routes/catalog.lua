-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/catalog.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The screens of the medication catalog: search, show, add, change, remove,
--          other names, and the merge of two entries that are the same product.
--          A catalog entry is a product; what a person takes is kept elsewhere.
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
local medication_name = require 'medication_name'
local medication_search = require 'medication_search'
local merge           = require 'merge'
local page            = require 'page'
local store           = require 'store'
local text            = require 'text'
local validate        = require 'validate'

--- Configuration ---
local LIST         = '/setup/catalog'
local NAME_MAX     = 200   -- Generic names of products with several drugs run long
local STRENGTH_MAX = 60
local CHOICE_MAX   = 60
local PACKAGE_MAX  = 40
local FIELDS       = { 'brand_name', 'generic_name', 'strength', 'route', 'dose_form',
                       'package_size', 'package_type', 'short_name' }

--- Reads ---

-- Grain: one row per medication.
local function everything()
  return pv.query([[
    SELECT medication_id, short_name, full_name, is_specialty
      FROM v_medication
     ORDER BY short_name COLLATE NOCASE, medication_id]])
end

-- Grain: one row, the medication with its built full name, or nil.
local function one(id)
  return pv.query1([[
    SELECT medication_id, short_name, full_name, generic_name, brand_name, strength,
           route, form, package_size, package_type, is_specialty
      FROM v_medication
     WHERE medication_id = ?]], { id })
end

-- Grain: one row per other name of one medication.
local function other_names(id)
  return pv.query([[
    SELECT id, alias
      FROM medication_alias
     WHERE medication_id = ?
     ORDER BY alias COLLATE NOCASE, id]], { id })
end

local function values_of(rows)
  local values = {}
  for _, row in ipairs(rows) do values[#values + 1] = row.value end
  return values
end

-- The choices of each drop-down: the starter list, then every value already in use.
local function options()
  return {
    route = choices.merge(choices.ROUTES, values_of(pv.query(
      'SELECT DISTINCT route AS value FROM medication WHERE route IS NOT NULL'))),
    dose_form = choices.merge(choices.FORMS, values_of(pv.query(
      'SELECT DISTINCT form AS value FROM medication WHERE form IS NOT NULL'))),
    package_type = choices.merge(choices.PACKAGE_TYPES, values_of(pv.query(
      'SELECT DISTINCT package_type AS value FROM medication WHERE package_type IS NOT NULL'))),
  }
end

-- The schema cannot declare a short name unique, so the check happens here.
local function short_name_taken(name, except_id)
  local key = text.key(name)
  for _, row in ipairs(pv.query('SELECT id, short_name FROM medication')) do
    if row.id ~= except_id and text.key(row.short_name) == key then return true end
  end
  return false
end

-- How many records still point to a medication, as phrases for the removal page.
local function uses(id)
  local counts = pv.query1([[
    SELECT (SELECT count(*) FROM person_medication   WHERE medication_id = ?1) AS lists,
           (SELECT count(*) FROM fill                WHERE medication_id = ?1) AS fills,
           (SELECT count(*) FROM prior_authorization WHERE medication_id = ?1) AS authorizations]],
    { id })
  local list = {}
  if counts.lists > 0 then
    list[#list + 1] = page.counted(counts.lists, "person's list", "people's lists")
  end
  if counts.fills > 0 then list[#list + 1] = page.counted(counts.fills, 'fill', 'fills') end
  if counts.authorizations > 0 then
    list[#list + 1] = page.counted(counts.authorizations, 'prior authorization', 'prior authorizations')
  end
  return list
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
    if not value then return nil, problem end
  end
  local key = text.key(value)
  for _, choice in ipairs(offered) do
    if text.key(choice) == key then return choice end
  end
  return value
end

local function read(form, existing, offered)
  local row, errors = {}, {}
  row.brand_name,   errors.brand_name   = validate.text(form.brand_name, 'the brand name', NAME_MAX)
  row.generic_name, errors.generic_name = validate.text(form.generic_name, 'the generic name', NAME_MAX)
  row.strength,     errors.strength     = validate.text(form.strength, 'the strength', STRENGTH_MAX)
  row.package_size, errors.package_size = validate.text(form.package_size, 'the package size', PACKAGE_MAX)
  row.route, errors.route = read_choice(form, 'route', 'the route', offered.route)
  row.form,  errors.dose_form = read_choice(form, 'dose_form', 'the form', offered.dose_form)
  row.package_type, errors.package_type =
    read_choice(form, 'package_type', 'the package type', offered.package_type)
  row.is_specialty = form.is_specialty == 'yes'

  if not row.brand_name and not row.generic_name
     and not errors.brand_name and not errors.generic_name then
    errors.brand_name = 'Enter a brand name or a generic name.'
  end

  -- A short name that was built by the app follows the parts it was built from. One
  -- that a person typed stays as typed.
  local typed, problem = validate.text(form.short_name, 'the short name', NAME_MAX)
  local built_before = existing
    and medication_name.short(existing.brand_name, existing.generic_name, existing.strength)
  if problem then
    errors.short_name = problem
  elseif typed and typed ~= built_before then
    row.short_name = typed
  else
    row.short_name = medication_name.short(row.brand_name, row.generic_name, row.strength)
  end

  if row.short_name and short_name_taken(row.short_name, existing and existing.medication_id) then
    errors.short_name = 'Choose another short name. A medication with this one is already in the catalog.'
  end
  return row, errors
end

-- What the form shows for a stored medication. The form field for the dose form is
-- called dose_form, because a field called form would shadow the form itself.
local function as_typed(medication)
  local typed = {}
  for key, value in pairs(medication) do typed[key] = value end
  typed.dose_form = medication.form
  typed.is_specialty = medication.is_specialty and 'yes' or nil
  return typed
end

local function form_page(heading, action, typed, errors, offered)
  return pv.render('medication_form', {
    section  = 'setup',
    heading  = heading,
    action   = action,
    typed    = typed,
    errors   = errors,
    problems = page.problems(errors, FIELDS),
    offered  = offered,
  })
end

--- Routes ---

pv.get(LIST, function(req)
  local typed = medication_search.typed(req.query.q)
  local found = medication_search.find(typed)
  local medications = typed == '' and everything() or found.matches
  return pv.render('catalog', {
    section     = 'setup',
    notice      = page.notice(req.query.notice),
    filter      = typed,
    medications = medications,
    close       = found.close,
    exact       = found.exact,
    found       = page.counted(#medications, 'medication', 'medications'),
  })
end)

-- Registered before the routes that take an id, so 'new' is never read as one.
pv.get(LIST .. '/new', function()
  return form_page('Add a medication', url(LIST .. '/new'), {}, {}, options())
end)

pv.post(LIST .. '/new', function(req)
  local offered = options()
  local row, errors = read(req.form, nil, offered)
  if not next(errors) then
    local saved, refusal = store.save('medication', nil, row)
    if saved then return pv.redirect(url(LIST .. '/' .. saved .. '?notice=saved')) end
    errors.brand_name = refusal
  end
  return form_page('Add a medication', url(LIST .. '/new'), req.form, errors, offered)
end)

pv.get(LIST .. '/:id', function(req)
  local medication = one(req.params.id)
  if not medication then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('medication', {
    section     = 'setup',
    notice      = page.notice(req.query.notice),
    medication  = medication,
    other_names = other_names(medication.medication_id),
  })
end)

pv.get(LIST .. '/:id/edit', function(req)
  local medication = one(req.params.id)
  if not medication then return pv.redirect(url(LIST .. '?notice=missing')) end
  return form_page('Change a medication', url(LIST .. '/' .. medication.medication_id .. '/edit'),
                   as_typed(medication), {}, options())
end)

pv.post(LIST .. '/:id/edit', function(req)
  local medication = one(req.params.id)
  if not medication then return pv.redirect(url(LIST .. '?notice=missing')) end
  local offered = options()
  local row, errors = read(req.form, medication, offered)
  if not next(errors) then
    local saved, refusal = store.save('medication', medication.medication_id, row)
    if saved then return pv.redirect(url(LIST .. '/' .. saved .. '?notice=saved')) end
    errors.brand_name = refusal
  end
  return form_page('Change a medication', url(LIST .. '/' .. medication.medication_id .. '/edit'),
                   req.form, errors, offered)
end)

pv.get(LIST .. '/:id/remove', function(req)
  local medication = one(req.params.id)
  if not medication then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'setup',
    heading = 'Remove a medication',
    name    = medication.short_name,
    used_by = uses(medication.medication_id),
    action  = url(LIST .. '/' .. medication.medication_id .. '/remove'),
    back    = url(LIST .. '/' .. medication.medication_id),
  })
end)

pv.post(LIST .. '/:id/remove', function(req)
  local medication = one(req.params.id)
  if not medication then return pv.redirect(url(LIST .. '?notice=missing')) end
  local id = medication.medication_id
  -- A medication that other records point to stays, or those records would name nothing.
  if #uses(id) > 0 then return pv.redirect(url(LIST .. '/' .. id .. '/remove')) end

  -- The other names go with the medication, in one batch, so none is left pointing at
  -- a medication that is gone.
  local names = other_names(id)
  local removed = store.together('medication', function(tx)
    for _, name in ipairs(names) do tx.delete('medication_alias', name.id) end
    tx.delete('medication', id)
  end)
  if not removed then return pv.redirect(url(LIST .. '/' .. id .. '/remove')) end
  return pv.redirect(url(LIST .. '?notice=removed'))
end)

--- Other names ---

local function name_known(id, name)
  local key = text.key(name)
  for _, row in ipairs(pv.query('SELECT name FROM v_medication_name WHERE medication_id = ?', { id })) do
    if text.key(row.name) == key then return true end
  end
  return false
end

pv.post(LIST .. '/:id/names', function(req)
  local medication = one(req.params.id)
  if not medication then return pv.redirect(url(LIST .. '?notice=missing')) end
  local id = medication.medication_id
  local alias, problem = validate.text(req.form.alias, 'the other name', NAME_MAX, true)
  if alias and name_known(id, alias) then
    problem = 'Type another name. This medication already answers to that one.'
  end
  if not problem then
    local saved, refusal = store.save('medication_alias', nil, { medication_id = id, alias = alias })
    if saved then return pv.redirect(url(LIST .. '/' .. id .. '?notice=named')) end
    problem = refusal
  end
  return pv.render('medication', {
    section     = 'setup',
    medication  = medication,
    other_names = other_names(id),
    typed_alias = req.form.alias,
    alias_err   = problem,
  })
end)

pv.get(LIST .. '/:id/names/:name_id/remove', function(req)
  local medication = one(req.params.id)
  local alias = pv.get_row('medication_alias', req.params.name_id)
  if not medication or not alias or alias.medication_id ~= medication.medication_id then
    return pv.redirect(url(LIST .. '?notice=missing'))
  end
  return pv.render('remove', {
    section = 'setup',
    heading = 'Remove another name',
    name    = alias.alias,
    used_by = {},
    action  = url(LIST .. '/' .. medication.medication_id .. '/names/' .. alias.id .. '/remove'),
    back    = url(LIST .. '/' .. medication.medication_id),
  })
end)

pv.post(LIST .. '/:id/names/:name_id/remove', function(req)
  local medication = one(req.params.id)
  local alias = pv.get_row('medication_alias', req.params.name_id)
  if not medication or not alias or alias.medication_id ~= medication.medication_id then
    return pv.redirect(url(LIST .. '?notice=missing'))
  end
  pv.delete('medication_alias', alias.id)
  return pv.redirect(url(LIST .. '/' .. medication.medication_id .. '?notice=removed'))
end)

--- Merge ---

-- The two medications of a merge, or nil when either is missing or both are the same.
local function pair(req)
  local source, target = one(req.params.id), one(req.params.target_id)
  if not source or not target or source.medication_id == target.medication_id then return nil end
  return source, target
end

-- What a plan will do, as sentences for the page that asks first.
local function sentences(plan)
  local list = {}
  local function add(count, singular, plural, ending)
    if count > 0 then list[#list + 1] = page.counted(count, singular, plural) .. ending end
  end
  add(#plan.fills, 'fill', 'fills', ' will move.')
  add(#plan.entries_moved, "entry on a person's list", "entries on people's lists", ' will move.')
  add(#plan.entries_dropped, "entry on a person's list", "entries on people's lists",
      ' will be removed, because that person has both medications on their list. The entry in use is kept.')
  add(#plan.authorizations, 'prior authorization', 'prior authorizations', ' will move.')
  add(#plan.aliases_moved + #plan.names_added, 'name', 'names', ' will become other names of the medication that stays.')
  return list
end

pv.get(LIST .. '/:id/merge', function(req)
  local source = one(req.params.id)
  if not source then return pv.redirect(url(LIST .. '?notice=missing')) end
  local typed = medication_search.typed(req.query.q)
  if typed == '' then typed = source.generic_name or source.brand_name or '' end
  local found = medication_search.find(typed)
  local candidates = {}
  for _, group in ipairs({ found.matches, found.close }) do
    for _, medication in ipairs(group) do
      if medication.medication_id ~= source.medication_id then
        candidates[#candidates + 1] = medication
      end
    end
  end
  return pv.render('merge_choose', {
    section = 'setup', source = source, filter = typed, candidates = candidates,
  })
end)

pv.get(LIST .. '/:id/merge/:target_id', function(req)
  local source, target = pair(req)
  if not source then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('merge_confirm', {
    section = 'setup', source = source, target = target,
    changes = sentences(merge.plan(source, target)),
  })
end)

pv.post(LIST .. '/:id/merge/:target_id', function(req)
  local source, target = pair(req)
  if not source then return pv.redirect(url(LIST .. '?notice=missing')) end
  local merged, refusal = merge.apply(merge.plan(source, target))
  if not merged then
    return pv.render('merge_confirm', {
      section = 'setup', source = source, target = target,
      changes = sentences(merge.plan(source, target)), err = refusal,
    })
  end
  return pv.redirect(url(LIST .. '/' .. target.medication_id .. '?notice=merged'))
end)
