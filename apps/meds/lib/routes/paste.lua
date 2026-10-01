-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/paste.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-01
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
local medication_pick   = require 'medication_pick'
local medication_search = require 'medication_search'
local page              = require 'page'
local portal_reader     = require 'portal_reader'
local quick_add         = require 'quick_add'
local store             = require 'store'
local suggestions       = require 'suggestions'
local text              = require 'text'
local validate          = require 'validate'
local written_name      = require 'written_name'

--- Configuration ---
local PASTE           = '/fills/paste'
local PASTED_MAX      = 60000   -- Bytes. A Tier 1 request holds 64 KiB, and the form adds a little.
local SUGGESTIONS_MAX = 8       -- Medications offered for a name that is not known yet
local NEW_PHARMACY    = 'new'   -- The choice that adds the pharmacy from the pasted details
local NAME_MAX, ADDRESS_MAX, PHONE_MAX, ALIAS_MAX = 120, 200, 40, 200

--- Reads ---

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

-- The number of the first fill of the text that carries each key. The fields of a
-- medication or a pharmacy are named after that number. It depends on the text alone,
-- so a choice still belongs to its name when the text is read again.
local function first_fill_of(claims, key_of)
  local first = {}
  for index, claim in ipairs(claims) do
    local key = key_of(claim)
    if key and key ~= '' and not first[key] then first[key] = index end
  end
  return first
end

-- Looks for the medication of a name among the earlier fills of the person, by the
-- prescription numbers of its fills. A number that is known names one medication. When
-- the drug of the written name is among the names of that medication too, the two
-- agree, and the medication is the choice to begin with. With the number alone, the
-- medication comes first and the person decides.
local function by_prescription(subject, person_id, typed, submitted)
  local found = {}
  for _, claim in ipairs(subject.claims) do
    for _, id in ipairs(fills.medications_of_rx(person_id, claim.rx_number)) do found[id] = true end
  end
  local id = next(found)
  -- Numbers that lead to two medications say nothing.
  if not id or next(found, id) then return end

  local medication, fits = medication_search.fit(id, subject.name)
  if not medication then return end
  local others = {}
  for _, candidate in ipairs(subject.candidates) do
    if candidate.medication_id ~= id then
      candidate.sure = nil
      others[#others + 1] = candidate
    end
  end
  medication.sure = fits
  medication.note = fits and 'Same prescription number and name' or 'Same prescription number'
  table.insert(others, 1, medication)
  subject.candidates, subject.by_number = others, true
  if not submitted then
    typed[subject.prefix .. '_choice'] = fits and id or nil
  end
end

-- The medications of a paste: one for each distinct name among the fills that can be
-- added, so ten fills of one medication ask one question.
-- @param rows table   The rows of the review.
-- @param typed table  The values of the review form; filled in with what the app
--        suggests when `submitted` is false.
local function medications_of(claims, rows, person_id, typed, submitted)
  local first = first_fill_of(claims, function(claim) return text.key(claim.drug_name) end)
  local list, by_key = {}, {}
  for _, row in ipairs(rows) do
    local claim = row.claim
    local key = text.key(claim.drug_name)
    if row.can_add and not by_key[key] then
      local subject = { index = first[key], name = claim.drug_name }
      subject.prefix = 'medication_' .. subject.index
      local offered, exact = medication_search.suggest(claim.drug_name, SUGGESTIONS_MAX)
      subject.candidates = offered
      subject.claims = {}
      if exact then
        subject.known = exact
      elseif submitted then
        subject.pick = medication_pick.read(typed, subject.prefix, true, true)
      else
        -- The choice that is marked to begin with: the one medication with the same
        -- name and strength, or a new medication when the catalog holds nothing like it.
        local parts = written_name.parse(claim.drug_name)
        typed[subject.prefix .. '_generic']  = parts.name
        typed[subject.prefix .. '_strength'] = parts.strength
        if offered[1] and offered[1].sure then
          typed[subject.prefix .. '_choice'] = offered[1].medication_id
        elseif #offered == 0 then
          typed[subject.prefix .. '_choice'] = medication_pick.NEW
        end
      end
      list[#list + 1], by_key[key] = subject, subject
    end
    if row.can_add then table.insert(by_key[key].claims, claim) end
  end

  for _, subject in ipairs(list) do
    if not subject.known then by_prescription(subject, person_id, typed, submitted) end
  end
  return list, by_key
end

-- The medication that a name of the paste stands for, when it is one of the app: the
-- medication that answers to the name, or the one that is chosen for it.
local function medication_of(subject, typed, submitted)
  if subject.known then return subject.known.medication_id end
  if submitted then return subject.pick and subject.pick.id end
  local choice = text.clean(typed[subject.prefix .. '_choice'])
  if choice and choice ~= medication_pick.NEW and choice ~= medication_pick.OTHER
     and pv.get_row('medication', choice) then
    return choice
  end
  return nil
end

-- Leaves out the fills that the person has already: the same medication on the same
-- date. A fill that was typed by hand or imported often has no prescription number,
-- so the number alone would let it in a second time. A medication with no fill left
-- asks no question.
local function leave_out_repeated(rows, medications, medication_by, person_id, typed, submitted)
  for _, row in ipairs(rows) do
    local subject = row.can_add and medication_by[text.key(row.claim.drug_name)]
    local id = subject and medication_of(subject, typed, submitted)
    if id and fills.on_day(person_id, id, row.claim.filled_on) then
      row.result, row.same_day = 'Already recorded', true
      row.can_add, row.ready, row.wanted = nil, nil, false
      if not submitted then typed['include_' .. row.index] = nil end
      for position, claim in ipairs(subject.claims) do
        if claim == row.claim then table.remove(subject.claims, position) break end
      end
    end
  end
  for position = #medications, 1, -1 do
    if #medications[position].claims == 0 then table.remove(medications, position) end
  end
end

-- The key of the pharmacy of a claim: its identifier, or its name.
local function pharmacy_key(claim)
  return claim.pharmacy_npi or text.key(claim.pharmacy_name)
end

-- The row of a pharmacy that is added from the pasted details.
local function pharmacy_row(claim)
  return {
    name    = validate.text(claim.pharmacy_name, 'the name', NAME_MAX, true),
    address = validate.text(claim.pharmacy_address, 'the address', ADDRESS_MAX),
    phone   = validate.phone(claim.pharmacy_phone, 'the phone number', PHONE_MAX),
    npi     = validate.npi(claim.pharmacy_npi),
  }
end

-- The pharmacies of a paste: one for each distinct pharmacy among the fills that can
-- be added.
local function pharmacies_of(claims, rows, typed, submitted, known)
  local first = first_fill_of(claims, pharmacy_key)
  local list, by_key = {}, {}
  for _, row in ipairs(rows) do
    local claim = row.claim
    local key = pharmacy_key(claim)
    if row.can_add and not by_key[key] then
      local subject = { index = first[key], claim = claim, name = claim.pharmacy_name }
      subject.field = 'pharmacy_' .. subject.index
      subject.known = pharmacy_of(claim, known)
      subject.can_add = pharmacy_row(claim).name ~= nil
      if not subject.known then
        if not submitted and subject.can_add then typed[subject.field] = NEW_PHARMACY end
        local chosen = text.clean(typed[subject.field])
        if chosen == NEW_PHARMACY and subject.can_add then
          subject.new_row = pharmacy_row(claim)
        elseif chosen and chosen ~= NEW_PHARMACY and pv.get_row('pharmacy', chosen) then
          subject.id = chosen
        else
          subject.problem = 'Choose a pharmacy from the list.'
        end
      end
      list[#list + 1], by_key[key] = subject, subject
    end
  end
  return list, by_key
end

-- Turns the claims of a pasted text into what the review page shows: the medications,
-- the pharmacies, and one row for each fill that says whether it can be added.
local function review(claims, person_id, typed, submitted)
  local rows = {}
  local person = pv.get_row('person', person_id)
  for index, claim in ipairs(claims) do
    local row = { index = index, claim = claim, problems = {} }
    local form = {
      plan_id = person and person.plan_id, person_id = person_id, filled_on = claim.filled_on, days_supply = claim.days_supply,
      quantity = claim.quantity, amount_paid = claim.amount_paid, rx_number = claim.rx_number,
    }
    row.fill, row.errors = fills.read(form, { medication_id = true, pharmacy_id = true })
    for _, field in ipairs({ 'filled_on', 'days_supply', 'quantity', 'amount_paid', 'rx_number' }) do
      if row.errors[field] then row.problems[#row.problems + 1] = row.errors[field] end
    end
    if row.errors.plan_id then row.problems[#row.problems + 1] = row.errors.plan_id end
    if text.key(claim.drug_name) == '' then
      row.problems[#row.problems + 1] = 'The name of the medication was not read.'
    end

    if #row.problems > 0 then
      row.result = 'Could not read'
    elseif claim.rx_number and claim.filled_on
           and fills.recorded(person_id, claim.rx_number, claim.filled_on) then
      row.result = 'Already recorded'
    elseif not claim.details_open or (pharmacy_key(claim) or '') == '' then
      row.result = 'Details missing'
    elseif (claim.status or ''):lower() ~= 'paid' then
      row.result, row.can_add = 'Not paid', true
    else
      row.result, row.can_add, row.ready = 'Ready', true, true
    end

    -- A fill is marked to begin with when nothing speaks against it. After that, the
    -- marks are the person's own.
    local field = 'include_' .. index
    if not submitted then typed[field] = row.ready and 'yes' or nil end
    row.wanted = row.can_add == true and typed[field] == 'yes'
    rows[#rows + 1] = row
  end

  local known = pharmacies()
  local medications, medication_by = medications_of(claims, rows, person_id, typed, submitted)
  leave_out_repeated(rows, medications, medication_by, person_id, typed, submitted)
  local pharmacy_list, pharmacy_by = pharmacies_of(claims, rows, typed, submitted, known)
  for _, row in ipairs(rows) do
    if row.can_add then
      row.medication = medication_by[text.key(row.claim.drug_name)]
      row.pharmacy   = pharmacy_by[pharmacy_key(row.claim)]
    end
  end
  return { rows = rows, medications = medications, pharmacies = pharmacy_list, known = known }
end

local function paste_page(typed, err)
  return pv.render('paste', {
    section = 'history', typed = typed, err = err,
    people = quick_add.options(quick_add.PERSON),
    notice = page.notice(typed.notice),
  })
end

local function review_page(found, person, pasted, typed, err)
  local ready, asked = 0, 0
  for _, row in ipairs(found.rows) do if row.ready then ready = ready + 1 end end
  for _, subject in ipairs(found.medications) do if not subject.known then asked = asked + 1 end end
  local plan = person.plan_id and pv.get_row('plan', person.plan_id)
  return pv.render('paste_review', {
    plan_name = plan and plan.name,
    section = 'history', found = found, person = person, pasted = pasted, typed = typed,
    err = err, new_pharmacy = NEW_PHARMACY, names = suggestions.medication_names(),
    summary = page.counted(#found.rows, 'fill', 'fills') .. ' found. ' .. ready .. ' ready to add. '
      .. page.counted(asked, 'name is', 'names are') .. ' new to the app.',
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
  local typed = {}
  return review_page(review(claims, person_id, typed, false),
    pv.get_row('person', person_id), pasted, typed)
end)

pv.post(PASTE .. '/add', function(req)
  local person_id, pasted, problem = read_request(req.form)
  if problem then return paste_page(req.form, problem) end

  -- The text is read again and every value is checked again. What the review page
  -- sent back is used only for the choices a person made there.
  local claims = portal_reader.read(pasted)
  local found = review(claims, person_id, req.form, true)

  local wanted, unanswered = {}, 0
  for _, row in ipairs(found.rows) do
    if row.wanted then
      wanted[#wanted + 1] = row
      row.medication.used, row.pharmacy.used = true, true
    end
  end
  if #wanted == 0 then return pv.redirect(url('/fills?added=0')) end
  for _, group in ipairs({ found.medications, found.pharmacies }) do
    for _, subject in ipairs(group) do
      local refused = (subject.pick and subject.pick.problem) or subject.problem
      if subject.used and not subject.known and refused then unanswered = unanswered + 1 end
    end
  end
  if unanswered > 0 then
    return review_page(found, pv.get_row('person', person_id), pasted, req.form,
      'Nothing was added yet. ' .. page.counted(unanswered, 'choice is', 'choices are')
      .. ' still open. Each one is marked below.')
  end

  local saved = store.together('fill', function(tx)
    -- Two names of the portal that lead to the same new medication add it once.
    local added = {}
    for _, subject in ipairs(found.medications) do
      if subject.used and subject.known then
        subject.id = subject.known.medication_id
      elseif subject.used then
        local new_row = subject.pick.new_row
        local key = new_row and text.key(new_row.short_name)
        if key and added[key] then
          subject.id = added[key]
        else
          subject.id = medication_pick.write(tx, subject.pick)
          if key then added[key] = subject.id end
        end
        -- The name the portal used becomes another name of the medication, so the
        -- next paste finds it without asking.
        local alias = validate.text(subject.name, 'the name', ALIAS_MAX)
        local answers = new_row and text.key(new_row.short_name) == text.key(subject.name)
          or (not new_row and answers_to(subject.id, subject.name))
        if alias and not answers then
          tx.append('medication_alias', { medication_id = subject.id, alias = alias })
        end
      end
    end
    for _, subject in ipairs(found.pharmacies) do
      if subject.used then
        subject.id = subject.known or subject.id or tx.append('pharmacy', subject.new_row)
      end
    end

    local rows = {}
    for _, row in ipairs(wanted) do
      row.fill.medication_id, row.fill.pharmacy_id = row.medication.id, row.pharmacy.id
      rows[#rows + 1] = row.fill
    end
    fills.add_all(tx, rows, nil)
  end)
  if not saved then
    return paste_page(req.form, 'The app could not add the fills. Read the text again and check each row.')
  end
  return pv.redirect(url('/fills?person=' .. person_id .. '&added=' .. #wanted))
end)
