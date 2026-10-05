-- This file is part of Prescription Tracker
-- apps/meds/lib/clock.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: The local date and hour of the computer that runs the node, the greeting for
--          an hour, and whole-day steps between dates. Every screen reads the time here,
--          so none of them shows UTC.
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

local clock = {}

--- Configuration ---
local NOON_HOUR    = 12   -- Morning ends here, on a 24-hour clock
local EVENING_HOUR = 18   -- Afternoon ends here
local SECONDS_A_DAY = 24 * 60 * 60

--- Local time ---

--- Today's date on the node's own clock.
-- A format without a leading '!' reads the local time zone; with one it reads UTC.
-- @return string  The date as YYYY-MM-DD.
function clock.today()
  return os.date('%Y-%m-%d')
end

--- The first day of the current month on the node's own clock.
-- @return string  The date as YYYY-MM-DD.
function clock.month_start()
  return os.date('%Y-%m-01')
end

--- The same day one year after the first day of the current month.
-- The first of a month exists in every year, so no date has to be corrected.
-- @return string  The date as YYYY-MM-DD.
function clock.month_start_next_year()
  local year = math.tointeger(tonumber(os.date('%Y')))
  return ('%04d-%s-01'):format(year + 1, os.date('%m'))
end

--- The current hour on the node's own clock.
-- @return integer  0 to 23.
function clock.hour()
  return tonumber(os.date('%H'))
end

--- Dates ---

-- Noon keeps a shift by whole days clear of the hour that daylight saving adds or removes.
local function time_of(date)
  local year, month, day = date:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
  return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = NOON_HOUR })
end

--- A date some whole days before or after another.
-- @param date string    The date as YYYY-MM-DD.
-- @param days integer   The days to add; negative goes back.
-- @return string  The date as YYYY-MM-DD. The month and the year roll over as needed.
function clock.add_days(date, days)
  return os.date('%Y-%m-%d', time_of(date) + days * SECONDS_A_DAY)
end

--- The day of the week of a date.
-- @param date string  The date as YYYY-MM-DD.
-- @return integer  1 for Sunday through 7 for Saturday, as os.date numbers them.
function clock.weekday(date)
  return os.date('*t', time_of(date)).wday
end

--- The greeting that suits an hour of the day.
-- @param hour integer  0 to 23, in local time.
-- @return string  'Good morning', 'Good afternoon' or 'Good evening'.
function clock.greeting(hour)
  if hour < NOON_HOUR then return 'Good morning' end
  if hour < EVENING_HOUR then return 'Good afternoon' end
  return 'Good evening'
end

return clock
