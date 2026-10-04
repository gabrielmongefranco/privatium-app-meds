-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/authorizations.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-03
-- Summary: The screens for prior authorizations: the list, and the form that adds, changes or
--          removes one for a tracked medication.
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
local clock           = require 'clock'
local entries         = require 'entries'
local medication_pick = require 'medication_pick'
local page            = require 'page'
local people_filter   = require 'people_filter'
local quick_add       = require 'quick_add'
local store           = require 'store'
local suggestions     = require 'suggestions'
local catalog_entry   = require 'catalog_entry'
local starter         = require 'starter'
local text            = require 'text'
local validate        = require 'validate'

--- Configuration ---
local LIST      = '/authorizations'
local NEW_ENTRY = 'new'   -- The choice of the medication drop-down that finds or adds one
local FIELDS    = { 'entry_id', 'person_id', 'medication_id', 'valid_from', 'valid_to' }
-- A product with an approval and no tracked medication is one the person is about to start.
local STATUS_OF_NEW_ENTRY = 'not_started'

--- Reads ---

-- Grain: one row per prior authorization, with its state on today's local date.
local function everything(person_id)
  return pv.query([[
    SELECT pa.id, pa.valid_from, pa.valid_to,
           p.display_name  AS person_name,
           pm.display_name AS medication_name,
           CASE WHEN pa.valid_to < date('now', 'localtime') THEN 'Expired'
                WHEN pa.valid_from > date('now', 'localtime') THEN 'Not started'
                WHEN pa.valid_to = date('now', 'localtime') THEN 'Due: expires today'
                WHEN pa.valid_to <= date('now', 'localtime', '+' || r.authorization_due_within_days || ' days')
                THEN 'Due: expires in ' || CAST(julianday(pa.valid_to) - julianday(date('now', 'localtime')) AS INTEGER) || ' days'
                WHEN pa.valid_to <= date('now', 'localtime', '+' || r.authorization_notice_days || ' days')
                THEN 'Due soon: expires in ' || CAST(julianday(pa.valid_to) - julianday(date('now', 'localtime')) AS INTEGER) || ' days'
                ELSE 'Active' END AS state
      FROM prior_authorization pa
      JOIN person_medication pm ON pm.id = pa.person_medication_id   -- many:1
      JOIN person p     ON p.id = pm.person_id                        -- many:1
     CROSS JOIN v_reminder_setting r                                  -- exactly one row
     WHERE ?1 = '' OR pm.person_id = ?1
     ORDER BY pa.valid_to DESC, pa.id]], { person_id })
end

-- Every tracked medication, for the drop-down of the form.
-- Grain: one row per person_medication row, by person and then by name.
local function listed()
  local options = {}
  for _, row in ipairs(pv.query([[
      SELECT pm.id, p.display_name || ': ' || pm.display_name AS label
        FROM person_medication pm
        JOIN person p ON p.id = pm.person_id   -- many:1
       ORDER BY p.display_name COLLATE NOCASE, pm.display_name COLLATE NOCASE, pm.id]])) do
    options[#options + 1] = { value = row.id, label = row.label }
  end
  return options
end

-- A tracked medication with its person, or nil.
local function listed_one(id)
  return id and pv.query1([[
    SELECT pm.id, pm.display_name, pm.person_id, p.display_name AS person_name
      FROM person_medication pm
      JOIN person p ON p.id = pm.person_id   -- many:1
     WHERE pm.id = ?]], { id }) or nil
end

--- Validation ---

-- Reads an authorization with the records it may add beside it: a person, a product
-- and the tracked medication.
-- @return table, table, table  The row, the problems, and what to add in the batch.
local function read(form, fixed_entry)
  local row, errors, adding = {}, {}, {}
  local chosen = text.clean(form.entry_id)
  if fixed_entry then
    adding.entry_id = fixed_entry.id
  elseif chosen and chosen ~= NEW_ENTRY then
    if entries.stored(chosen) then adding.entry_id = chosen
    else errors.entry_id = 'Choose a medication from the list.' end
  else
    adding.person_id, adding.person, errors.person_id =
      quick_add.read(form, 'person_id', quick_add.PERSON, true)
    adding.pick = medication_pick.read(form, 'medication', true)
    errors.medication_id = adding.pick.problem
    local found = entries.with_product(adding.person_id, adding.pick.id)
    if found then adding.entry_id = found.id end
    if not adding.entry_id and not errors.entry_id and not errors.person_id and not errors.medication_id
       and not adding.person_id and not adding.person then
      errors.entry_id = 'Choose a medication from the list, or choose Another medication.'
    end
  end
  row.person_medication_id = adding.entry_id

  -- Only the expiration date is required. A renewal notice often names no first day.
  row.valid_from, errors.valid_from = validate.date(form.valid_from, 'the first day')
  row.valid_to, errors.valid_to = validate.date(form.valid_to, 'the expiration date', true)
  if row.valid_from and row.valid_to and row.valid_to < row.valid_from then
    errors.valid_from = 'Choose a first day that is the expiration date or earlier, or leave it empty.'
  end
  return row, errors, adding
end

-- Writes an authorization and the new records beside it in one batch. A product that
-- is on no list of the person is added to it, named after the product, so the Refills
-- page can warn when the authorization ends.
-- @return boolean, string|nil  True, or false and a message.
local function save(id, row, adding)
  return store.together('prior_authorization', function(tx)
    if not adding.entry_id then
      local person_id = quick_add.write(tx, quick_add.PERSON, adding.person_id, adding.person)
      local _, full_name = medication_pick.names(adding.pick)
      local product_id = medication_pick.write(tx, adding.pick)
      row.person_medication_id = entries.add(tx, {
        person_id = person_id, medication_id = product_id, display_name = full_name,
        status = STATUS_OF_NEW_ENTRY, refills_left = 0,
      })
    end
    if id then tx.append('prior_authorization', id, row)
    else tx.append('prior_authorization', row) end
  end)
end

local function form_page(heading, action, typed, errors, entry, pick)
  return pv.render('authorization_form', {
    section   = 'authorizations',
    heading   = heading,
    action    = action,
    typed     = typed,
    errors    = errors,
    problems  = page.problems(errors, FIELDS),
    entry     = entry,
    pick      = pick,
    listed   = not entry and listed() or {},
    new_entry = NEW_ENTRY,
    people    = quick_add.options(quick_add.PERSON),
    names     = not entry and suggestions.medication_names() or {},
    catalog_options = not entry and catalog_entry.options() or { route = {}, dose_form = {}, package_type = {} },
  })
end

--- Routes ---

pv.get(LIST, function(req)
  local filter = people_filter.read(req)
  return pv.render('authorizations', {
    section        = 'authorizations',
    notice         = page.notice(req.query.notice),
    filter         = filter,
    authorizations = everything(filter.id),
  })
end)

-- The form can start from a tracked medication, which names the person too.
pv.get(LIST .. '/new', function(req)
  starter.ensure()
  return form_page('Add a prior authorization', url(LIST .. '/new'), {
    entry_id   = text.clean(req.query.entry),
    person_id  = text.clean(req.query.person),
    -- Most approvals start with a month and run for a year, so the form starts there.
    valid_from = clock.month_start(),
    valid_to   = clock.month_start_next_year(),
  }, {})
end)

pv.post(LIST .. '/new', function(req)
  local row, errors, adding = read(req.form)
  if not next(errors) then
    local saved, refusal = save(nil, row, adding)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.valid_to = refusal
  end
  return form_page('Add a prior authorization', url(LIST .. '/new'), req.form, errors, nil, adding.pick)
end)

pv.get(LIST .. '/:id/edit', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  return form_page('Change a prior authorization',
    url(LIST .. '/' .. authorization.id .. '/edit'), authorization, {},
    listed_one(authorization.person_medication_id))
end)

pv.post(LIST .. '/:id/edit', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  -- The tracked medication of an authorization does not change in this form.
  local entry = listed_one(authorization.person_medication_id)
  local row, errors, adding = read(req.form, entry)
  if not next(errors) then
    local saved, refusal = save(authorization.id, row, adding)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.valid_to = refusal
  end
  return form_page('Change a prior authorization',
    url(LIST .. '/' .. authorization.id .. '/edit'), req.form, errors, entry)
end)

pv.get(LIST .. '/:id/remove', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'authorizations',
    heading = 'Remove a prior authorization',
    name    = 'the prior authorization that expires on ' .. authorization.valid_to,
    used_by = {},
    action  = url(LIST .. '/' .. authorization.id .. '/remove'),
    back    = url(LIST),
  })
end)

pv.post(LIST .. '/:id/remove', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  pv.delete('prior_authorization', authorization.id)
  return pv.redirect(url(LIST .. '?notice=removed'))
end)
