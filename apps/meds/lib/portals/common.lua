-- This file is part of Medication Tracker
-- apps/meds/lib/portals/common.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: The pieces that every reader of a pasted portal page uses: lines, dates, amounts,
--          phone numbers and tab-separated rows. Pure Lua with no framework calls.
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

local common = {}

--- Configuration ---
-- Month names as portals write them, in full or cut short.
local MONTHS = {
  january = 1, february = 2, march = 3, april = 4, may = 5, june = 6, july = 7,
  august = 8, september = 9, october = 10, november = 11, december = 12,
  jan = 1, feb = 2, mar = 3, apr = 4, jun = 6, jul = 7, aug = 8, sep = 9, sept = 9,
  oct = 10, nov = 11, dec = 12,
}
local NO_BREAK_SPACE = '\194\160'   -- What a web page writes in a cell it leaves empty

--- Lines ---

--- Split a pasted text into the forms that the readers look at.
-- @param pasted string  The text as pasted.
-- @return table  `text`, the whole text with every line ending written as \n; `raw`,
--         its lines as they are, tabs kept; and `lines`, the same lines cleaned to one
--         line of plain text each, '' for a line that holds nothing.
function common.page_of(pasted)
  local normalized = pasted:gsub('\r\n?', '\n')
  local raw, lines = {}, {}
  for line in (normalized .. '\n'):gmatch('(.-)\n') do
    raw[#raw + 1] = line
    lines[#lines + 1] = common.clean(line) or ''
  end
  return { text = normalized, raw = raw, lines = lines }
end

--- Clean a value the way a typed field is cleaned, treating a no-break space as a space.
-- @param value string|nil
-- @return string|nil  The value on one line, or nil when nothing is left.
function common.clean(value)
  if type(value) ~= 'string' then return nil end
  return text.clean((value:gsub(NO_BREAK_SPACE, ' ')))
end

--- The first line from `from` to `to` that holds anything.
-- @return string|nil, integer  The line and its number, or nil and `to + 1`.
function common.next_filled(lines, from, to)
  for index = from, to do
    if lines[index] ~= '' then return lines[index], index end
  end
  return nil, to + 1
end

--- Values ---

--- A date written month/day/year, as year-month-day.
-- @param value string|nil  Such as '09/20/2026' or '9/2/2026'.
-- @return string|nil  Such as '2026-09-20', or nil when the value is not written so.
--         The calendar check is the caller's.
function common.us_date(value)
  local month, day, year = (value or ''):match('^%s*(%d%d?)/(%d%d?)/(%d%d%d%d)%s*$')
  if not month then return nil end
  return ('%s-%02d-%02d'):format(year, tonumber(month), tonumber(day))
end

--- A date written with the name of its month, as year-month-day.
-- @param value string|nil  Such as 'October 5, 2026', 'Oct 02, 2026' or 'Sept. 5 2026'.
-- @return string|nil  Such as '2026-10-05', or nil when the value is not written so.
function common.month_date(value)
  local name, day, year = (value or ''):match('^%s*(%a+)%.?%s+(%d%d?),?%s+(%d%d%d%d)%s*$')
  local month = name and MONTHS[name:lower()]
  if not month then return nil end
  return ('%s-%02d-%02d'):format(year, month, tonumber(day))
end

--- A date in any of the ways the portals write one, as year-month-day.
-- A value already written year-month-day is kept, so a spreadsheet that turned the
-- dates around still reads.
-- @param value string|nil
-- @return string|nil  The date, or the value as it was when it is written another way,
--         so the check that follows can say what is wrong with it.
function common.any_date(value)
  local cleaned = common.clean(value)
  if not cleaned then return nil end
  return common.us_date(cleaned) or common.month_date(cleaned) or cleaned
end

--- A money value as a portal prints it, without its sign.
-- A sign with no number after it is how some portals show an empty amount.
-- @param value string|nil
-- @return string|nil  Such as '1,240.12'. The commas stay for the check that follows.
function common.money(value)
  local cleaned = common.clean(value)
  if not cleaned then return nil end
  local amount = cleaned:gsub('^%$%s*', '')
  if amount == '' then return nil end
  return amount
end

--- The number that starts a value, such as the 90 of '90 tablets'.
-- @param value string|nil
-- @return string|nil  The number as text, or the value as it was when it starts with
--         no number, so the check that follows can refuse it.
function common.leading_number(value)
  local cleaned = common.clean(value)
  if not cleaned then return nil end
  return cleaned:match('^([%d,]*%.?%d+)') or cleaned
end

-- A line that is a phone number and nothing else, with at least seven digits.
local function is_phone(line)
  return line:match('^[%d%s%(%)%-%.%+]+$') ~= nil and #line:gsub('%D', '') >= 7
end
common.is_phone = is_phone

--- Split a phone number off the end of a line.
-- @param line string  Such as 'EXAMPLE PHARMACY 1 MAIN ST ANYTOWN, MI 48000 (555) 555-0100'.
-- @return string, string|nil  What comes before the number, and the number; or the line
--         and nil when it does not end in a ten-digit number.
function common.trailing_phone(line)
  local before, phone = line:match('^(.-)%s*(%(?%d%d%d%)?[%s%-%.]?%d%d%d[%s%-%.]%d%d%d%d)$')
  if not phone then return line, nil end
  return before, phone
end

--- Take a pharmacy apart into its name, address and phone number.
-- The cell either holds one part on each line, or runs them together on one line. On
-- one line the name ends before the first word made only of digits, which is where a
-- street address starts; a store number written '#1234' stays in the name.
-- @param cell string|nil
-- @return string|nil, string|nil, string|nil  The name, address and phone number.
function common.pharmacy_parts(cell)
  local parts = {}
  for line in ((cell or '') .. '\n'):gmatch('(.-)\n') do
    parts[#parts + 1] = common.clean(line)
  end
  if #parts == 0 then return nil end
  if #parts > 1 then
    local phone
    if is_phone(parts[#parts]) then phone = table.remove(parts) end
    local address = #parts > 1 and table.concat(parts, ', ', 2) or nil
    return parts[1], address, phone
  end

  local one, phone = common.trailing_phone(parts[1])
  if one == '' then return nil, nil, phone end
  local name, address = one:match('^(.-)%s+(%d+%s.*)$')
  if not name or name == '' then return one, nil, phone end
  return name, address, phone
end

--- Tab-separated rows ---

--- Split one row of text on its tabs. A cell may hold line breaks.
-- @param row string
-- @return table  The cells, as they are.
function common.cells(row)
  local cells = {}
  for cell in (row .. '\t'):gmatch('(.-)\t') do cells[#cells + 1] = cell end
  return cells
end

--- Read the rows of a table copied from a spreadsheet program.
-- A spreadsheet writes a cell that holds a line break, a tab or a quotation mark inside
-- quotation marks, and doubles each quotation mark in it.
-- @param whole string  The text, with \n line endings.
-- @return table  The rows, each a list of cells as written, quotation marks taken off.
function common.spreadsheet_rows(whole)
  local rows, row, at, size = {}, {}, 1, #whole
  while at <= size + 1 do
    local cell
    if whole:sub(at, at) == '"' then
      local parts, from = {}, at + 1
      while true do
        local quote = whole:find('"', from, true)
        if not quote then parts[#parts + 1] = whole:sub(from) at = size + 1 break end
        parts[#parts + 1] = whole:sub(from, quote - 1)
        if whole:sub(quote + 1, quote + 1) == '"' then
          parts[#parts + 1] = '"'
          from = quote + 2
        else
          at = quote + 1
          break
        end
      end
      cell = table.concat(parts) .. (whole:match('^[^\t\n]*', at) or '')
      at = at + #(whole:match('^[^\t\n]*', at) or '')
    else
      cell = whole:match('^[^\t\n]*', at) or ''
      at = at + #cell
    end
    row[#row + 1] = cell
    local ending = whole:sub(at, at)
    at = at + 1
    if ending ~= '\t' then
      rows[#rows + 1] = row
      row = {}
      if ending == '' then break end
    end
  end
  return rows
end

--- Find the columns of a table by the names in its heading row.
-- @param cells table  The cells of the heading row.
-- @param names table  Maps a heading, compared through `text.key`, to a field name.
-- @return table  Maps each field name to the number of its column.
function common.column_map(cells, names)
  local columns = {}
  for index, cell in ipairs(cells) do
    local field = names[text.key(common.clean(cell))]
    if field and not columns[field] then columns[field] = index end
  end
  return columns
end

return common
