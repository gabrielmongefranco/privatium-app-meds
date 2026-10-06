-- This file is part of Medication Tracker
-- apps/meds/lib/portals/mychart.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Reads the Medications page of Epic MyChart. The page lists prescriptions, not fills,
--          so each medication that shows a last fill date gives one fill. Pure Lua.
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

local common = require 'portals.common'
local page   = require 'page'

local mychart = {}

--- Configuration ---
mychart.NAME = 'MyChart medications'

-- The labels the page prints, in lower case, and the field each one fills. A browser
-- may copy the value on the same line as its label ('Day supply90') or on the next.
local LABELS = {
  { 'prescription number', 'rx_number' },
  { 'quantity',            'quantity' },
  { 'days supply',         'days_supply' },
  { 'day supply',          'days_supply' },
  { 'last filled',         'filled_on' },
}
-- The headings of the parts of a medication, which are never a value.
local HEADINGS = {
  ['prescription details'] = true, ['refill details'] = true,
  ['pharmacy details'] = true, ['details'] = true,
}
local PHARMACY = 'pharmacy details'
local END_OF_PHARMACY = 'map'   -- The link the page prints after a pharmacy
local LEARN_MORE = 'learn more'
local OTHER_NAMES = { 'generic name:', 'commonly known as:' }

--- Lines ---

local function starts_with(line, prefix)
  return line:lower():sub(1, #prefix) == prefix
end

-- A line that gives another name of the medication above it.
local function other_name(line)
  for _, prefix in ipairs(OTHER_NAMES) do
    if starts_with(line, prefix) then return true end
  end
  return false
end

-- A medication starts on its name, the line just before another name or the link to
-- learn more about it.
local function starts_medication(lines, index)
  local line, following = lines[index], lines[index + 1]
  if not following or other_name(line) or line:lower() == LEARN_MORE then return false end
  return other_name(following) or following:lower() == LEARN_MORE
end

-- The label that a line starts with, and what follows it on the line.
local function label_of(line)
  for _, label in ipairs(LABELS) do
    if starts_with(line, label[1]) then
      return label[2], common.clean((line:sub(#label[1] + 1):gsub('^%s*:', '')))
    end
  end
  return nil
end

--- Read ---

--- Whether a page is the medications page: it has the parts of a prescription.
-- @param page_text table  The page, from `common.page_of`.
-- @return boolean
function mychart.recognizes(page_text)
  local refill, pharmacy = false, false
  for _, line in ipairs(page_text.lines) do
    local lower = line:lower()
    refill = refill or lower == 'refill details'
    pharmacy = pharmacy or lower == PHARMACY
  end
  return refill and pharmacy
end

-- Reads one medication, from its name on line `from` to line `to`.
local function read_medication(lines, from, to)
  local claim = { drug_name = lines[from], details_open = true, has_status = false }
  local index = from + 1
  while index <= to do
    local line = lines[index]
    local field, value = label_of(line)
    if field then
      local following = lines[index + 1]
      if not value and index < to and not label_of(following) and not HEADINGS[following:lower()] then
        value, index = following, index + 1
      end
      claim[field] = value
    elseif line:lower() == PHARMACY then
      local parts = {}
      index = index + 1
      while index <= to and lines[index]:lower() ~= END_OF_PHARMACY do
        parts[#parts + 1] = lines[index]
        index = index + 1
      end
      claim.pharmacy_name = parts[1]
      if parts[2] and common.is_phone(parts[2]) then
        claim.pharmacy_phone = parts[2]
      else
        claim.pharmacy_address = parts[2]
        if parts[3] and common.is_phone(parts[3]) then claim.pharmacy_phone = parts[3] end
      end
    end
    index = index + 1
  end
  claim.filled_on = common.any_date(claim.filled_on)
  claim.quantity = common.leading_number(claim.quantity)
  return claim
end

--- Read the fills of the page.
-- @param page_text table  The page, from `common.page_of`.
-- @return table, integer  A list of claims, in the shape `portal_reader.read`
--         describes, and the number of medications left out because they show no fill
--         date.
function mychart.read(page_text)
  local lines = {}
  for _, line in ipairs(page_text.lines) do
    if line ~= '' then lines[#lines + 1] = line end
  end
  local starts = {}
  for index = 1, #lines do
    if starts_medication(lines, index) then starts[#starts + 1] = index end
  end

  local claims, left_out = {}, 0
  for position, from in ipairs(starts) do
    local claim = read_medication(lines, from, (starts[position + 1] or (#lines + 1)) - 1)
    if claim.filled_on then claims[#claims + 1] = claim else left_out = left_out + 1 end
  end
  return claims, left_out
end

--- The sentence that tells how many medications were left out.
-- @param count integer
-- @return string
function mychart.left_out_note(count)
  return page.counted(count, 'medication shows', 'medications show')
    .. ' no fill date, so ' .. (count == 1 and 'it is' or 'they are') .. ' not listed.'
end

return mychart
