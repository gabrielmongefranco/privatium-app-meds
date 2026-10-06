-- This file is part of Medication Tracker
-- tests/lua/test_page.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Unit tests for apps/meds/lib/page.lua.
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

local page = require 'page'

return function(equal)
  equal('a known notice code gives its sentence', page.notice('saved'), 'Saved.')
  equal('an unknown notice code gives nothing', page.notice('<script>alert(1)</script>'), nil)
  equal('a notice code that is not text gives nothing', page.notice({ 'saved' }), nil)
  equal('no notice code gives nothing', page.notice(nil), nil)

  local problems = page.problems({ phone = 'b', name = 'a' }, { 'name', 'phone', 'fax' })
  equal('problems follow the order of the form', problems[1].field .. ',' .. problems[2].field, 'name,phone')
  equal('a field with no problem is left out', #problems, 2)
  equal('no problems gives an empty list', #page.problems({}, { 'name' }), 0)

  equal('one is singular', page.counted(1, 'fill', 'fills'), '1 fill')
  equal('zero is plural', page.counted(0, 'fill', 'fills'), '0 fills')
  equal('two is plural', page.counted(2, 'fill', 'fills'), '2 fills')

  equal('masked hides a value in double quotes', page.masked('fill.filled_on: "2026-02-30" is not a date'), 'fill.filled_on: "..." is not a date')
  equal('masked hides a value in single quotes', page.masked("name 'Alex Example' refused"), "name '...' refused")
  equal('masked accepts a value that is not text', page.masked(nil), 'nil')
end
