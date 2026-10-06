-- This file is part of Medication Tracker
-- apps/meds/lib/portals/dromos_statement.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Reads the Patient Tax Statement page of DromosPTM pharmacy websites: one row per
--          fill, with its cells separated by tabs. Pure Lua with no framework calls.
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

local dromos_statement = {}

--- Configuration ---
dromos_statement.NAME = 'DromosPTM patient tax statement'

-- The headings of the page, compared through text.key, and the field each one fills.
local HEADINGS = {
  ['date sold']                = 'filled_on',
  ['rx number']                = 'rx_number',
  ['medication']               = 'drug_name',
  ['quantity']                 = 'quantity',
  ['days supply']              = 'days_supply',
  ['doctor']                   = 'doctor',
  ['pharmacy']                 = 'pharmacy',
  ['primary insurance cash']   = 'insurance',
  ['insurance portion']        = 'plan_paid',
  ['patient copay']            = 'amount_paid',
}
-- The columns in the order the page shows them. A copy rarely holds the heading row, so
-- this order is the one used without it. The first column holds a button and no value.
local ORDER = {
  'toggle', 'filled_on', 'rx_number', 'drug_name', 'quantity', 'days_supply', 'doctor',
  'pharmacy', 'insurance', 'plan_paid', 'amount_paid',
}

--- Rows ---

-- Whether a cell holds nothing, as the button column does.
local function blank(cell)
  return common.clean(cell) == nil
end

-- A row of the table starts on a line with an empty cell, then the date the fill was
-- sold, then a prescription number made of digits.
local function starts_row(line)
  local cells = common.cells(line)
  return #cells >= 3 and blank(cells[1]) and common.month_date(common.clean(cells[2])) ~= nil
    and (common.clean(cells[3]) or ''):match('^%d+$') ~= nil
end

-- The heading row, when the copy holds it.
local function heading_columns(line)
  local columns = common.column_map(common.cells(line), HEADINGS)
  if columns.filled_on and columns.amount_paid then return columns end
  return nil
end

local function default_columns()
  local columns = {}
  for index, field in ipairs(ORDER) do columns[field] = index end
  return columns
end

--- Read ---

--- Whether a page is the tax statement: a line starts a row of its table.
-- @param page_text table  The page, from `common.page_of`.
-- @return boolean
function dromos_statement.recognizes(page_text)
  for _, line in ipairs(page_text.raw) do
    if starts_row(line) then return true end
  end
  return false
end

-- Counts the tabs of a text.
local function tabs_in(value)
  return select(2, value:gsub('\t', ''))
end

--- Read the fills of the page.
-- A cell of the table can hold a line break: the medication has its product number on a
-- second line, and the pharmacy its phone number. So a row runs on over the next lines
-- until it has as many cells as the table has columns.
-- @param page_text table  The page, from `common.page_of`.
-- @return table, integer  A list of claims, in the shape `portal_reader.read`
--         describes, and the number of rows left out because they miss columns.
function dromos_statement.read(page_text)
  local raw = page_text.raw
  local columns, width = default_columns(), #ORDER
  local rows = {}
  local index = 1
  while index <= #raw do
    local line = raw[index]
    local heading = heading_columns(line)
    if heading then
      columns, width = heading, #common.cells(line)
      index = index + 1
    elseif starts_row(line) then
      local joined = line
      index = index + 1
      while index <= #raw and tabs_in(joined) < width - 1 and not starts_row(raw[index]) do
        joined = joined .. '\n' .. raw[index]
        index = index + 1
      end
      rows[#rows + 1] = joined
    else
      index = index + 1
    end
  end

  local claims, left_out = {}, 0
  for _, row in ipairs(rows) do
    local cells = common.cells(row)
    -- The page hides columns in a narrow window, and then a cell cannot be told by its
    -- place. Such a row is left out rather than read into the wrong fields.
    if #cells ~= width then
      left_out = left_out + 1
    else
      local function cell(field) return cells[columns[field]] end
      local name = (cell('drug_name') or ''):match('^[^\n]*')
      local claim = {
        details_open = true, has_status = false,
        filled_on    = common.any_date(cell('filled_on')),
        rx_number    = common.clean(cell('rx_number')),
        drug_name    = common.clean(name),
        quantity     = common.clean(cell('quantity')),
        days_supply  = common.clean(cell('days_supply')),
        plan_paid    = common.money(cell('plan_paid')),
        amount_paid  = common.money(cell('amount_paid')),
      }
      claim.pharmacy_name, claim.pharmacy_address, claim.pharmacy_phone =
        common.pharmacy_parts(cell('pharmacy'))
      claims[#claims + 1] = claim
    end
  end
  return claims, left_out
end

--- The sentence that tells how many rows were left out.
-- @param count integer
-- @return string
function dromos_statement.left_out_note(count)
  return page.counted(count, 'row misses', 'rows miss')
    .. ' columns, so ' .. (count == 1 and 'it is' or 'they are')
    .. ' not listed. Make the window wider, then copy the table again.'
end

return dromos_statement
