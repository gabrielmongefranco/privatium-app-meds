-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/people.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-03
-- Summary: The screens that list, add, change and remove the people of the household.
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
local page     = require 'page'
local quick_add = require 'quick_add'
local store    = require 'store'
local text     = require 'text'
local validate = require 'validate'

--- Configuration ---
local LIST     = '/setup/people'
local NAME_MAX = 120
local FIELDS   = { 'display_name', 'birth_date', 'plan_id' }

--- Reads ---

-- Grain: one row per person.
local function everyone()
  return pv.query([[
    SELECT id, display_name, birth_date
      FROM person
     ORDER BY display_name COLLATE NOCASE, id]])
end

-- The schema cannot declare a name unique, so the check happens here. Two names are
-- the same when they differ only by case, punctuation or spacing.
local function name_taken(name, except_id)
  local key = text.key(name)
  for _, row in ipairs(pv.query('SELECT id, display_name FROM person')) do
    if row.id ~= except_id and text.key(row.display_name) == key then return true end
  end
  return false
end

-- How many records still point to a person, as phrases for the removal page.
local function uses(id)
  local counts = pv.query1([[
    SELECT (SELECT count(*) FROM person_medication WHERE person_id = ?1) AS medications,
           (SELECT count(*) FROM fill f
             JOIN person_medication pm ON pm.id = f.person_medication_id
            WHERE pm.person_id = ?1) AS fills,
           (SELECT count(*) FROM prior_authorization pa
             JOIN person_medication pm ON pm.id = pa.person_medication_id
            WHERE pm.person_id = ?1) AS authorizations]],
    { id })
  local list = {}
  if counts.medications > 0 then
    list[#list + 1] = page.counted(counts.medications, 'medication on their list', 'medications on their list')
  end
  if counts.fills > 0 then
    list[#list + 1] = page.counted(counts.fills, 'fill', 'fills')
  end
  if counts.authorizations > 0 then
    list[#list + 1] = page.counted(counts.authorizations, 'prior authorization', 'prior authorizations')
  end
  return list
end

--- Validation ---

local function read(form, except_id)
  local row, errors = {}, {}
  row.display_name, errors.display_name =
    validate.text(form.display_name, 'the name', NAME_MAX, true)
  row.birth_date, errors.birth_date = validate.date(form.birth_date, 'the birth date')
  if row.birth_date then
    row.birth_date, errors.birth_date = validate.not_after(
      row.birth_date, clock.today(), 'Choose a birth date that is not in the future.')
  end
  if row.display_name and name_taken(row.display_name, except_id) then
    errors.display_name = 'Choose another name. A person with this name is already in the app.'
  end
  row.plan_id, row.new_plan, errors.plan_id = quick_add.read(form, 'plan_id', quick_add.PLAN)
  return row, errors
end

local function form_page(heading, action, typed, errors)
  return pv.render('person_form', {
    section  = 'setup',
    heading  = heading,
    action   = action,
    typed    = typed,
    errors   = errors,
    problems = page.problems(errors, FIELDS),
    today    = clock.today(),
    plans    = quick_add.options(quick_add.PLAN),
  })
end

local function save_person(id, row)
  local new_plan = row.new_plan
  row.new_plan = nil
  return store.together('person', function(tx)
    row.plan_id = quick_add.write(tx, quick_add.PLAN, row.plan_id, new_plan)
    tx.append('person', id, row)
  end)
end

--- Routes ---

pv.get(LIST, function(req)
  return pv.render('people', {
    section = 'setup',
    notice  = page.notice(req.query.notice),
    people  = everyone(),
  })
end)

pv.get(LIST .. '/new', function()
  return form_page('Add a family member', url(LIST .. '/new'), {}, {})
end)

pv.post(LIST .. '/new', function(req)
  local row, errors = read(req.form, nil)
  if not next(errors) then
    local saved, refusal = save_person(nil, row)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.display_name = refusal
  end
  return form_page('Add a family member', url(LIST .. '/new'), req.form, errors)
end)

pv.get(LIST .. '/:id/edit', function(req)
  local person = pv.get_row('person', req.params.id)
  if not person then return pv.redirect(url(LIST .. '?notice=missing')) end
  return form_page('Change a person', url(LIST .. '/' .. person.id .. '/edit'), person, {})
end)

pv.post(LIST .. '/:id/edit', function(req)
  local person = pv.get_row('person', req.params.id)
  if not person then return pv.redirect(url(LIST .. '?notice=missing')) end
  local row, errors = read(req.form, person.id)
  if not next(errors) then
    local saved, refusal = save_person(person.id, row)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.display_name = refusal
  end
  return form_page('Change a person', url(LIST .. '/' .. person.id .. '/edit'), req.form, errors)
end)

pv.get(LIST .. '/:id/remove', function(req)
  local person = pv.get_row('person', req.params.id)
  if not person then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'setup',
    heading = 'Remove a person',
    name    = person.display_name,
    used_by = uses(person.id),
    action  = url(LIST .. '/' .. person.id .. '/remove'),
    back    = url(LIST),
  })
end)

pv.post(LIST .. '/:id/remove', function(req)
  local person = pv.get_row('person', req.params.id)
  if not person then return pv.redirect(url(LIST .. '?notice=missing')) end
  -- A person that other records point to stays, or those records would name nobody.
  if #uses(person.id) > 0 then
    return pv.redirect(url(LIST .. '/' .. person.id .. '/remove'))
  end
  pv.delete('person', person.id)
  return pv.redirect(url(LIST .. '?notice=removed'))
end)
