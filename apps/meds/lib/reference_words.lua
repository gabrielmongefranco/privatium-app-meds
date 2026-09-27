-- This file is part of Prescription Tracker
-- apps/meds/lib/reference_words.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Turns the route and the dose form of a drug reference into the words of the
--          catalog.
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

local text = require 'text'

local reference_words = {}

--- Configuration ---
-- A drug reference names routes and forms in its own words. The catalog shows the
-- words of its drop-downs, so a copied entry looks like one that was typed.

-- The first word of the route of a reference, and the route the catalog shows.
local ROUTES = {
  oral = 'Oral', chewable = 'Oral', sublingual = 'Oral', buccal = 'Oral',
  inhalant = 'Inhalation', inhalation = 'Inhalation', respiratory = 'Inhalation',
  nasal = 'Nasal', ophthalmic = 'Eye', otic = 'Ear', auricular = 'Ear',
  topical = 'Topical', transdermal = 'Topical', rectal = 'Rectal', vaginal = 'Vaginal',
  injectable = 'Injection', subcutaneous = 'Subcutaneous Injection',
  intramuscular = 'Intramuscular Injection', intravenous = 'Injection',
}

-- A word of the dose form of a reference, and the form the catalog shows. The first
-- word that is found decides, so the order matters: an injectable suspension is an
-- injection.
local FORMS = {
  { 'inject', 'Injection' }, { 'syringe', 'Injection' }, { 'cartridge', 'Injection' },
  { 'inhaler', 'Inhaler' }, { 'aerosol', 'Inhaler' }, { 'nebuliz', 'Nebulizer Solution' },
  { 'tablet', 'Tablet' }, { 'capsule', 'Capsule' }, { 'suspension', 'Suspension' },
  { 'cream', 'Cream' }, { 'ointment', 'Ointment' }, { 'gel', 'Gel' }, { 'patch', 'Patch' },
  { 'transdermal', 'Patch' }, { 'spray', 'Spray' }, { 'powder', 'Powder' },
  { 'suppository', 'Suppository' }, { 'solution', 'Liquid' }, { 'liquid', 'Liquid' },
}

--- The route the catalog shows for the route of a reference.
-- @param raw any  The route as the reference wrote it, such as 'Oral Pill' or 'ORAL'.
-- @return string|nil  A route, or nil when the reference gave none or one that is not known.
function reference_words.route(raw)
  local first = text.key(text.clean(raw)):match('^%S+')
  return first and ROUTES[first] or nil
end

--- The form the catalog shows for the dose form of a reference.
-- @param raw any  The dose form as the reference wrote it, such as 'Oral Tablet' or
--        'TABLET, FILM COATED'.
-- @param route string|nil  What reference_words.route returned. A solution for the
--        eye or the ear is drops. A liquid to inhale is a nebulizer solution, and
--        anything else to inhale is an inhaler.
-- @return string|nil  A form, 'Other' for a dose form that is not known, or nil when
--         the reference gave none.
function reference_words.form(raw, route)
  local written = text.key(text.clean(raw))
  if written == '' then return nil end
  if route == 'Inhalation' then
    local liquid = written:find('solution', 1, true) or written:find('suspension', 1, true)
    return liquid and 'Nebulizer Solution' or 'Inhaler'
  end
  for _, pair in ipairs(FORMS) do
    if written:find(pair[1], 1, true) then
      local form = pair[2]
      if form == 'Liquid' and (route == 'Eye' or route == 'Ear') then return 'Drops' end
      return form
    end
  end
  return 'Other'
end

return reference_words
