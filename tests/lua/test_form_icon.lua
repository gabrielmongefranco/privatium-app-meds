-- This file is part of Prescription Tracker
-- tests/lua/test_form_icon.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-03
-- Last Modified: 2026-10-03
-- Summary: Tests for form_icon: every form of the starter list, the routes of drops, the
--          packages of an injection, an unknown form and no form.
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

local choices   = require 'choices'
local form_icon = require 'form_icon'

return function(equal)
  local expected = {
    Tablet = 'capsule-pill', Capsule = 'capsule', Liquid = 'droplet', Suspension = 'droplet-half',
    Drops = 'eyedropper', Cream = 'moisture', Ointment = 'moisture', Gel = 'moisture',
    Patch = 'bandaid', Inhaler = 'lungs', ['Nebulizer Solution'] = 'cloud-haze', Spray = 'wind',
    Injection = 'syringe', Powder = 'snow', Suppository = 'egg', Device = 'cpu',
    Supplies = 'box-seam', Other = 'prescription2',
  }
  for _, form in ipairs(choices.FORMS) do
    local icon, label = form_icon.of(form)
    equal('icon of ' .. form, icon, expected[form])
    equal('label of ' .. form, label, form)
  end
  equal('every starter form has an expected icon', #choices.FORMS, 18)

  equal('eye drops', (form_icon.of('Drops', 'Eye')), 'eye')
  equal('ophthalmic drops in other letters', (form_icon.of('drops', 'OPHTHALMIC')), 'eye')
  equal('ear drops', (form_icon.of('Drops', 'Ear')), 'ear')
  equal('otic drops', (form_icon.of('Drops', 'Otic')), 'ear')
  equal('oral drops', (form_icon.of('Drops', 'Oral')), 'eyedropper')
  equal('an injection in a pen', (form_icon.of('Injection', 'Subcutaneous Injection', 'Pen')), 'pen')
  equal('an injection in a cartridge', (form_icon.of('Injection', nil, 'Cartridge')), 'battery')
  equal('an injection in a vial', (form_icon.of('Injection', nil, 'Vial')), 'syringe')
  equal('a tablet in a pen package is still a tablet', (form_icon.of('Tablet', nil, 'Pen')), 'capsule-pill')
  equal('a form the list lacks', (form_icon.of('Lozenge')), 'prescription2')
  equal('a form with other punctuation', (form_icon.of('nebulizer-solution')), 'cloud-haze')
  equal('no form', (form_icon.of(nil)), 'prescription2')
  equal('no form, labelled', select(2, form_icon.of(nil)), 'Medication')
  equal('an empty form, labelled', select(2, form_icon.of('  ')), 'Medication')
  equal('no form in a pen package', (form_icon.of(nil, nil, 'Pen')), 'pen')
  equal('a number as a form', (form_icon.of(12)), 'prescription2')
end
