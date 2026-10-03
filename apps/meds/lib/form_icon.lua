-- This file is part of Prescription Tracker
-- apps/meds/lib/form_icon.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-03
-- Last Modified: 2026-10-03
-- Summary: Pure Lua: the icon and the words that stand for the dose form of a product, so a
--          tablet, an inhaler or an injection can be told apart at a glance.
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

local form_icon = {}

--- Configuration ---
-- The icon of each form of the starter list, by the key of the form. Every name is in
-- the Bootstrap Icons set that Privatium ships, except 'syringe', which the partial
-- _form_icon draws itself.
local BY_FORM = {
  ['tablet']             = 'capsule-pill',
  ['capsule']            = 'capsule',
  ['liquid']             = 'droplet',
  ['suspension']         = 'droplet-half',
  ['drops']              = 'eyedropper',
  ['cream']              = 'moisture',
  ['ointment']           = 'moisture',
  ['gel']                = 'moisture',
  ['patch']              = 'bandaid',
  ['inhaler']            = 'lungs',
  ['nebulizer solution'] = 'cloud-haze',
  ['spray']              = 'wind',
  ['injection']          = 'syringe',
  ['powder']             = 'snow',
  ['suppository']        = 'egg',
  ['device']             = 'cpu',
  ['supplies']           = 'box-seam',
}
-- A product with no form, or a form the list above lacks.
local DEFAULT = 'prescription2'

local function key(value)
  if type(value) ~= 'string' then return '' end
  local lowered = value:lower():gsub('[%p%c]', ' '):gsub('%s+', ' '):match('^ ?(.-) ?$')
  return lowered
end

local function holds(value, word)
  return key(value):find(word, 1, true) ~= nil
end

--- The icon and the label for a product.
-- @param form string|nil          The dose form, such as 'Tablet'.
-- @param route string|nil         The route, such as 'Eye'. It decides the icon of drops.
-- @param package_type string|nil  The package, such as 'Pen'. A pen or a cartridge of an
--        injection shows as such.
-- @return string, string  The icon name and the label a screen reader hears: the form
--         as written, or 'Medication' when there is none. Reads no data.
function form_icon.of(form, route, package_type)
  local form_key = key(form)
  local label = (type(form) == 'string' and form_key ~= '') and form or 'Medication'
  if form_key == 'drops' then
    if holds(route, 'eye') or holds(route, 'ophthalmic') then return 'eye', label end
    if holds(route, 'ear') or holds(route, 'otic') then return 'ear', label end
  end
  if form_key == 'injection' or form_key == '' then
    if holds(package_type, 'pen') then return 'pen', label end
    if holds(package_type, 'cartridge') then return 'battery', label end
  end
  return BY_FORM[form_key] or DEFAULT, label
end

return form_icon
