-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/medications.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The screens for what each person takes: the lists, the page of one medication of
--          one person, the forms, and the list made for paper.
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
local choices           = require 'choices'
local clock             = require 'clock'
local entries           = require 'entries'
local medication_pick   = require 'medication_pick'
local page              = require 'page'
local people_filter     = require 'people_filter'
local quick_add         = require 'quick_add'
local store             = require 'store'
local suggestions       = require 'suggestions'
local text              = require 'text'
local validate          = require 'validate'

--- Configuration ---
local LIST         = '/medications'
local CHOICE_MAX   = 60
local PURPOSE_MAX  = 200
local INSTRUCT_MAX = 300
local REFILLS_MAX  = 99
local FIELDS       = { 'person_id', 'medication_id', 'status', 'medication_type', 'pharmacy_id',
                       'prescriber_id', 'prescribed_for', 'instructions', 'when_to_take',
                       'refills_left' }

--- Reads ---

local function values_of(rows)
  local values = {}
  for _, row in ipairs(rows) do values[#values + 1] = row.value end
  return values
end

-- Everything the entry form offers to choose from.
local function offered()
  return {
    people      = quick_add.options(quick_add.PERSON),
    pharmacies  = quick_add.options(quick_add.PHARMACY),
    prescribers = quick_add.options(quick_add.PRESCRIBER),
    purposes     = suggestions.purposes(),
    instructions = suggestions.instructions(),
    statuses = choices.STATUSES,
    medication_type = choices.merge(choices.MEDICATION_TYPES, values_of(pv.query(
      'SELECT DISTINCT medication_type AS value FROM person_medication WHERE medication_type IS NOT NULL'))),
    when_to_take = choices.merge(choices.TIMES_TO_TAKE, values_of(pv.query(
      'SELECT DISTINCT when_to_take AS value FROM person_medication WHERE when_to_take IS NOT NULL'))),
  }
end

-- Grain: one row per fill of one medication for one person, newest first.
local function fills_of(person_id, medication_id)
  return pv.query([[
    SELECT f.id, f.filled_on, f.quantity, f.days_supply, f.amount_paid, f.rx_number,
           ph.name AS pharmacy_name
      FROM fill f
      LEFT JOIN pharmacy ph ON ph.id = f.pharmacy_id   -- many:0..1
     WHERE f.person_id = ? AND f.medication_id = ?
     ORDER BY f.filled_on DESC, f.id DESC]], { person_id, medication_id })
end

-- Grain: one row, the number of fills and the exact total paid.
local function paid_for(person_id, medication_id)
  return pv.query1([[
    SELECT count(*) AS fills, decimal_sum(amount_paid) AS amount_paid
      FROM fill
     WHERE person_id = ? AND medication_id = ?]], { person_id, medication_id })
end

-- Grain: one row per prior authorization of one medication for one person, with its
-- state on today's local date.
local function authorizations_of(person_id, medication_id)
  return pv.query([[
    SELECT id, valid_from, valid_to,
           CASE WHEN valid_to < date('now', 'localtime') THEN 'Ended'
                WHEN valid_from > date('now', 'localtime') THEN 'Not started'
                ELSE 'Active' END AS state
      FROM prior_authorization
     WHERE person_id = ? AND medication_id = ?
     ORDER BY valid_to DESC, id]], { person_id, medication_id })
end

--- Validation ---

local function read_choice(form, name, label, list)
  local value, problem = validate.text(form[name .. '_new'], label, CHOICE_MAX)
  if problem then return nil, problem end
  if not value then
    value, problem = validate.text(form[name], label, CHOICE_MAX)
    if not value then return nil, problem end
  end
  local key = text.key(value)
  for _, choice in ipairs(list) do
    if text.key(choice) == key then return choice end
  end
  return value
end

-- Reads an entry with the records it may add beside it: a person, a medication, a
-- pharmacy and a prescriber.
-- @return table, table, table  The row, the problems, and what to add in the batch.
local function read(form, existing, lists)
  local row, errors, adding = {}, {}, {}
  if existing then
    -- The person and the medication of an entry never change. To move an entry, remove
    -- it and add another.
    row.person_id, row.medication_id = existing.person_id, existing.medication_id
    adding.person_id, adding.pick = existing.person_id, { id = existing.medication_id }
  else
    adding.person_id, adding.person, errors.person_id =
      quick_add.read(form, 'person_id', quick_add.PERSON, true)
    adding.pick = medication_pick.read(form, 'medication', true)
    errors.medication_id = adding.pick.problem
    row.person_id, row.medication_id = adding.person_id, adding.pick.id
  end

  row.status = text.clean(form.status)
  if not choices.status_label(row.status) then
    row.status, errors.status = nil, 'Choose a status.'
  end
  row.medication_type, errors.medication_type =
    read_choice(form, 'medication_type', 'the type', lists.medication_type)
  row.when_to_take, errors.when_to_take =
    read_choice(form, 'when_to_take', 'when to take it', lists.when_to_take)
  adding.pharmacy_id, adding.pharmacy, errors.pharmacy_id =
    quick_add.read(form, 'pharmacy_id', quick_add.PHARMACY)
  adding.prescriber_id, adding.prescriber, errors.prescriber_id =
    quick_add.read(form, 'prescriber_id', quick_add.PRESCRIBER)
  row.pharmacy_id, row.prescriber_id = adding.pharmacy_id, adding.prescriber_id
  row.prescribed_for, errors.prescribed_for =
    validate.text(form.prescribed_for, 'what it is for', PURPOSE_MAX)
  row.instructions, errors.instructions =
    validate.text(form.instructions, 'the instructions', INSTRUCT_MAX)
  row.refills_left, errors.refills_left =
    validate.whole_number(form.refills_left, 'the refills left', 0, REFILLS_MAX, true)

  if not existing and row.person_id and row.medication_id
     and entries.of(row.person_id, row.medication_id) then
    errors.medication_id = 'Choose another medication. This one is already on the list of this person.'
  end
  return row, errors, adding
end

-- Writes an entry and the new records beside it in one batch.
-- @return string|nil, string|nil  The id of the entry, or nil and a message.
local function save(id, row, adding)
  local entry_id
  local saved, refusal = store.together('person_medication', function(tx)
    row.person_id     = quick_add.write(tx, quick_add.PERSON, adding.person_id, adding.person)
    row.medication_id = medication_pick.write(tx, adding.pick)
    row.pharmacy_id   = quick_add.write(tx, quick_add.PHARMACY, adding.pharmacy_id, adding.pharmacy)
    row.prescriber_id =
      quick_add.write(tx, quick_add.PRESCRIBER, adding.prescriber_id, adding.prescriber)
    if id then
      tx.append('person_medication', id, row)
      entry_id = id
    else
      entry_id = tx.append('person_medication', row)
    end
  end)
  if not saved then return nil, refusal end
  return entry_id
end

-- The form of an entry. `medication` is set when the form is about a stored entry;
-- without it, the form holds the medication box, and `pick` is what the box answered.
local function form_page(heading, action, typed, errors, medication, fixed_person, pick)
  return pv.render('entry_form', {
    section      = 'medications',
    heading      = heading,
    action       = action,
    typed        = typed,
    errors       = errors,
    problems     = page.problems(errors, FIELDS),
    offered      = offered(),
    medication   = medication,
    fixed_person = fixed_person,
    pick         = pick,
    in_use       = not medication and medication_pick.in_use(text.clean(typed.medication_id)) or {},
    names        = not medication and suggestions.medication_names() or {},
  })
end

--- Routes ---

pv.get(LIST, function(req)
  local filter = people_filter.read(req)
  local groups, stopped = {}, {}
  for _, status in ipairs(choices.STATUSES) do
    groups[#groups + 1] = { status = status.value, title = status.label, rows = {} }
  end
  for _, row in ipairs(entries.list(filter.id)) do
    for _, group in ipairs(groups) do
      if group.status == row.status then group.rows[#group.rows + 1] = row end
    end
  end
  stopped = table.remove(groups)   -- 'No longer taking' is the last status
  return pv.render('medications', {
    section = 'medications',
    notice  = page.notice(req.query.notice),
    filter  = filter,
    groups  = groups,
    stopped = stopped,
  })
end)

-- Registered before the routes that take an id, so 'new' is never read as one.
pv.get(LIST .. '/new', function(req)
  return form_page('Add a medication to a list', url(LIST .. '/new'),
    { person_id = text.clean(req.query.person), medication_id = text.clean(req.query.medication),
      status = 'taking_regularly', refills_left = 0 }, {})
end)

pv.post(LIST .. '/new', function(req)
  local row, errors, adding = read(req.form, nil, offered())
  if not next(errors) then
    local saved, refusal = save(nil, row, adding)
    if saved then return pv.redirect(url(LIST .. '/' .. saved .. '?notice=saved')) end
    errors.status = refusal
  end
  return form_page('Add a medication to a list', url(LIST .. '/new'), req.form, errors, nil, nil,
    adding.pick)
end)

pv.get(LIST .. '/:id', function(req)
  local entry = entries.one(req.params.id)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('entry', {
    section        = 'medications',
    notice         = page.notice(req.query.notice),
    entry          = entry,
    statuses       = choices.STATUSES,
    medication     = pv.query1([[
      SELECT medication_id, short_name, full_name
        FROM v_medication WHERE medication_id = ?]], { entry.medication_id }),
    other_names    = pv.query([[
      SELECT alias FROM medication_alias
       WHERE medication_id = ? ORDER BY alias COLLATE NOCASE]], { entry.medication_id }),
    fills          = fills_of(entry.person_id, entry.medication_id),
    paid           = paid_for(entry.person_id, entry.medication_id),
    authorizations = authorizations_of(entry.person_id, entry.medication_id),
  })
end)

pv.get(LIST .. '/:id/edit', function(req)
  local stored = pv.get_row('person_medication', req.params.id)
  local entry = stored and entries.one(stored.id)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  return form_page('Change a medication on a list', url(LIST .. '/' .. stored.id .. '/edit'), stored, {},
    { medication_id = entry.medication_id, short_name = entry.medication_name }, entry.person_name)
end)

pv.post(LIST .. '/:id/edit', function(req)
  local stored = pv.get_row('person_medication', req.params.id)
  local entry = stored and entries.one(stored.id)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  local row, errors, adding = read(req.form, stored, offered())
  if not next(errors) then
    local saved, refusal = save(stored.id, row, adding)
    if saved then return pv.redirect(url(LIST .. '/' .. saved .. '?notice=saved')) end
    errors.status = refusal
  end
  return form_page('Change a medication on a list', url(LIST .. '/' .. stored.id .. '/edit'), req.form,
    errors, { medication_id = entry.medication_id, short_name = entry.medication_name },
    entry.person_name)
end)

-- A change of status alone, from the page of the entry. Every other column is carried
-- over, because an amendment replaces the whole row.
pv.post(LIST .. '/:id/status', function(req)
  local stored = pv.get_row('person_medication', req.params.id)
  if not stored then return pv.redirect(url(LIST .. '?notice=missing')) end
  local status = text.clean(req.form.status)
  if not choices.status_label(status) then
    return pv.redirect(url(LIST .. '/' .. stored.id))
  end
  local id = stored.id
  stored.id, stored.status = nil, status
  local saved = store.save('person_medication', id, stored)
  return pv.redirect(url(LIST .. '/' .. id .. (saved and '?notice=saved' or '')))
end)

pv.get(LIST .. '/:id/remove', function(req)
  local entry = entries.one(req.params.id)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'medications',
    heading = 'Remove a medication from a list',
    name    = entry.medication_name .. ', on the list of ' .. entry.person_name,
    used_by = {},
    note    = 'The fills and the prior authorizations stay. To keep the medication on the list as one no longer taken, change its status instead.',
    action  = url(LIST .. '/' .. entry.id .. '/remove'),
    back    = url(LIST .. '/' .. entry.id),
  })
end)

pv.post(LIST .. '/:id/remove', function(req)
  local stored = pv.get_row('person_medication', req.params.id)
  if not stored then return pv.redirect(url(LIST .. '?notice=missing')) end
  pv.delete('person_medication', stored.id)
  return pv.redirect(url(LIST .. '?notice=removed'))
end)

--- The list made for paper ---

pv.get('/people/:id/medication-list', function(req)
  local person = pv.get_row('person', req.params.id)
  if not person then return pv.redirect(url(LIST .. '?notice=missing')) end
  local taking, on_hold = {}, {}
  for _, row in ipairs(entries.list(person.id)) do
    if row.status == 'taking_regularly' or row.status == 'taking_as_needed' then
      taking[#taking + 1] = row
    elseif row.status == 'on_hold' then
      on_hold[#on_hold + 1] = row
    end
  end
  return pv.render('medication_list', {
    section = 'medications',
    person  = person,
    today   = clock.today(),
    taking  = taking,
    on_hold = on_hold,
  })
end)
