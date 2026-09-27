-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/authorizations.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The screens for prior authorizations: the list with the state of each one, and
--          the form that adds, changes or removes one.
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
local entries         = require 'entries'
local medication_pick = require 'medication_pick'
local page            = require 'page'
local people_filter   = require 'people_filter'
local quick_add       = require 'quick_add'
local store           = require 'store'
local suggestions     = require 'suggestions'
local text            = require 'text'
local validate        = require 'validate'

--- Configuration ---
local LIST   = '/authorizations'
local FIELDS = { 'person_id', 'medication_id', 'valid_to', 'valid_from' }
-- A medication with an approval and no list entry is one the person is about to start.
local STATUS_OF_NEW_ENTRY = 'not_started'

--- Reads ---

-- Grain: one row per prior authorization, with its state on today's local date.
local function everything(person_id)
  return pv.query([[
    SELECT pa.id, pa.valid_from, pa.valid_to,
           p.display_name AS person_name,
           m.short_name   AS medication_name,
           CASE WHEN pa.valid_to < date('now', 'localtime') THEN 'Ended'
                WHEN pa.valid_from > date('now', 'localtime') THEN 'Not started'
                WHEN pa.valid_to = date('now', 'localtime') THEN 'Ends today'
                WHEN pa.valid_to <= date('now', 'localtime', '+' || r.authorization_notice_days || ' days')
                THEN 'Ends in ' || CAST(julianday(pa.valid_to) - julianday(date('now', 'localtime')) AS INTEGER) || ' days'
                ELSE 'Active' END AS state
      FROM prior_authorization pa
      JOIN person p     ON p.id = pa.person_id        -- many:1
      JOIN medication m ON m.id = pa.medication_id    -- many:1
     CROSS JOIN v_reminder_setting r                  -- exactly one row
     WHERE ?1 = '' OR pa.person_id = ?1
     ORDER BY pa.valid_to DESC, pa.id]], { person_id })
end

--- Validation ---

-- Reads an authorization with the records it may add beside it: a person and a
-- medication.
-- @return table, table, table  The row, the problems, and what to add in the batch.
local function read(form)
  local row, errors, adding = {}, {}, {}
  adding.person_id, adding.person, errors.person_id =
    quick_add.read(form, 'person_id', quick_add.PERSON, true)
  adding.pick = medication_pick.read(form, 'medication', true)
  errors.medication_id = adding.pick.problem
  row.person_id, row.medication_id = adding.person_id, adding.pick.id

  -- Only the last day is required. A renewal notice often names no first day.
  row.valid_to, errors.valid_to = validate.date(form.valid_to, 'the last day', true)
  row.valid_from, errors.valid_from = validate.date(form.valid_from, 'the first day')
  if row.valid_from and row.valid_to and row.valid_to < row.valid_from then
    errors.valid_from = 'Choose a first day that is the last day or earlier, or leave it empty.'
  end
  return row, errors, adding
end

-- Writes an authorization and the new records beside it in one batch. A medication
-- that is not on the list of the person is added to it, so the Refills page can warn
-- when the authorization ends.
-- @return boolean, string|nil  True, or false and a message.
local function save(id, row, adding)
  return store.together('prior_authorization', function(tx)
    row.person_id     = quick_add.write(tx, quick_add.PERSON, adding.person_id, adding.person)
    row.medication_id = medication_pick.write(tx, adding.pick)
    local on_list = adding.person_id and adding.pick.id
      and entries.of(adding.person_id, adding.pick.id)
    if not on_list then
      tx.append('person_medication', {
        person_id = row.person_id, medication_id = row.medication_id,
        status = STATUS_OF_NEW_ENTRY, refills_left = 0,
      })
    end
    if id then tx.append('prior_authorization', id, row)
    else tx.append('prior_authorization', row) end
  end)
end

local function form_page(heading, action, typed, errors, pick)
  return pv.render('authorization_form', {
    section  = 'authorizations',
    heading  = heading,
    action   = action,
    typed    = typed,
    errors   = errors,
    problems = page.problems(errors, FIELDS),
    pick     = pick,
    people   = quick_add.options(quick_add.PERSON),
    in_use   = medication_pick.in_use(text.clean(typed.medication_id)),
    names    = suggestions.medication_names(),
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

-- The form can start from a list entry, which names the person and the medication.
pv.get(LIST .. '/new', function(req)
  local entry = req.query.entry and pv.get_row('person_medication', req.query.entry)
  return form_page('Add a prior authorization', url(LIST .. '/new'), {
    person_id     = entry and entry.person_id or text.clean(req.query.person),
    medication_id = entry and entry.medication_id,
  }, {})
end)

pv.post(LIST .. '/new', function(req)
  local row, errors, adding = read(req.form)
  if not next(errors) then
    local saved, refusal = save(nil, row, adding)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.valid_to = refusal
  end
  return form_page('Add a prior authorization', url(LIST .. '/new'), req.form, errors, adding.pick)
end)

pv.get(LIST .. '/:id/edit', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  return form_page('Change a prior authorization',
    url(LIST .. '/' .. authorization.id .. '/edit'), authorization, {})
end)

pv.post(LIST .. '/:id/edit', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  local row, errors, adding = read(req.form)
  if not next(errors) then
    local saved, refusal = save(authorization.id, row, adding)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.valid_to = refusal
  end
  return form_page('Change a prior authorization',
    url(LIST .. '/' .. authorization.id .. '/edit'), req.form, errors, adding.pick)
end)

pv.get(LIST .. '/:id/remove', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'authorizations',
    heading = 'Remove a prior authorization',
    name    = 'the prior authorization that ends on ' .. authorization.valid_to,
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
