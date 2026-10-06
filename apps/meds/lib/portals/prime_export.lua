-- This file is part of Medication Tracker
-- apps/meds/lib/portals/prime_export.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Reads the claims history that the Prime Therapeutics member website exports, as a
--          spreadsheet program copies it: tab-separated, with a heading row. Pure Lua.
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

local prime_export = {}

--- Configuration ---
prime_export.NAME = 'Prime Therapeutics claims history export'

-- The headings of the export, compared through text.key, and the field each one fills.
-- Columns are found by heading, so the export can change their order.
local HEADINGS = {
  ['rx number']              = 'rx_number',
  ['date of service']        = 'filled_on',
  ['drug name']              = 'drug_name',
  ['quantity']               = 'quantity',
  ['days supply']            = 'days_supply',
  ['pharmacy']               = 'pharmacy',
  ['pharmacy id']            = 'pharmacy_npi',
  ['plan paid amount']       = 'plan_paid',
  ['patient responsibility'] = 'amount_paid',
  ['deductible']             = 'deductible',
  ['claim status']           = 'status',
}
local MONEY = { plan_paid = true, deductible = true, amount_paid = true }
local NEEDED = { 'filled_on', 'drug_name' }   -- The headings that make a table this export

--- Read ---

-- The heading row of the export, as the number of its row and its columns.
local function heading_of(rows)
  for index, cells in ipairs(rows) do
    local columns = common.column_map(cells, HEADINGS)
    local complete = true
    for _, field in ipairs(NEEDED) do complete = complete and columns[field] ~= nil end
    if complete then return index, columns end
  end
  return nil
end

--- Whether a page is the export: a tab-separated row holds its headings.
-- @param page table  The page, from `common.page_of`.
-- @return boolean
function prime_export.recognizes(page)
  for _, line in ipairs(page.raw) do
    if line:find('\t', 1, true) then
      local columns = common.column_map(common.cells(line), HEADINGS)
      if columns.filled_on and columns.drug_name then return true end
    end
  end
  return false
end

--- Read the claims of the export.
-- @param page table  The page, from `common.page_of`.
-- @return table  A list of claims, in the shape `portal_reader.read` describes. Every
--         claim has its details, since the export holds them all.
function prime_export.read(page)
  local rows = common.spreadsheet_rows(page.text)
  local heading, columns = heading_of(rows)
  local claims = {}
  if not heading then return claims end

  for index = heading + 1, #rows do
    local cells = rows[index]
    local function cell(field)
      local at = columns[field]
      return at and cells[at]
    end
    local filled_on, drug_name = common.clean(cell('filled_on')), common.clean(cell('drug_name'))
    -- A row with neither a date nor a name is an empty row of the spreadsheet.
    if filled_on or drug_name then
      local claim = { details_open = true, drug_name = drug_name, filled_on = common.any_date(filled_on) }
      for _, field in ipairs({ 'rx_number', 'quantity', 'days_supply', 'pharmacy_npi', 'status' }) do
        claim[field] = common.clean(cell(field))
      end
      for field in pairs(MONEY) do claim[field] = common.money(cell(field)) end
      claim.pharmacy_name, claim.pharmacy_address, claim.pharmacy_phone =
        common.pharmacy_parts(cell('pharmacy'))
      -- An export without the status column says nothing about payment.
      claim.has_status = columns.status ~= nil
      claims[#claims + 1] = claim
    end
  end
  return claims
end

return prime_export
