-- This file is part of Prescription Tracker
-- apps/meds/lib/periods.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: The time periods the history can be narrowed to, and the first and last
--          date of each, worked out from today's date.
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

local periods = {}

--- Configuration ---
local WEEK_STARTS_ON = 1    -- os.date's weekday number: 1 is Sunday, as on US calendars
local RECENT_DAYS    = 90   -- "Last 90 days" is today and the 89 days before it
local SECONDS_A_DAY  = 24 * 60 * 60

-- The periods that move with today, in the order the drop-down lists them.
local NAMED = {
  { value = 'this-week',    label = 'This week' },
  { value = 'this-month',   label = 'This month' },
  { value = 'last-week',    label = 'Last week' },
  { value = 'last-month',   label = 'Last month' },
  { value = 'last-90-days', label = 'Last ' .. RECENT_DAYS .. ' days' },
}

--- Dates ---

-- Noon keeps a shift by whole days clear of the hour that daylight saving adds or removes.
local function time_of(date)
  local year, month, day = date:match('^(%d%d%d%d)-(%d%d)-(%d%d)$')
  return os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = 12 })
end

local function date_of(time) return os.date('%Y-%m-%d', time) end

local function shifted(date, days) return date_of(time_of(date) + days * SECONDS_A_DAY) end

local function week_start(today)
  local weekday = os.date('*t', time_of(today)).wday
  return shifted(today, -((weekday - WEEK_STARTS_ON) % 7))
end

--- Periods ---

--- The choices of the time period drop-down.
-- @param years table  The years with a fill, newest first, as 'YYYY' strings.
-- @return table  { value, label } rows: the periods that move with today, then one row
--         for each year. "Any time" is the drop-down's empty choice, so it is not here.
function periods.options(years)
  local options = {}
  for _, named in ipairs(NAMED) do options[#options + 1] = { value = named.value, label = named.label } end
  for _, year in ipairs(years) do options[#options + 1] = { value = year, label = 'Year: ' .. year } end
  return options
end

--- The first and last date of a period.
-- @param code string  '' for any time, a value of periods.options, or a year as 'YYYY'.
-- @param today string  Today's date as YYYY-MM-DD.
-- @return string|nil, string|nil  Both dates as YYYY-MM-DD, '' for an open end, or nil
--         when the code names no period.
function periods.range(code, today)
  if code == '' then return '', '' end
  if type(code) ~= 'string' then return nil end
  if code:match('^%d%d%d%d$') then return code .. '-01-01', code .. '-12-31' end
  if code == 'this-week' then return week_start(today), today end
  if code == 'last-week' then
    local this_week = week_start(today)
    return shifted(this_week, -7), shifted(this_week, -1)
  end
  local this_month = today:sub(1, 8) .. '01'
  if code == 'this-month' then return this_month, today end
  if code == 'last-month' then
    local last_day = shifted(this_month, -1)
    return last_day:sub(1, 8) .. '01', last_day
  end
  if code == 'last-90-days' then return shifted(today, -(RECENT_DAYS - 1)), today end
  return nil
end

--- The name of a period, for a sentence.
-- @param code string  A code that periods.range accepts.
-- @return string  Such as 'Last month' or 'Year: 2025', or 'Any time' for ''.
function periods.label(code)
  if code == '' then return 'Any time' end
  if code:match('^%d%d%d%d$') then return 'Year: ' .. code end
  for _, named in ipairs(NAMED) do
    if named.value == code then return named.label end
  end
  return code
end

return periods
