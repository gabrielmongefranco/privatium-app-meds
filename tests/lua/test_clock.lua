-- This file is part of Prescription Tracker
-- tests/lua/test_clock.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Unit tests for apps/meds/lib/clock.lua.
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

local clock = require 'clock'

return function(equal)
  equal('midnight is morning', clock.greeting(0), 'Good morning')
  equal('11 is morning', clock.greeting(11), 'Good morning')
  equal('noon is afternoon', clock.greeting(12), 'Good afternoon')
  equal('17 is afternoon', clock.greeting(17), 'Good afternoon')
  equal('18 is evening', clock.greeting(18), 'Good evening')
  equal('23 is evening', clock.greeting(23), 'Good evening')

  equal('today has the form YYYY-MM-DD', clock.today():match('^%d%d%d%d%-%d%d%-%d%d$') ~= nil, true)
  equal('today is the local date', clock.today(), os.date('%Y-%m-%d'))
  equal('the hour is the local hour', clock.hour(), tonumber(os.date('%H')))
end
