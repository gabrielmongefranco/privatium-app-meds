-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/paste.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The screens that turn the pasted text of a portal page into fills: paste, review,
--          add. The text is untrusted; it is read again and checked again before anything is saved.
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
local fills             = require 'fills'
local match             = require 'match'
local medication_search = require 'medication_search'
local page              = require 'page'
local portal_reader     = require 'portal_reader'
local store             = require 'store'
local text              = require 'text'
local validate          = require 'validate'

--- Configuration ---
local PASTE           = '/fills/paste'
local PASTED_MAX      = 60000   -- Bytes. A Tier 1 request holds 64 KiB, and the form adds a little.
local SUGGESTIONS_MAX = 8       -- Medications offered for a name that is not known yet
local NEW_PHARMACY    = 'new'   -- The choice that adds the pharmacy from the pasted details
local NAME_MAX, ADDRESS_MAX, PHONE_MAX = 120, 200, 40

--- Reads ---

local function as_options(rows)
  local options = {}
  for _, row in ipairs(rows) do options[#options + 1] = { value = row.id, label = row.label } end
  return options
end

local function people()
  return as_options(pv.query(
    'SELECT id, display_name AS label FROM person ORDER BY display_name COLLATE NOCASE, id'))
end

-- Grain: one row per pharmacy.
local function pharmacies()
  return pv.query('SELECT id, name, npi FROM pharmacy ORDER BY name COLLATE NOCASE, id')
end

-- The pharmacy of a claim: by its identifier first, which cannot be misspelled, then
-- by its name.
local function pharmacy_of(claim, known)
  for _, pharmacy in ipairs(known) do
    if claim.pharmacy_npi and pharmacy.npi == claim.pharmacy_npi then return pharmacy.id end
  end
  local key = text.key(claim.pharmacy_name)
  for _, pharmacy in ipairs(known) do
    if key ~= '' and text.key(pharmacy.name) == key then return pharmacy.id end
  end
  return nil
end

-- Whether a medication already answers to a name.
local function answers_to(medication_id, name)
  for _, row in ipairs(pv.query(
      'SELECT name FROM v_medication_name WHERE medication_id = ?', { medication_id })) do
    if match.kind(name, row.name) == match.EXACT then return true end
  end
  return false
end

--- Review ---

-- Turns the claims of a pasted text into the rows of the review table. Each row says
-- what was read, what it matched, and whether it can be added.
local function review(claims, person_id, chosen)
  local known = pharmacies()
  local rows = {}
  for index, claim in ipairs(claims) do
    local row = { index = index, claim = claim, problems = {} }
    local picked = chosen['medication_' .. index]
    local suggestions, exact = {}, nil
    if claim.drug_name then
      suggestions, exact = medication_search.suggest(claim.drug_name, SUGGESTIONS_MAX)
    end
    row.suggestions = {}
    for _, medication in ipairs(suggestions) do
      row.suggestions[#row.suggestions + 1] =
        { value = medication.medication_id, label = medication.short_name }
    end
    row.medication_id = picked or (exact and exact.medication_id)
    row.known_name = exact ~= nil

    row.pharmacy_id = chosen['pharmacy_' .. index] or pharmacy_of(claim, known)
      or (claim.pharmacy_name and NEW_PHARMACY)

    local form = {
      person_id = person_id, medication_id = row.medication_id, pharmacy_id = row.pharmacy_id,
      filled_on = claim.filled_on, days_supply = claim.days_supply, quantity = claim.quantity,
      amount_paid = claim.amount_paid, rx_number = claim.rx_number,
    }
    local _, errors = fills.read(form, row.pharmacy_id == NEW_PHARMACY)
    for _, field in ipairs({ 'filled_on', 'days_supply', 'quantity', 'amount_paid', 'rx_number' }) do
      if errors[field] then row.problems[#row.problems + 1] = errors[field] end
    end

    if #row.problems > 0 then
      row.result, row.can_add = 'Could not read', false
    elseif claim.rx_number and claim.filled_on
           and fills.recorded(person_id, claim.rx_number, claim.filled_on) then
      row.result, row.can_add = 'Already recorded', false
    elseif #row.suggestions == 0 then
      row.result, row.can_add = 'Not in the catalog', false
    elseif not claim.details_open then
      row.result, row.can_add = 'Details missing', false
    elseif not row.medication_id then
      row.result, row.can_add = 'Choose a medication', true
    elseif not row.pharmacy_id then
      row.result, row.can_add = 'Choose a pharmacy', true
    elseif (claim.status or ''):lower() ~= 'paid' then
      row.result, row.can_add = 'Not paid', true
    else
      row.result, row.can_add, row.ready = 'Ready', true, true
    end
    rows[#rows + 1] = row
  end
  return rows, known
end

local function paste_page(typed, err)
  return pv.render('paste', {
    section = 'history', typed = typed, err = err, people = people(),
    notice = page.notice(typed.notice),
  })
end

-- Reads the person and the text of a request, or returns a message.
local function read_request(form)
  local person_id = text.clean(form.person_id)
  if not person_id or not pv.get_row('person', person_id) then
    return nil, nil, 'Choose the person the portal page belongs to.'
  end
  local pasted = form.pasted
  if type(pasted) ~= 'string' or not text.clean(pasted) then
    return nil, nil, 'Paste the text of the portal page into the box.'
  end
  if #pasted > PASTED_MAX then
    return nil, nil, 'Paste fewer fills at a time. The text is too long to read in one go.'
  end
  return person_id, pasted
end

--- Routes ---

pv.get(PASTE, function(req)
  return paste_page({ person_id = text.clean(req.query.person), notice = req.query.notice })
end)

pv.post(PASTE .. '/read', function(req)
  local person_id, pasted, problem = read_request(req.form)
  if problem then return paste_page(req.form, problem) end
  local claims = portal_reader.read(pasted)
  if #claims == 0 then
    req.form.notice = 'unread'
    return paste_page(req.form)
  end
  local rows, known = review(claims, person_id, {})
  local ready = 0
  for _, row in ipairs(rows) do if row.ready then ready = ready + 1 end end
  return pv.render('paste_review', {
    section = 'history', rows = rows, person = pv.get_row('person', person_id),
    pasted = pasted, pharmacies = known, new_pharmacy = NEW_PHARMACY,
    summary = page.counted(#rows, 'fill', 'fills') .. ' found. ' .. ready .. ' ready to add.',
  })
end)

pv.post(PASTE .. '/add', function(req)
  local person_id, pasted, problem = read_request(req.form)
  if problem then return paste_page(req.form, problem) end

  -- The text is read again and every value is checked again. What the review page
  -- sent back is used only for the choices a person made there.
  local claims = portal_reader.read(pasted)
  local chosen = {}
  for index = 1, #claims do
    for _, name in ipairs({ 'medication_' .. index, 'pharmacy_' .. index }) do
      chosen[name] = text.clean(req.form[name])
    end
  end
  local rows = review(claims, person_id, chosen)

  local to_add = {}
  for _, row in ipairs(rows) do
    local wanted = req.form['include_' .. row.index] == 'yes'
    if wanted and row.can_add and row.medication_id and row.pharmacy_id then
      local new_pharmacy = row.pharmacy_id == NEW_PHARMACY
      local fill, errors = fills.read({
        person_id = person_id, medication_id = row.medication_id,
        pharmacy_id = row.pharmacy_id, filled_on = row.claim.filled_on,
        days_supply = row.claim.days_supply, quantity = row.claim.quantity,
        amount_paid = row.claim.amount_paid, rx_number = row.claim.rx_number,
      }, new_pharmacy)
      if not next(errors) then
        to_add[#to_add + 1] = { fill = fill, claim = row.claim, new_pharmacy = new_pharmacy }
      end
    end
  end
  if #to_add == 0 then return pv.redirect(url('/fills?added=0')) end

  local saved = store.together('fill', function(tx)
    local made, taught, fill_rows = {}, {}, {}
    for _, item in ipairs(to_add) do
      local claim = item.claim
      if item.new_pharmacy then
        -- Two fills from one new pharmacy add it once.
        local key = claim.pharmacy_npi or text.key(claim.pharmacy_name)
        if not made[key] then
          made[key] = tx.append('pharmacy', {
            name    = validate.text(claim.pharmacy_name, 'the name', NAME_MAX, true),
            address = validate.text(claim.pharmacy_address, 'the address', ADDRESS_MAX),
            phone   = validate.phone(claim.pharmacy_phone, 'the phone number', PHONE_MAX),
            npi     = validate.npi(claim.pharmacy_npi),
          })
        end
        item.fill.pharmacy_id = made[key]
      end
      -- The name the portal used becomes another name of the medication, so the next
      -- paste finds it without asking.
      local name_key = item.fill.medication_id .. ' ' .. text.key(claim.drug_name)
      if claim.drug_name and not taught[name_key]
         and not answers_to(item.fill.medication_id, claim.drug_name) then
        taught[name_key] = true
        local alias = validate.text(claim.drug_name, 'the name', 200)
        if alias then
          tx.append('medication_alias', { medication_id = item.fill.medication_id, alias = alias })
        end
      end
      fill_rows[#fill_rows + 1] = item.fill
    end
    fills.add_all(tx, fill_rows, nil)
  end)
  if not saved then
    return paste_page(req.form, 'The app could not add the fills. Read the text again and check each row.')
  end
  return pv.redirect(url('/fills?person=' .. person_id .. '&added=' .. #to_add))
end)
