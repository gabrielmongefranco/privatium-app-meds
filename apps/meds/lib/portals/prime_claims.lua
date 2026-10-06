-- This file is part of Medication Tracker
-- apps/meds/lib/portals/prime_claims.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Reads the Recent Claims page of the Prime Therapeutics member website, with the
--          details of each claim open or closed. Pure Lua with no framework calls.
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
local text   = require 'text'

local prime_claims = {}

--- Configuration ---
prime_claims.NAME = 'Prime Therapeutics recent claims'

-- The labels that the claims layout prints above each value. The value is the next
-- line that holds anything.
local LABELS = {
  ['pharmacy id']            = 'pharmacy_npi',
  ['rx number']              = 'rx_number',
  ['days supply']            = 'days_supply',
  ['quantity']               = 'quantity',
  ['plan paid']              = 'plan_paid',
  ['deductible']             = 'deductible',
  ['patient responsibility'] = 'amount_paid',
}
local MONEY = { plan_paid = true, deductible = true, amount_paid = true }

-- The words the layout prints after the claim status, which are not part of it.
local ROW_ENDINGS = { 'Less Info', 'More Info' }

--- Lines ---

-- A claim starts on a line that opens with a date written month/day/year.
local function claim_start(line)
  local month, day, year, rest = line:match('^(%d%d)/(%d%d)/(%d%d%d%d)(.*)$')
  if not month then return nil end
  return year .. '-' .. month .. '-' .. day, rest
end

local next_filled, money = common.next_filled, common.money

--- The first line of a claim ---

-- The layout runs the columns of a row together: the drug name, the pharmacy name, the
-- amounts and the status, with nothing between them. The amounts start at the first
-- dollar sign, so everything before it is the two names.
local function read_row(rest, claim)
  local opened = false
  for _, ending in ipairs(ROW_ENDINGS) do
    local at = rest:find(ending, 1, true)
    if at then
      opened = opened or ending == 'Less Info'
      rest = rest:sub(1, at - 1)
    end
  end
  claim.details_open = opened

  local names, amounts = rest:match('^(.-)(%$.*)$')
  if not names then names, amounts = rest, '' end
  claim.names = text.clean(names)

  local listed = {}
  for amount in amounts:gmatch('%$%s*([%d,]*%.?%d*)') do listed[#listed + 1] = amount end
  claim.status = text.clean((amounts:gsub('%$%s*[%d,]*%.?%d*', '')))
  -- With both columns filled in, the second amount is what the patient paid. With one
  -- amount the column cannot be told, so the details have to say.
  if #listed == 2 and listed[2] ~= '' then claim.row_amount_paid = listed[2] end
end

--- The details of a claim ---

local function read_details(lines, from, to, claim)
  local name, at = next_filled(lines, from, to)
  if not name or LABELS[name:lower()] then return end
  claim.pharmacy_name = name
  local index = at + 1
  local address, address_at = next_filled(lines, index, to)
  if address and not LABELS[address:lower()] then
    claim.pharmacy_address = address
    local phone, phone_at = next_filled(lines, address_at + 1, to)
    if phone and not LABELS[phone:lower()] and phone:match('^[%d%s%(%)%-%.%+]+$') then
      claim.pharmacy_phone = phone
      index = phone_at + 1
    else
      index = address_at + 1
    end
  end

  while index <= to do
    local field = LABELS[lines[index]:lower()]
    if field then
      local value, value_at = next_filled(lines, index + 1, to)
      if value and not LABELS[value:lower()] then
        if MONEY[field] then claim[field] = money(value) else claim[field] = value end
        index = value_at
      end
    end
    index = index + 1
  end
end

--- Read ---

--- Whether a page is in the claims layout: a line opens with a date.
-- This layout is asked last, so the more particular layouts claim their text first.
-- @param page table  The page, from `common.page_of`.
-- @return boolean
function prime_claims.recognizes(page)
  for _, line in ipairs(page.lines) do
    if claim_start(line) then return true end
  end
  return false
end

--- Read the claims of the page.
-- @param page table  The page, from `common.page_of`.
-- @return table  A list of claims, in the shape `portal_reader.read` describes.
function prime_claims.read(page)
  local lines = page.lines
  local starts = {}
  for index, line in ipairs(lines) do
    if claim_start(line) then starts[#starts + 1] = index end
  end

  local claims = {}
  for position, index in ipairs(starts) do
    local claim = {}
    local rest
    claim.filled_on, rest = claim_start(lines[index])
    read_row(rest, claim)
    local last = (starts[position + 1] or (#lines + 1)) - 1
    if claim.details_open then read_details(lines, index + 1, last, claim) end

    -- The pharmacy name stands alone in the details, which is what tells the two
    -- names of the first line apart.
    local names = claim.names or ''
    local pharmacy = claim.pharmacy_name
    if pharmacy and #names > #pharmacy and names:sub(-#pharmacy) == pharmacy then
      claim.drug_name = text.clean(names:sub(1, #names - #pharmacy))
    else
      claim.drug_name = claim.names
      claim.names_joined = pharmacy == nil
    end
    claim.names = nil
    claim.amount_paid = claim.amount_paid or claim.row_amount_paid
    claim.row_amount_paid = nil
    claims[#claims + 1] = claim
  end
  return claims
end

return prime_claims
