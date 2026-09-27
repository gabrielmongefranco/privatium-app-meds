-- This file is part of Prescription Tracker
-- tests/lua/test_authorization_words.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Tests of the levels and the words of a prior authorization that needs attention.
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

local authorization_words = require 'authorization_words'

return function(equal)
  --- Levels, with 14 days for due ---
  equal('yesterday is expired', authorization_words.level(-1, 14), 'expired')
  equal('today is due', authorization_words.level(0, 14), 'due')
  equal('14 days away is due', authorization_words.level(14, 14), 'due')
  equal('15 days away is due soon', authorization_words.level(15, 14), 'due_soon')
  equal('30 days away is due soon', authorization_words.level(30, 14), 'due_soon')
  equal('zero days for due leaves today due', authorization_words.level(0, 0), 'due')
  equal('zero days for due makes tomorrow due soon', authorization_words.level(1, 0), 'due_soon')

  --- Words ---
  equal('long expired', authorization_words.phrase(-5), 'Expired 5 days ago')
  equal('expired yesterday', authorization_words.phrase(-1), 'Expired 1 day ago')
  equal('expires today', authorization_words.phrase(0), 'Expires today')
  equal('expires tomorrow', authorization_words.phrase(1), 'Expires tomorrow')
  equal('expires later', authorization_words.phrase(10), 'Expires in 10 days')

  --- The levels are listed most urgent first ---
  equal('the first level', authorization_words.LEVELS[1].key, 'expired')
  equal('the last level', authorization_words.LEVELS[3].key, 'due_soon')
end
