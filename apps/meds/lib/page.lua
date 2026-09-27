-- This file is part of Prescription Tracker
-- apps/meds/lib/page.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Small helpers that every screen shares: the notice shown after a save, the
--          list of problems at the top of a form, and the wording of a count. Pure Lua
--          with no framework calls, so plain Lua can test it.
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

local page = {}

--- Configuration ---
-- A page address carries a code, never a sentence, so nothing typed into an address
-- can appear on a page. A code that is not listed here shows nothing.
local NOTICES = {
  saved   = 'Saved.',
  removed = 'Removed. Privatium keeps the original record in its log.',
  missing = 'That record is not in the app. It may have been removed.',
  unnamed = 'Name your household first. The reminder settings are saved with it.',
  named   = 'Saved. The search now finds this medication by that name.',
  unread  = 'The app found no fills in that text. Open the details of each fill in the portal, then copy the list again.',
  merged  = 'Merged. The fills, the list entries and the names now belong to this medication.',
}

--- The sentence for a notice code.
-- @param code any  The value of the notice parameter in the page address.
-- @return string|nil  The sentence, or nil for a code that is not known.
function page.notice(code)
  if type(code) ~= 'string' then return nil end
  return NOTICES[code]
end

--- The problems of a form, in the order of its fields.
-- @param errors table  Messages keyed by field name.
-- @param fields table  The field names, in the order the form shows them.
-- @return table  A list of { field = name, message = text }. Empty when nothing failed.
function page.problems(errors, fields)
  local list = {}
  for _, field in ipairs(fields) do
    if errors[field] then
      list[#list + 1] = { field = field, message = errors[field] }
    end
  end
  return list
end

--- A count with its noun, singular or plural: '1 fill', '3 fills'.
-- @param count integer
-- @param singular string
-- @param plural string
-- @return string
function page.counted(count, singular, plural)
  if count == 1 then return '1 ' .. singular end
  return count .. ' ' .. plural
end

--- An error text with every quoted value taken out.
-- The framework quotes the value it refused, and that value may be health information,
-- so the text is masked before it goes to the diagnostic log.
-- @param message any
-- @return string
function page.masked(message)
  local masked = tostring(message):gsub('"[^"]*"', '"..."'):gsub("'[^']*'", "'...'")
  return masked
end

return page
