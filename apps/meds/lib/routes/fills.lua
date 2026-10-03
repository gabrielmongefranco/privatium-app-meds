-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/fills.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-03
-- Summary: The screens for fills: the history with its totals, and the form that records,
--          changes or removes a fill of a tracked medication.
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
local starter           = require 'starter'
local text              = require 'text'
local validate          = require 'validate'
local form_icon         = require 'form_icon'

--- Configuration ---
local LIST      = '/fills'
local PAGE_SIZE = 50
local NEW_ENTRY = 'new'   -- The choice of the medication drop-down that finds or adds one
local FIELDS    = { 'entry_id', 'person_id', 'medication_id', 'product_id', 'filled_on', 'pharmacy_id',
                    'days_supply', 'quantity', 'amount_paid', 'refills_left', 'rx_number', 'plan_id',
                    'insurance_claim_number', 'notes' }
-- A fill for a product on no list adds the tracked medication with this status.
local STATUS_OF_NEW_ENTRY = 'taking_regularly'

--- Reads ---

local function as_options(rows)
  local options = {}
  for _, row in ipairs(rows) do options[#options + 1] = { value = row.id, label = row.label } end
  return options
end

local function people() return quick_add.options(quick_add.PERSON) end

local function pharmacies() return quick_add.options(quick_add.PHARMACY) end

-- Every tracked medication, for the drop-down of the fill form.
-- Grain: one row per person_medication row, by person and then by name.
local function listed()
  return as_options(pv.query([[
    SELECT pm.id, p.display_name || ': ' || pm.display_name AS label
      FROM person_medication pm
      JOIN person p ON p.id = pm.person_id   -- many:1
     ORDER BY p.display_name COLLATE NOCASE, pm.display_name COLLATE NOCASE, pm.id]]))
end

-- A tracked medication with its person and its products, or nil.
local function listed_one(id)
  local entry = id and pv.query1([[
    SELECT pm.id, pm.display_name, pm.person_id, pm.pharmacy_id, pm.refills_left,
           p.display_name AS person_name
      FROM person_medication pm
      JOIN person p ON p.id = pm.person_id   -- many:1
     WHERE pm.id = ?]], { id })
  if not entry then return nil end
  entry.products = entries.products(entry.id)
  return entry
end

-- The choices of the product drop-down of a tracked medication.
local function product_options(entry)
  local options = {}
  for _, product in ipairs(entry.products) do
    options[#options + 1] = { value = product.medication_id, label = product.short_name }
  end
  return options
end

-- What a new fill starts with: the values of the last fill of the tracked medication.
-- The quantity is read from the fill itself, because the views leave out the decimal
-- columns.
local function starting_values(entry)
  local last = pv.query1([[
    SELECT l.pharmacy_id, l.days_supply, l.rx_number, l.plan_id, l.medication_id, f.quantity
      FROM v_last_fill l
      JOIN fill f ON f.id = l.fill_id    -- 1:1
     WHERE l.person_medication_id = ?]], { entry.id }) or {}
  local person = pv.get_row('person', entry.person_id)
  last.plan_id = (person and person.plan_id) or last.plan_id
  last.pharmacy_id = last.pharmacy_id or entry.pharmacy_id
  last.refills_left = math.max(entry.refills_left - 1, 0)
  last.person_medication_id = entry.id
  -- The product of the last fill, or the one product of the tracked medication.
  last.product_id = last.medication_id or (entry.products[1] and #entry.products == 1 and entry.products[1].medication_id)
  last.medication_id = nil
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

-- The form of a fill. `entry` is the tracked medication when the form is about one;
-- without it, the form holds the drop-down of tracked medications and the medication
-- box, and `pick` is what the box answered.
local function form_page(heading, action, typed, errors, entry, is_new, pick)
  return pv.render('fill_form', {
    section    = 'history',
    heading    = heading,
    action     = action,
    typed      = typed,
    errors     = errors,
    problems   = page.problems(errors, FIELDS),
    entry      = entry,
    products   = entry and product_options(entry) or {},
    pick       = pick,
    listed    = not entry and listed() or {},
    new_entry  = NEW_ENTRY,
    names      = not entry and suggestions.medication_names() or {},
    plans      = quick_add.options(quick_add.PLAN),
    people     = people(),
    pharmacies = pharmacies(),
    is_new     = is_new,
    today      = clock.today(),
  })
end

-- Reads a fill with the records it may add beside it: a pharmacy, a plan and, when the
-- form holds the medication box, a person, a product and the tracked medication.
-- @return table, table, table  The row, the problems, and what to add in the batch.
local function read_with_new(form, fixed_entry)
  local adding, problems = {}, {}
  adding.pharmacy_id, adding.pharmacy, problems.pharmacy_id =
    quick_add.read(form, 'pharmacy_id', quick_add.PHARMACY, true)
  adding.plan_id, adding.plan, problems.plan_id =
    quick_add.read(form, 'plan_id', quick_add.PLAN)
  local chosen = text.clean(form.entry_id)
  if fixed_entry then
    adding.entry_id = fixed_entry.id
  elseif chosen and chosen ~= NEW_ENTRY then
    if entries.stored(chosen) then adding.entry_id = chosen
    else problems.entry_id = 'Choose a medication from the list.' end
  else
    -- A medication that is on no list: the person and the product name it, and the
    -- tracked medication is added with the fill, unless the person has it already.
    adding.person_id, adding.person, problems.person_id =
      quick_add.read(form, 'person_id', quick_add.PERSON, true)
    adding.pick = medication_pick.read(form, 'medication', true)
    problems.medication_id = adding.pick.problem
    local found = entries.with_product(adding.person_id, adding.pick.id)
    if found then adding.entry_id = found.id end
  end

  -- The product check needs the tracked medication, which the form may name only
  -- through the page address or the drop-down.
  local checked = {}
  for key, value in pairs(form) do checked[key] = value end
  checked.person_medication_id = adding.entry_id
  local row, errors = fills.read(checked, {
    person_medication_id = true, medication_id = not adding.entry_id, pharmacy_id = true, plan_id = true })
  for field, problem in pairs(problems) do errors[field] = problem end
  if adding.entry_id then
    row.person_medication_id = adding.entry_id
    if not row.medication_id and text.clean(form.product_id) and not errors.product_id then
      row.medication_id = text.clean(form.product_id)
    end
  end
  row.pharmacy_id, row.plan_id = adding.pharmacy_id, adding.plan_id
  return row, errors, adding
end

-- Adds the new records of a fill inside its batch and sets their ids on the fill. A
-- product on no list of the person gets a tracked medication, named after the product.
local function write_new(adding, status)
  return function(tx, row)
    row.pharmacy_id = quick_add.write(tx, quick_add.PHARMACY, adding.pharmacy_id, adding.pharmacy)
    row.plan_id = quick_add.write(tx, quick_add.PLAN, adding.plan_id, adding.plan)
    if adding.entry_id then return end
    local person_id = quick_add.write(tx, quick_add.PERSON, adding.person_id, adding.person)
    local _, full_name = medication_pick.names(adding.pick)
    local product_id = medication_pick.write(tx, adding.pick)
    row.medication_id = product_id
    row.new_entry = {
      person_id = person_id, medication_id = product_id, display_name = full_name,
      status = status, pharmacy_id = row.pharmacy_id,
    }
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
      JOIN person_medication pm ON pm.id = f.person_medication_id   -- many:1
     WHERE (?1 = '' OR pm.person_id = ?1)
       AND (?2 = '' OR f.person_medication_id = ?2)
       AND (?3 = '' OR f.pharmacy_id = ?3)
       AND (?4 = '' OR strftime('%Y', f.filled_on) = ?4)]], bound)

  local pages = math.max(1, math.ceil(total.fills / PAGE_SIZE))
  if chosen.page > pages then chosen.page = pages end
  bound[5], bound[6] = PAGE_SIZE, (chosen.page - 1) * PAGE_SIZE

  -- Grain: one row per fill under the filters, newest first, one page of them.
  local rows = pv.query([[
    SELECT f.id, f.filled_on, f.quantity, f.days_supply, f.amount_paid, f.rx_number,
           p.display_name  AS person_name,
           pm.display_name AS medication_name,
           m.short_name    AS product_name,
           m.route, m.form, m.package_type,
           ph.name         AS pharmacy_name,
           pl.name         AS plan_name
      FROM fill f
      JOIN person_medication pm ON pm.id = f.person_medication_id   -- many:1
      JOIN person p     ON p.id = pm.person_id         -- many:1
      LEFT JOIN medication m ON m.id = f.medication_id -- many:0..1
      LEFT JOIN pharmacy ph ON ph.id = f.pharmacy_id   -- many:0..1
      LEFT JOIN plan pl ON pl.id = f.plan_id           -- many:0..1
     WHERE (?1 = '' OR pm.person_id = ?1)
       AND (?2 = '' OR f.person_medication_id = ?2)
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

  for _, row in ipairs(rows) do
    row.quantity = text.plain_number(row.quantity)
    row.form_icon, row.form_label = form_icon.of(row.form, row.route, row.package_type)
  end

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
      SELECT pm.id, p.display_name || ': ' || pm.display_name AS label
        FROM person_medication pm
        JOIN person p ON p.id = pm.person_id   -- many:1
       WHERE EXISTS (SELECT 1 FROM fill f WHERE f.person_medication_id = pm.id)
       ORDER BY p.display_name COLLATE NOCASE, pm.display_name COLLATE NOCASE, pm.id]])),
    pharmacies  = pharmacies(),
    years       = pv.query(
      "SELECT DISTINCT strftime('%Y', filled_on) AS year FROM fill ORDER BY 1 DESC"),
  })
end)

-- Recording a fill starts from a tracked medication, or from the drop-down of them
-- with the medication box for one that is on no list yet.
pv.get(LIST .. '/new', function(req)
  starter.ensure()
  local entry = listed_one(text.clean(req.query.entry))
  if entry then
    return form_page('Record a fill', url(LIST .. '/new?entry=' .. entry.id),
      starting_values(entry), {}, entry, true)
  end
  local person_id = text.clean(req.query.person)
  return form_page('Record a fill', url(LIST .. '/new'),
    { person_id = person_id, filled_on = clock.today(),
      medication_id = text.clean(req.query.medication),
      plan_id = person_id and (pv.get_row('person', person_id) or {}).plan_id }, {}, nil, true)
end)

pv.post(LIST .. '/new', function(req)
  -- The page address names the tracked medication when the form is about one.
  local entry = listed_one(text.clean(req.query.entry))
  local row, errors, adding = read_with_new(req.form, entry)
  local refills_left
  refills_left, errors.refills_left = validate.whole_number(
    req.form.refills_left, 'the refills left', 0, fills.REFILLS_MAX)
  if not next(errors) then
    local saved, refusal = fills.save_new(row, refills_left, write_new(adding, STATUS_OF_NEW_ENTRY))
    if saved then return pv.redirect(url('/refills?filled=' .. saved)) end
    errors.filled_on = refusal
  end
  local action = url(LIST .. '/new' .. (entry and ('?entry=' .. entry.id) or ''))
  return form_page('Record a fill', action, req.form, errors, entry, true, adding.pick)
end)

-- The stored fill as the form shows it: its product under the field of the form.
local function as_typed(fill)
  fill.quantity = text.plain_number(fill.quantity)
  fill.product_id, fill.medication_id = fill.medication_id, nil
  return fill
end

pv.get(LIST .. '/:id/edit', function(req)
  local fill = pv.get_row('fill', req.params.id)
  if not fill then return pv.redirect(url(LIST .. '?notice=missing')) end
  return form_page('Change a fill', url(LIST .. '/' .. fill.id .. '/edit'), as_typed(fill), {},
    listed_one(fill.person_medication_id), false)
end)

pv.post(LIST .. '/:id/edit', function(req)
  local fill = pv.get_row('fill', req.params.id)
  if not fill then return pv.redirect(url(LIST .. '?notice=missing')) end
  -- The tracked medication of a fill does not change in this form.
  local entry = listed_one(fill.person_medication_id)
  req.form.id = fill.id
  local row, errors, adding = read_with_new(req.form, entry)
  if not next(errors) then
    local saved, refusal = store.together('fill', function(tx)
      write_new(adding)(tx, row)
      tx.append('fill', fill.id, row)
    end)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.filled_on = refusal
  end
  return form_page('Change a fill', url(LIST .. '/' .. fill.id .. '/edit'), req.form, errors, entry, false)
end)

pv.get(LIST .. '/:id/remove', function(req)
  local fill = pv.get_row('fill', req.params.id)
  if not fill then return pv.redirect(url(LIST .. '?notice=missing')) end
  local entry = listed_one(fill.person_medication_id)
  return pv.render('remove', {
    section = 'history',
    heading = 'Remove a fill',
    name    = 'the fill of ' .. fill.filled_on .. (entry and (', ' .. entry.display_name) or ''),
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
