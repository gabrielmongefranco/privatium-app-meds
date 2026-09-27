-- This file is part of Prescription Tracker
-- apps/meds/lib/validate.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Checks for the values a form sends. Each check returns the cleaned value, or
--          nil and a message for the person who typed it. Pure Lua with no framework
--          calls, so plain Lua can test it.
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

local text = require 'text'

local validate = {}

--- Configuration ---
local NPI_DIGITS         = 10   -- A National Provider Identifier is always 10 digits
local TEL_MINIMUM_DIGITS = 3    -- Shorter than any number a phone can dial
local DAYS_IN_MONTH      = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

-- Every check names its field with an article, as in 'the name', so a message reads
-- as a sentence: 'Enter the name.'
local function missing(label, required)
  if required then return nil, 'Enter ' .. label .. '.' end
  return nil
end

--- One line of text.
-- @param raw any         What the form sent.
-- @param label string    The field, with its article: 'the name'.
-- @param max integer     The most characters the field may hold.
-- @param required boolean|nil
-- @return string|nil, string|nil  The cleaned text, or nil and a message. An empty
--         optional field returns nil and no message.
function validate.text(raw, label, max, required)
  local value = text.clean(raw)
  if not value then return missing(label, required) end
  local length = text.length(value)
  if not length then
    return nil, 'Type ' .. label .. ' again. It holds characters the app cannot read.'
  end
  if length > max then
    return nil, 'Keep ' .. label .. ' to ' .. max .. ' characters or fewer.'
  end
  return value
end

local function is_leap_year(year)
  return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

--- A calendar date, written as YYYY-MM-DD.
-- The date input of a browser sends this form. A date that the calendar does not have,
-- such as 2026-02-30, is refused.
-- @return string|nil, string|nil
function validate.date(raw, label, required)
  local value = text.clean(raw)
  if not value then return missing(label, required) end
  local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  local days = month and DAYS_IN_MONTH[month]
  if days and month == 2 and is_leap_year(year) then days = 29 end
  if not days or day < 1 or day > days then
    return nil, 'Write ' .. label .. ' as year-month-day, such as 1980-01-31.'
  end
  return value
end

--- A date that must not come after another date.
-- Dates in YYYY-MM-DD form sort as text, so a plain comparison is enough.
-- @param value string|nil  A date that validate.date accepted, or nil.
-- @param limit string      The latest date allowed.
-- @param message string    What to say when the date is later.
-- @return string|nil, string|nil
function validate.not_after(value, limit, message)
  if value and value > limit then return nil, message end
  return value
end

--- A whole number within a range, typed with digits only.
-- @return integer|nil, string|nil
function validate.whole_number(raw, label, min, max, required)
  local value = text.clean(raw)
  if not value then return missing(label, required) end
  local number = value:match('^%d+$') and math.tointeger(tonumber(value))
  if not number or number < min or number > max then
    return nil, 'Write ' .. label .. ' as a whole number from ' .. min .. ' to ' .. max .. '.'
  end
  return number
end

--- A National Provider Identifier.
-- @return string|nil, string|nil
function validate.npi(raw)
  local value = text.clean(raw)
  if not value then return nil end
  if #value ~= NPI_DIGITS or not value:match('^%d+$') then
    return nil, 'Write the National Provider Identifier as ' .. NPI_DIGITS .. ' digits.'
  end
  return value
end

--- A phone or fax number. People write them in many ways, so only a digit is required.
-- @return string|nil, string|nil
function validate.phone(raw, label, max)
  local value, problem = validate.text(raw, label, max)
  if not value then return nil, problem end
  if not value:match('%d') then
    return nil, 'Write ' .. label .. ' with digits, such as (555) 555-0100.'
  end
  return value
end

--- An email address. The check is loose on purpose: one @, a dot after it, no spaces.
-- @return string|nil, string|nil
function validate.email(raw, max)
  local value, problem = validate.text(raw, 'the email address', max)
  if not value then return nil, problem end
  if not value:match('^[^%s@]+@[^%s@]+%.[^%s@]+$') then
    return nil, 'Write the email address in the form name@example.com.'
  end
  return value
end

--- A website address. Only http and https are accepted, because the address becomes a
-- link and any other scheme could run a script.
-- @return string|nil, string|nil
function validate.website(raw, max)
  local value, problem = validate.text(raw, 'the website', max)
  if not value then return nil, problem end
  local scheme = value:lower():match('^(https?)://[^%s]+$')
  if not scheme then
    return nil, 'Start the website with https://, such as https://example.com.'
  end
  return value
end

--- The part of a phone number that a tel: link can dial.
-- An extension, written after a letter, is left out: 555-0100 x12 dials 5550100.
-- @param phone string|nil  A number as stored.
-- @return string|nil  Digits with an optional leading plus sign, or nil when the number
--         is too short to dial.
function validate.tel_href(phone)
  if type(phone) ~= 'string' then return nil end
  local dialable = phone:match('^[^%a]*') or ''
  local digits = dialable:gsub('%D', '')
  if #digits < TEL_MINIMUM_DIGITS then return nil end
  if dialable:match('^%s*%+') then digits = '+' .. digits end
  return digits
end

return validate
