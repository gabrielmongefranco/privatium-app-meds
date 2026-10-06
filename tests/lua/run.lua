-- This file is part of Medication Tracker
-- tests/lua/run.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Runs the unit tests of the app's pure Lua modules with plain Lua 5.4. Run it
--          from the root of the repository: lua5.4 tests/lua/run.lua
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

--- Check the interpreter ---
-- Privatium runs apps on Lua 5.4. An older Lua lacks utf8 and integers, so the tests
-- would fail for reasons that have nothing to do with the app.
if _VERSION ~= 'Lua 5.4' then
  print('These tests need Lua 5.4, and this is ' .. _VERSION .. '. Run: lua5.4 tests/lua/run.lua')
  os.exit(2)
end

--- Configuration ---
-- The modules under test, and the tests, are found from the root of the repository.
package.path = 'apps/meds/lib/?.lua;tests/lua/?.lua;' .. package.path

local SUITES = {
  'test_text', 'test_validate', 'test_medication_name', 'test_choices', 'test_page',
  'test_clock', 'test_match', 'test_refill', 'test_portal_reader', 'test_written_name', 'test_reference_words', 'test_authorization_words',
  'test_form_icon', 'test_periods', 'test_spending_chart', 'test_when_icon',
}

--- Run ---
local passed, failed = 0, 0

-- Compares two values and records the result under a name that says what was expected.
local function equal(name, actual, expected)
  if actual == expected then
    passed = passed + 1
    return
  end
  failed = failed + 1
  print(('FAIL  %s: expected %s, got %s'):format(name, tostring(expected), tostring(actual)))
end

for _, suite in ipairs(SUITES) do
  local loaded, run = pcall(require, suite)
  if loaded then
    local finished, problem = pcall(run, equal)
    if not finished then
      failed = failed + 1
      print(('FAIL  %s stopped: %s'):format(suite, tostring(problem)))
    end
  else
    failed = failed + 1
    print(('FAIL  %s did not load: %s'):format(suite, tostring(run)))
  end
end

--- Report ---
print(('%d passed, %d failed'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
