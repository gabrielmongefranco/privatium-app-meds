-- This file is part of Prescription Tracker
-- tests/lua/test_match.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Unit tests for apps/meds/lib/match.lua, with invented names.
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

local match = require 'match'

return function(equal)
  --- distance ---
  equal('the same word is 0 apart', match.distance('examplol', 'examplol'), 0)
  equal('one changed letter is 1 apart', match.distance('examplol', 'examplal'), 1)
  equal('one missing letter is 1 apart', match.distance('examplol', 'exmplol'), 1)
  equal('one added letter is 1 apart', match.distance('examplol', 'exampllol'), 1)
  equal('two swapped letters are 1 apart', match.distance('examplol', 'exmaplol'), 1)
  equal('an empty word is as far as the other is long', match.distance('', 'abc'), 3)
  equal('two different words are far apart', match.distance('examplol', 'samplex') > 2, true)

  --- kind ---
  equal('the same name is exact', match.kind('Z-Pak', 'z pak'), match.EXACT)
  equal('case and punctuation do not matter', match.kind('EXAMPLOL (exampline)', 'Examplol Exampline'), match.EXACT)
  equal('the start of a word matches', match.kind('exam', 'Examplol (Exampline) 10 mg'), match.CONTAINS)
  equal('a later word matches', match.kind('exampline', 'Examplol (Exampline) 10 mg'), match.CONTAINS)
  equal('two words in any order match', match.kind('10 examplol', 'Examplol (Exampline) 10 mg'), match.CONTAINS)
  equal('one mistake in a long word is close', match.kind('examplal', 'Examplol'), match.CLOSE)
  equal('two mistakes in a very long word are close', match.kind('exampleneride', 'Examplinerida'), match.CLOSE)
  equal('three mistakes are no match', match.kind('exomplanirede', 'Examplinerida'), nil)
  equal('one mistake in a short word is no match', match.kind('abcd', 'abce'), nil)
  equal('a word the name lacks is no match', match.kind('examplol samplex', 'Examplol 10 mg'), nil)
  equal('the middle of a word is no match', match.kind('amplo', 'Examplol'), nil)
  equal('nothing typed is no match', match.kind('', 'Examplol'), nil)
  equal('punctuation only is no match', match.kind('%_', 'Examplol 0.1%'), nil)

  --- rank ---
  local names = {
    { medication_id = 'A', name = 'Examplol (Exampline) 10 mg' },
    { medication_id = 'A', name = 'exm' },
    { medication_id = 'B', name = 'Examplal 5 mg' },
    { medication_id = 'C', name = 'Samplex' },
    { medication_id = 'D', name = 'exm' },
  }
  local ranked = match.rank('exm', names)
  equal('a name that two medications share finds both', #ranked, 2)
  equal('an exact match is exact', ranked[1].kind, match.EXACT)
  equal('matches keep the order of the names', ranked[1].medication_id .. ranked[2].medication_id, 'AD')

  ranked = match.rank('examplol', names)
  equal('a better match comes first', ranked[1].medication_id, 'A')
  equal('a close match comes after', ranked[2].medication_id .. ranked[2].kind, 'B' .. match.CLOSE)
  equal('a medication appears once', #ranked, 2)
  equal('no match gives an empty list', #match.rank('zzzzzz', names), 0)
end
