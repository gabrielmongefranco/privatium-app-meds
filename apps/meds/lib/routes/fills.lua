-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/fills.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The screens for fills: the history with its totals, and the form that records,
--          changes or removes a fill.
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
local clock             = require 'clock'
local entries           = require 'entries'
local fills             = require 'fills'
local medication_pick   = require 'medication_pick'
local page              = require 'page'
local people_filter     = require 'people_filter'
local quick_add         = require 'quick_add'
local store             = require 'store'
local suggestions       = require 'suggestions'
local text              = require 'text'
local validate          = require 'validate'

--- Configuration ---
local LIST      = '/fills'
local PAGE_SIZE = 50
local FIELDS    = { 'person_id', 'medication_id', 'filled_on', 'pharmacy_id', 'days_supply',
                    'quantity', 'amount_paid', 'refills_left', 'rx_number', 'insurance_plan',
                    'insurance_claim_number', 'notes' }

--- Reads ---

local function as_options(rows)
  local options = {}
  for _, row in ipairs(rows) do options[#options + 1] = { value = row.id, label = row.label } end
  return options
end

local function people() return quick_add.options(quick_add.PERSON) end

local function pharmacies() return quick_add.options(quick_add.PHARMACY) end

local function medication(id)
  return pv.query1(
    'SELECT medication_id, short_name, full_name FROM v_medication WHERE medication_id = ?',
    { id or '' })
end

-- What a new fill starts with: the values of the last fill of the same medication for
-- the same person. The quantity is read from the fill itself, because the views leave
-- out the decimal columns.
local function starting_values(person_id, medication_id)
  local last = person_id and pv.query1([[
    SELECT l.pharmacy_id, l.days_supply, l.rx_number, l.insurance_plan, f.quantity
      FROM v_last_fill l
      JOIN fill f ON f.id = l.fill_id    -- 1:1
     WHERE l.person_id = ? AND l.medication_id = ?]], { person_id, medication_id }) or {}
  local entry = person_id and entries.of(person_id, medication_id)
  last.pharmacy_id = last.pharmacy_id or (entry and entry.pharmacy_id)
  last.refills_left = entry and math.max(entry.refills_left - 1, 0) or nil
  last.person_id, last.medication_id = person_id, medication_id
  last.quantity = text.plain_number(last.quantity)
  last.filled_on = clock.today()
  return last
end

-- The filters of the history, read from the page address. A value that names nothing
-- counts as no filter.
local function history_filters(req)
  local year = text.clean(req.query.year) or ''
  if not year:match('^%d%d%d%d$') then year = '' end
  local page_number = math.tointeger(tonumber(req.query.page) or 1) or 1
  if page_number < 1 then page_number = 1 end
  return {
    medication = text.clean(req.query.medication) or '',
    pharmacy   = text.clean(req.query.pharmacy) or '',
    year       = year,
    page       = page_number,
  }
end

-- The sentence after pasted fills were added. The page address carries a count only.
local function added_notice(count)
  if type(count) ~= 'string' or not count:match('^%d%d?%d?$') then return nil end
  return page.counted(math.tointeger(tonumber(count)), 'fill', 'fills') .. ' added.'
end

--- Pages ---

-- The form of a fill. `chosen` is the medication when the form is about one; without
-- it, the form holds the medication box, and `pick` is what the box answered.
local function form_page(heading, action, typed, errors, chosen, is_new, pick)
  local person_id = text.clean(typed.person_id)
  return pv.render('fill_form', {
    section    = 'history',
    heading    = heading,
    action     = action,
    typed      = typed,
    errors     = errors,
    problems   = page.problems(errors, FIELDS),
    medication = chosen,
    pick       = pick,
    in_use     = not chosen and medication_pick.in_use(text.clean(typed.medication_id)) or {},
    names      = not chosen and suggestions.medication_names() or {},
    plans      = suggestions.insurance_plans(),
    people     = people(),
    pharmacies = pharmacies(),
    is_new     = is_new,
    today      = clock.today(),
    on_list    = person_id ~= nil and chosen ~= nil
                 and entries.of(person_id, chosen.medication_id) ~= nil,
  })
end

-- Reads a fill with the records it may add beside it: a person, a pharmacy and, when
-- the form holds the medication box, a medication.
-- @return table, table, table  The row, the problems, and what to add in the batch.
local function read_with_new(form, fixed_medication_id)
  local adding, problems = {}, {}
  adding.person_id, adding.person, problems.person_id =
    quick_add.read(form, 'person_id', quick_add.PERSON, true)
  adding.pharmacy_id, adding.pharmacy, problems.pharmacy_id =
    quick_add.read(form, 'pharmacy_id', quick_add.PHARMACY, true)
  if fixed_medication_id then
    adding.pick = { id = fixed_medication_id }
  else
    adding.pick = medication_pick.read(form, 'medication', true)
    problems.medication_id = adding.pick.problem
  end

  local row, errors = fills.read(form, { person_id = true, pharmacy_id = true, medication_id = true })
  for field, problem in pairs(problems) do errors[field] = problem end
  row.person_id, row.pharmacy_id, row.medication_id =
    adding.person_id, adding.pharmacy_id, adding.pick.id
  return row, errors, adding
end

-- Adds the new records of a fill inside its batch and sets their ids on the fill.
local function write_new(adding)
  return function(tx, row)
    row.person_id   = quick_add.write(tx, quick_add.PERSON, adding.person_id, adding.person)
    row.pharmacy_id = quick_add.write(tx, quick_add.PHARMACY, adding.pharmacy_id, adding.pharmacy)
    row.medication_id = medication_pick.write(tx, adding.pick)
  end
end

--- Routes ---

pv.get(LIST, function(req)
  local filter = people_filter.read(req)
  local chosen = history_filters(req)
  local bound = { filter.id, chosen.medication, chosen.pharmacy, chosen.year }

  -- Grain: one row, the number of fills and the exact total paid under the filters.
  local total = pv.query1([[
    SELECT count(*) AS fills, decimal_sum(f.amount_paid) AS amount_paid
      FROM fill f
     WHERE (?1 = '' OR f.person_id = ?1)
       AND (?2 = '' OR f.medication_id = ?2)
       AND (?3 = '' OR f.pharmacy_id = ?3)
       AND (?4 = '' OR strftime('%Y', f.filled_on) = ?4)]], bound)

  local pages = math.max(1, math.ceil(total.fills / PAGE_SIZE))
  if chosen.page > pages then chosen.page = pages end
  bound[5], bound[6] = PAGE_SIZE, (chosen.page - 1) * PAGE_SIZE

  -- Grain: one row per fill under the filters, newest first, one page of them.
  local rows = pv.query([[
    SELECT f.id, f.filled_on, f.quantity, f.days_supply, f.amount_paid, f.rx_number,
           p.display_name AS person_name,
           m.short_name   AS medication_name,
           ph.name        AS pharmacy_name
      FROM fill f
      JOIN person p     ON p.id = f.person_id          -- many:1
      JOIN medication m ON m.id = f.medication_id      -- many:1
      LEFT JOIN pharmacy ph ON ph.id = f.pharmacy_id   -- many:0..1
     WHERE (?1 = '' OR f.person_id = ?1)
       AND (?2 = '' OR f.medication_id = ?2)
       AND (?3 = '' OR f.pharmacy_id = ?3)
       AND (?4 = '' OR strftime('%Y', f.filled_on) = ?4)
     ORDER BY f.filled_on DESC, f.id DESC
     LIMIT ?5 OFFSET ?6]], bound)

  -- Grain: one row per person per year with a fill.
  local spending = pv.query([[
    SELECT p.display_name AS person_name, s.year, s.fills, s.amount_paid
      FROM v_spending_by_year s
      JOIN person p ON p.id = s.person_id    -- many:1
     WHERE ?1 = '' OR s.person_id = ?1
     ORDER BY s.year DESC, p.display_name COLLATE NOCASE]], { filter.id })

  for _, row in ipairs(rows) do row.quantity = text.plain_number(row.quantity) end

  return pv.render('history', {
    section     = 'history',
    notice      = added_notice(req.query.added) or page.notice(req.query.notice),
    filter      = filter,
    chosen      = chosen,
    rows        = rows,
    total       = total,
    counted     = page.counted(total.fills, 'fill', 'fills'),
    pages       = pages,
    spending    = spending,
    medications = as_options(pv.query([[
      SELECT m.id, m.short_name AS label
        FROM medication m
       WHERE EXISTS (SELECT 1 FROM fill f WHERE f.medication_id = m.id)
       ORDER BY m.short_name COLLATE NOCASE, m.id]])),
    pharmacies  = pharmacies(),
    years       = pv.query(
      "SELECT DISTINCT strftime('%Y', filled_on) AS year FROM fill ORDER BY 1 DESC"),
  })
end)

-- Recording a fill starts from a list entry, or from a person and a medication. With
-- neither, the form holds the medication box.
pv.get(LIST .. '/new', function(req)
  local entry = req.query.entry and pv.get_row('person_medication', req.query.entry)
  local person_id = entry and entry.person_id or text.clean(req.query.person)
  local chosen = medication(entry and entry.medication_id or req.query.medication)
  if chosen then
    return form_page('Record a fill', url(LIST .. '/new?medication=' .. chosen.medication_id),
      starting_values(person_id, chosen.medication_id), {}, chosen, true)
  end
  return form_page('Record a fill', url(LIST .. '/new'),
    { person_id = person_id, filled_on = clock.today() }, {}, nil, true)
end)

pv.post(LIST .. '/new', function(req)
  -- The page address names the medication when the form is about one.
  local chosen = medication(req.query.medication)
  local row, errors, adding = read_with_new(req.form, chosen and chosen.medication_id)
  local refills_left
  refills_left, errors.refills_left = validate.whole_number(
    req.form.refills_left, 'the refills left', 0, fills.REFILLS_MAX)
  if not next(errors) then
    local saved, refusal = fills.save_new(row, refills_left, write_new(adding))
    if saved then return pv.redirect(url('/?filled=' .. saved)) end
    errors.filled_on = refusal
  end
  local action = url(LIST .. '/new' .. (chosen and ('?medication=' .. chosen.medication_id) or ''))
  return form_page('Record a fill', action, req.form, errors, chosen, true, adding.pick)
end)

pv.get(LIST .. '/:id/edit', function(req)
  local fill = pv.get_row('fill', req.params.id)
  if not fill then return pv.redirect(url(LIST .. '?notice=missing')) end
  fill.quantity = text.plain_number(fill.quantity)
  return form_page('Change a fill', url(LIST .. '/' .. fill.id .. '/edit'), fill, {},
    medication(fill.medication_id), false)
end)

pv.post(LIST .. '/:id/edit', function(req)
  local fill = pv.get_row('fill', req.params.id)
  if not fill then return pv.redirect(url(LIST .. '?notice=missing')) end
  -- The medication of a fill does not change in this form; a merge moves it.
  req.form.id = fill.id
  local row, errors, adding = read_with_new(req.form, fill.medication_id)
  if not next(errors) then
    local saved, refusal = store.together('fill', function(tx)
      write_new(adding)(tx, row)
      tx.append('fill', fill.id, row)
    end)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.filled_on = refusal
  end
  return form_page('Change a fill', url(LIST .. '/' .. fill.id .. '/edit'), req.form, errors,
    medication(fill.medication_id), false)
end)

pv.get(LIST .. '/:id/remove', function(req)
  local fill = pv.get_row('fill', req.params.id)
  if not fill then return pv.redirect(url(LIST .. '?notice=missing')) end
  local chosen = medication(fill.medication_id)
  return pv.render('remove', {
    section = 'history',
    heading = 'Remove a fill',
    name    = 'the fill of ' .. fill.filled_on .. (chosen and (', ' .. chosen.short_name) or ''),
    used_by = {},
    note    = 'The refills left of the medication do not change. Correct them on the page of the medication.',
    action  = url(LIST .. '/' .. fill.id .. '/remove'),
    back    = url(LIST),
  })
end)

pv.post(LIST .. '/:id/remove', function(req)
  local fill = pv.get_row('fill', req.params.id)
  if not fill then return pv.redirect(url(LIST .. '?notice=missing')) end
  pv.delete('fill', fill.id)
  return pv.redirect(url(LIST .. '?notice=removed'))
end)
