-- This file is part of Medication Tracker
-- tests/lua/test_written_name.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Tests of the module that takes apart a medication name as a pharmacy or an
--          insurer wrote it.
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

local written_name = require 'written_name'

return function(equal)
  --- Taking a name apart ---
  local parts = written_name.parse('EXAMPLINE HCL 10 MG TABLET')
  equal('the drug comes first', parts.name, 'Exampline HCL')
  equal('the strength follows', parts.strength, '10 mg')
  equal('the form comes last', parts.rest, 'Tablet')

  parts = written_name.parse('SAMPLAMIDE 0.5MG/ML SOLN')
  equal('a strength with no space gets one', parts.strength, '0.5 mg/mL')

  parts = written_name.parse('EXAMPLOL-SAMPLINE 875-125 MG TAB')
  equal('a name of two drugs keeps its hyphen', parts.name, 'Examplol-Sampline')
  equal('a strength of two drugs stays whole', parts.strength, '875-125 mg')

  parts = written_name.parse('TEST STRIPS')
  equal('a name with no number is all name', parts.name, 'Test Strips')
  equal('a name with no number has no strength', parts.strength, nil)

  parts = written_name.parse(nil)
  equal('no name gives no parts', parts.name, nil)
  parts = written_name.parse('   ')
  equal('an empty name gives no parts', parts.name, nil)
  parts = written_name.parse('10 MG')
  equal('a number in first place is part of the name', parts.name, '10 MG')

  --- The strength must stand alone ---
  equal('the same strength is found', written_name.has_strength('EXAMPLINE 5 MG TAB', '5 mg'), true)
  equal('a strength with no space is found', written_name.has_strength('EXAMPLINE 5MG TAB', '5 mg'), true)
  equal('5 mg is not 0.5 mg', written_name.has_strength('EXAMPLINE 0.5 MG TAB', '5 mg'), false)
  equal('5 mg is not 2.5 mg', written_name.has_strength('EXAMPLINE 2.5 MG TAB', '5 mg'), false)
  equal('5 mg is not 25 mg', written_name.has_strength('EXAMPLINE 25 MG TAB', '5 mg'), false)
  equal('5 mg is not 5 mcg', written_name.has_strength('EXAMPLINE 5 MCG TAB', '5 mg'), false)
  equal('one part of two strengths is not the strength',
        written_name.has_strength('EXAMPLOL-SAMPLINE 875-125 MG', '125 mg'), false)
  equal('two strengths are found together',
        written_name.has_strength('EXAMPLOL-SAMPLINE 875-125 MG', '875-125 mg'), true)
  equal('a decimal strength is found', written_name.has_strength('EXAMPLINE 2.5 MG', '2.5 mg'), true)
  equal('no strength is never found', written_name.has_strength('EXAMPLINE 10 MG', nil), false)
  equal('an empty strength is never found', written_name.has_strength('EXAMPLINE 10 MG', ' '), false)
  equal('a pattern in a strength is plain text', written_name.has_strength('EXAMPLINE 10 MG', '.. mg'), false)

  --- The name must start the written name ---
  equal('the drug starts the name', written_name.starts_with('EXAMPLINE HCL 10 MG', 'Exampline'), true)
  equal('part of a word does not', written_name.starts_with('EXAMPLINE HCL 10 MG', 'Exam'), false)
  equal('one drug of two does not', written_name.starts_with('EXAMPLINE-SAMPLAMIDE 10 MG', 'Exampline'), false)
  equal('a name of two words does', written_name.starts_with('ventolin hfa 90 mcg', 'Ventolin HFA'), true)
  equal('a later word does not', written_name.starts_with('GENERIC EXAMPLINE 10 MG', 'Exampline'), false)
  equal('no name never does', written_name.starts_with('EXAMPLINE', nil), false)
end
