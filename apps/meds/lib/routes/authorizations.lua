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

local pv            = require 'privatium'
local page          = require 'page'
local people_filter = require 'people_filter'
local store         = require 'store'
local text          = require 'text'
local validate      = require 'validate'

--- Configuration ---
local LIST   = '/authorizations'
local FIELDS = { 'entry_id', 'valid_from', 'valid_to' }

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

-- The medications an authorization can be for: every entry of every list.
-- Grain: one row per person_medication row.
local function entry_options()
  local options = {}
  for _, row in ipairs(pv.query([[
      SELECT pm.id, m.short_name || ', for ' || p.display_name AS label
        FROM person_medication pm
        JOIN person p     ON p.id = pm.person_id       -- many:1
        JOIN medication m ON m.id = pm.medication_id   -- many:1
       ORDER BY p.display_name COLLATE NOCASE, m.short_name COLLATE NOCASE, pm.id]])) do
    options[#options + 1] = { value = row.id, label = row.label }
  end
  return options
end

-- The list entry of the person and the medication of an authorization, for the form.
local function entry_of(authorization)
  local entry = pv.query1([[
    SELECT id
      FROM person_medication
     WHERE person_id = ? AND medication_id = ?
     ORDER BY id
     LIMIT 1]], { authorization.person_id, authorization.medication_id })
  return entry and entry.id
end

--- Validation ---

local function read(form)
  local row, errors = {}, {}
  local entry = pv.get_row('person_medication', text.clean(form.entry_id) or '')
  if entry then
    row.person_id, row.medication_id = entry.person_id, entry.medication_id
  else
    errors.entry_id = 'Choose a medication from the list.'
  end
  row.valid_from, errors.valid_from = validate.date(form.valid_from, 'the first day', true)
  row.valid_to, errors.valid_to = validate.date(form.valid_to, 'the last day', true)
  if row.valid_from and row.valid_to and row.valid_to < row.valid_from then
    errors.valid_to = 'Choose a last day that is the first day or later.'
  end
  return row, errors
end

local function form_page(heading, action, typed, errors)
  return pv.render('authorization_form', {
    section  = 'authorizations',
    heading  = heading,
    action   = action,
    typed    = typed,
    errors   = errors,
    problems = page.problems(errors, FIELDS),
    entries  = entry_options(),
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

pv.get(LIST .. '/new', function(req)
  return form_page('Add a prior authorization', url(LIST .. '/new'),
    { entry_id = text.clean(req.query.entry) }, {})
end)

pv.post(LIST .. '/new', function(req)
  local row, errors = read(req.form)
  if not next(errors) then
    local saved, refusal = store.save('prior_authorization', nil, row)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.valid_from = refusal
  end
  return form_page('Add a prior authorization', url(LIST .. '/new'), req.form, errors)
end)

pv.get(LIST .. '/:id/edit', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  authorization.entry_id = entry_of(authorization)
  return form_page('Change a prior authorization',
    url(LIST .. '/' .. authorization.id .. '/edit'), authorization, {})
end)

pv.post(LIST .. '/:id/edit', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  local row, errors = read(req.form)
  if not next(errors) then
    local saved, refusal = store.save('prior_authorization', authorization.id, row)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.valid_from = refusal
  end
  return form_page('Change a prior authorization',
    url(LIST .. '/' .. authorization.id .. '/edit'), req.form, errors)
end)

pv.get(LIST .. '/:id/remove', function(req)
  local authorization = pv.get_row('prior_authorization', req.params.id)
  if not authorization then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'authorizations',
    heading = 'Remove a prior authorization',
    name    = 'the prior authorization from ' .. authorization.valid_from
              .. ' to ' .. authorization.valid_to,
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
