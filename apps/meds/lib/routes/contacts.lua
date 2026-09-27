-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/contacts.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The screens that list, add, change and remove pharmacies and prescribers.
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
local page     = require 'page'
local store    = require 'store'
local suggestions = require 'suggestions'
local text     = require 'text'
local validate = require 'validate'

--- Configuration ---
local LIST        = '/contacts'
local PHARMACIES  = '/contacts/pharmacies'
local PRESCRIBERS = '/contacts/prescribers'
local NAME_MAX    = 120
local ADDRESS_MAX = 200
local PHONE_MAX   = 40
local EMAIL_MAX   = 254   -- The longest address that mail servers accept
local WEBSITE_MAX = 200

local PHARMACY_FIELDS   = { 'name', 'phone', 'fax', 'address', 'email', 'website', 'npi' }
local PRESCRIBER_FIELDS = { 'name', 'clinic', 'phone', 'mobile_phone', 'fax', 'address',
                            'email', 'website', 'npi' }

--- Reads ---

-- Grain: one row per pharmacy.
local function pharmacies()
  return pv.query([[
    SELECT id, name, npi, address, phone, fax, email, website
      FROM pharmacy
     ORDER BY name COLLATE NOCASE, id]])
end

-- Grain: one row per prescriber.
local function prescribers()
  return pv.query([[
    SELECT id, name, clinic, phone, mobile_phone, fax, email, address, website, npi
      FROM prescriber
     ORDER BY name COLLATE NOCASE, id]])
end

-- The schema cannot declare a name unique, so the check happens here.
local function taken(rows, name, except_id)
  local key = text.key(name)
  for _, row in ipairs(rows) do
    if row.id ~= except_id and text.key(row.name) == key then return true end
  end
  return false
end

local function pharmacy_uses(id)
  local counts = pv.query1([[
    SELECT (SELECT count(*) FROM fill              WHERE pharmacy_id = ?1) AS fills,
           (SELECT count(*) FROM person_medication WHERE pharmacy_id = ?1) AS medications]],
    { id })
  local list = {}
  if counts.fills > 0 then list[#list + 1] = page.counted(counts.fills, 'fill', 'fills') end
  if counts.medications > 0 then
    list[#list + 1] = page.counted(counts.medications, 'medication on a list', 'medications on a list')
  end
  return list
end

local function prescriber_uses(id)
  local counts = pv.query1(
    'SELECT count(*) AS medications FROM person_medication WHERE prescriber_id = ?', { id })
  local list = {}
  if counts.medications > 0 then
    list[#list + 1] = page.counted(counts.medications, 'medication on a list', 'medications on a list')
  end
  return list
end

-- Adds what a list page shows beside the stored values: a number a phone can dial.
local function with_links(rows)
  for _, row in ipairs(rows) do
    row.phone_href  = validate.tel_href(row.phone)
    row.mobile_href = validate.tel_href(row.mobile_phone)
  end
  return rows
end

--- Validation ---

-- The columns that a pharmacy and a prescriber share.
local function read_shared(form, row, errors)
  row.name,    errors.name    = validate.text(form.name, 'the name', NAME_MAX, true)
  row.phone,   errors.phone   = validate.phone(form.phone, 'the phone number', PHONE_MAX)
  row.fax,     errors.fax     = validate.phone(form.fax, 'the fax number', PHONE_MAX)
  row.address, errors.address = validate.text(form.address, 'the address', ADDRESS_MAX)
  row.email,   errors.email   = validate.email(form.email, EMAIL_MAX)
  row.website, errors.website = validate.website(form.website, WEBSITE_MAX)
  row.npi,     errors.npi     = validate.npi(form.npi)
end

local function read_pharmacy(form, except_id)
  local row, errors = {}, {}
  read_shared(form, row, errors)
  if row.name and taken(pharmacies(), row.name, except_id) then
    errors.name = 'Choose another name. A pharmacy with this name is already in the app.'
  end
  return row, errors
end

local function read_prescriber(form, except_id)
  local row, errors = {}, {}
  read_shared(form, row, errors)
  row.clinic, errors.clinic = validate.text(form.clinic, 'the clinic', NAME_MAX)
  row.mobile_phone, errors.mobile_phone =
    validate.phone(form.mobile_phone, 'the mobile phone number', PHONE_MAX)
  if row.name and taken(prescribers(), row.name, except_id) then
    errors.name = 'Choose another name. A prescriber with this name is already in the app.'
  end
  return row, errors
end

--- One set of routes for each kind of contact ---
-- The two kinds differ in their table, their fields and their wording, and in nothing
-- else, so both are built from one description.

local function routes(kind)
  local function form_page(heading, action, typed, errors)
    return pv.render(kind.form_view, {
      section  = 'contacts',
      heading  = heading,
      action   = action,
      typed    = typed,
      errors   = errors,
      problems = page.problems(errors, kind.fields),
      clinics  = suggestions.clinics(),
    })
  end

  pv.get(kind.path .. '/new', function()
    return form_page(kind.add_heading, url(kind.path .. '/new'), {}, {})
  end)

  pv.post(kind.path .. '/new', function(req)
    local row, errors = kind.read(req.form, nil)
    if not next(errors) then
      local saved, refusal = store.save(kind.table_name, nil, row)
      if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
      errors.name = refusal
    end
    return form_page(kind.add_heading, url(kind.path .. '/new'), req.form, errors)
  end)

  pv.get(kind.path .. '/:id/edit', function(req)
    local contact = pv.get_row(kind.table_name, req.params.id)
    if not contact then return pv.redirect(url(LIST .. '?notice=missing')) end
    return form_page(kind.change_heading, url(kind.path .. '/' .. contact.id .. '/edit'), contact, {})
  end)

  pv.post(kind.path .. '/:id/edit', function(req)
    local contact = pv.get_row(kind.table_name, req.params.id)
    if not contact then return pv.redirect(url(LIST .. '?notice=missing')) end
    local row, errors = kind.read(req.form, contact.id)
    if not next(errors) then
      local saved, refusal = store.save(kind.table_name, contact.id, row)
      if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
      errors.name = refusal
    end
    return form_page(kind.change_heading, url(kind.path .. '/' .. contact.id .. '/edit'),
                     req.form, errors)
  end)

  pv.get(kind.path .. '/:id/remove', function(req)
    local contact = pv.get_row(kind.table_name, req.params.id)
    if not contact then return pv.redirect(url(LIST .. '?notice=missing')) end
    return pv.render('remove', {
      section = 'contacts',
      heading = kind.remove_heading,
      name    = contact.name,
      used_by = kind.uses(contact.id),
      action  = url(kind.path .. '/' .. contact.id .. '/remove'),
      back    = url(LIST),
    })
  end)

  pv.post(kind.path .. '/:id/remove', function(req)
    local contact = pv.get_row(kind.table_name, req.params.id)
    if not contact then return pv.redirect(url(LIST .. '?notice=missing')) end
    -- A contact that other records point to stays, or those records would name nobody.
    if #kind.uses(contact.id) > 0 then
      return pv.redirect(url(kind.path .. '/' .. contact.id .. '/remove'))
    end
    pv.delete(kind.table_name, contact.id)
    return pv.redirect(url(LIST .. '?notice=removed'))
  end)
end

--- Routes ---

pv.get(LIST, function(req)
  return pv.render('contacts', {
    section     = 'contacts',
    notice      = page.notice(req.query.notice),
    pharmacies  = with_links(pharmacies()),
    prescribers = with_links(prescribers()),
  })
end)

routes {
  table_name     = 'pharmacy',
  path           = PHARMACIES,
  form_view      = 'pharmacy_form',
  fields         = PHARMACY_FIELDS,
  read           = read_pharmacy,
  uses           = pharmacy_uses,
  add_heading    = 'Add a pharmacy',
  change_heading = 'Change a pharmacy',
  remove_heading = 'Remove a pharmacy',
}

routes {
  table_name     = 'prescriber',
  path           = PRESCRIBERS,
  form_view      = 'prescriber_form',
  fields         = PRESCRIBER_FIELDS,
  read           = read_prescriber,
  uses           = prescriber_uses,
  add_heading    = 'Add a prescriber',
  change_heading = 'Change a prescriber',
  remove_heading = 'Remove a prescriber',
}
