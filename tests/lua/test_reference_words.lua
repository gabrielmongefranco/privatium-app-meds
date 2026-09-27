-- This file is part of Prescription Tracker
-- tests/lua/test_reference_words.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Tests of the module that turns the words of a drug reference into the words of
--          the catalog.
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

local reference_words = require 'reference_words'

return function(equal)
  --- Routes ---
  equal('a pill by mouth', reference_words.route('Oral Pill'), 'Oral')
  equal('capitals do not matter', reference_words.route('ORAL'), 'Oral')
  equal('an inhalant', reference_words.route('Inhalant'), 'Inhalation')
  equal('the eye', reference_words.route('Ophthalmic'), 'Eye')
  equal('the ear', reference_words.route('Otic'), 'Ear')
  equal('under the skin', reference_words.route('SUBCUTANEOUS'), 'Subcutaneous Injection')
  equal('a route that is not known', reference_words.route('Intergalactic'), nil)
  equal('no route', reference_words.route(nil), nil)
  equal('an empty route', reference_words.route('  '), nil)
  equal('markup as a route', reference_words.route('<script>'), nil)

  --- Forms ---
  equal('a tablet', reference_words.form('Oral Tablet', 'Oral'), 'Tablet')
  equal('a coated tablet', reference_words.form('TABLET, FILM COATED', 'Oral'), 'Tablet')
  equal('a long-acting capsule', reference_words.form('Extended Release Oral Capsule', 'Oral'), 'Capsule')
  equal('a solution by mouth', reference_words.form('Oral Solution', 'Oral'), 'Liquid')
  equal('a solution for the eye', reference_words.form('Ophthalmic Solution', 'Eye'), 'Drops')
  equal('a solution to inhale', reference_words.form('Inhalation Solution', 'Inhalation'), 'Nebulizer Solution')
  equal('a suspension to inhale', reference_words.form('Inhalation Suspension', 'Inhalation'), 'Nebulizer Solution')
  equal('a metered inhaler', reference_words.form('Metered Dose Inhaler', 'Inhalation'), 'Inhaler')
  equal('a powder to inhale', reference_words.form('Inhalation Powder', 'Inhalation'), 'Inhaler')
  equal('an injectable suspension is an injection',
        reference_words.form('Injectable Suspension', 'Injection'), 'Injection')
  equal('a pen', reference_words.form('Pen Injector', 'Injection'), 'Injection')
  equal('a form that is not known', reference_words.form('Cloth', 'Topical'), 'Other')
  equal('no form', reference_words.form(nil, 'Oral'), nil)
  equal('an empty form', reference_words.form('', nil), nil)
end
