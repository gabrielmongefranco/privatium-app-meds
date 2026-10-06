-- This file is part of Medication Tracker
-- apps/meds/lib/written_name.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Takes apart a medication name as a pharmacy or an insurer wrote it, and
--          compares it with the name and the strength of a catalog entry.
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

local written_name = {}

--- Configuration ---
-- The units a strength is written in. A number followed by one of these is a strength.
local UNITS = {
  mg = true, mcg = true, g = true, gm = true, ml = true, l = true, unit = true,
  units = true, iu = true, meq = true, ['%'] = true,
}
local SHORT_WORD = 3   -- A word this short in capitals is an abbreviation, such as ER or HFA

local function words_of(value)
  local words = {}
  for word in value:gmatch('%S+') do words[#words + 1] = word end
  return words
end

-- 'EXAMPLINE' becomes 'Exampline'. An abbreviation keeps its capitals.
local function as_name(word)
  if #word <= SHORT_WORD and word:match('^%u+$') then return word end
  local name = word:lower():gsub('^%a', string.upper):gsub('%-%a', string.upper)
  return name
end

-- A strength as a label prints it: lower case, a space between the number and the
-- unit, and 'mL' with its capital.
local function as_strength(value)
  local strength = value:lower():gsub('(%d)(%a)', '%1 %2'):gsub('%s+', ' ')
  strength = strength:gsub('ml', 'mL')
  return strength
end

local function is_unit(word)
  local first = word:lower():match('^([%a%%]+)')
  return first ~= nil and UNITS[first] == true
end

--- Take apart a name as a pharmacy or an insurer wrote it.
-- Such a name holds the drug, then the strength, then the form:
-- 'EXAMPLINE HCL 10 MG TABLET' gives 'Exampline HCL', '10 mg' and 'Tablet'.
-- @param written string|nil
-- @return table  { name = text or nil, strength = text or nil, rest = text or nil }.
--         A guess to show a person, who corrects it. Never stored unseen.
function written_name.parse(written)
  local words = words_of(text.clean(written) or '')
  local first_number
  for position, word in ipairs(words) do
    if position > 1 and word:match('^%d') then
      first_number = position
      break
    end
  end

  local parts = {}
  local name = {}
  for position = 1, (first_number or #words + 1) - 1 do name[#name + 1] = as_name(words[position]) end
  if #name > 0 then parts.name = table.concat(name, ' ') end
  if not first_number then return parts end

  local last = first_number
  if words[last]:match('^[%d%.,/%-]+$') and words[last + 1] and is_unit(words[last + 1]) then
    last = last + 1
  end
  parts.strength = as_strength(table.concat(words, ' ', first_number, last))

  local rest = {}
  for position = last + 1, #words do rest[#rest + 1] = as_name(words[position]) end
  if #rest > 0 then parts.rest = table.concat(rest, ' ') end
  return parts
end

--- Whether a written name starts with a name of a medication, word for word.
-- Words are split at spaces only, so 'Exampline' does not start 'EXAMPLINE-SAMPLAMIDE',
-- which is another product.
-- @param written string  The name as written.
-- @param name string|nil  A brand name or a generic name.
-- @return boolean
function written_name.starts_with(written, name)
  local name_words = words_of((text.clean(name) or ''):lower())
  if #name_words == 0 then return false end
  local written_words = words_of((text.clean(written) or ''):lower())
  for position, word in ipairs(name_words) do
    if written_words[position] ~= word then return false end
  end
  return true
end

--- Whether a written name holds a strength, as a whole.
-- The strength must stand alone: '5 mg' is not found in '0.5 mg', in '2.5 mg' or in
-- '875-5 mg', because those are other strengths.
-- @param written string   The name as written.
-- @param strength string|nil  The strength of a medication, such as '10 mg'.
-- @return boolean
function written_name.has_strength(written, strength)
  local wanted = text.clean(strength)
  if not wanted then return false end
  wanted = as_strength(wanted):lower()
  local spread = ' ' .. as_strength(text.clean(written) or ''):lower() .. ' '
  return spread:find(' ' .. wanted .. ' ', 1, true) ~= nil
end

return written_name
