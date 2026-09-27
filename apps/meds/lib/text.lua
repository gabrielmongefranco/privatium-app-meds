-- This file is part of Prescription Tracker
-- apps/meds/lib/text.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Cleans text that a person typed or pasted, and builds the key that two names
--          are compared by. Pure Lua with no framework calls, so plain Lua can test it.
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

local text = {}

--- Clean one line of typed text.
-- Control characters, line breaks included, become spaces, because every field that
-- uses this holds one line. Runs of spaces become one space.
-- @param value any  What the form sent. Anything but a string counts as empty.
-- @return string|nil  The cleaned text, or nil when nothing is left.
function text.clean(value)
  if type(value) ~= 'string' then return nil end
  local cleaned = value:gsub('%c', ' '):gsub('%s+', ' '):match('^ ?(.-) ?$')
  if cleaned == '' then return nil end
  return cleaned
end

--- Count the characters of a text, not its bytes.
-- @param value string
-- @return integer|nil  The count, or nil when the text is not valid UTF-8.
function text.length(value)
  return utf8.len(value)
end

--- Build the key that two names are compared by.
-- Two names with the same key are the same name: 'Z-Pak', 'z pak' and 'Z.PAK' all give
-- 'z pak'. Only ASCII letters change case; other letters compare as they are written.
-- @param value string|nil
-- @return string  The key, or '' for nil.
function text.key(value)
  if type(value) ~= 'string' then return '' end
  local key = value:lower():gsub('[%p%c]', ' '):gsub('%s+', ' '):match('^ ?(.-) ?$')
  return key
end

--- A decimal number without the zeros that say nothing.
-- '30.000' becomes '30' and '2.500' becomes '2.5'. The number stays text from start to
-- end, so an exact decimal never passes through a float.
-- @param value any  A number as text, as a DECIMAL column returns it.
-- @return string|nil  The shorter text, or nil for nil.
function text.plain_number(value)
  if value == nil then return nil end
  local number = tostring(value)
  if not number:find('.', 1, true) then return number end
  number = number:gsub('0+$', ''):gsub('%.$', '')
  return number
end

return text
