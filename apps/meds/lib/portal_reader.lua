-- This file is part of Medication Tracker
-- apps/meds/lib/portal_reader.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Takes the text of a pasted portal page apart into claims. It works out which page
--          the text came from and hands it to the reader of that page, under lib/portals/.
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

local portal_reader = {}

--- Configuration ---
-- The pages the app reads, asked in this order. The first page that recognizes the text
-- reads it, so the most particular layouts come first and the claims page, which only
-- looks for lines that open with a date, comes last. Each require is in parentheses
-- because require also returns where it found the module.
local LAYOUTS = {
  (require 'portals.prime_export'),
  (require 'portals.dromos_statement'),
  (require 'portals.mychart'),
  (require 'portals.prime_claims'),
}

--- The names of the pages the app reads, in the order they are asked.
-- @return table  A list of names.
function portal_reader.names()
  local names = {}
  for _, layout in ipairs(LAYOUTS) do names[#names + 1] = layout.NAME end
  return names
end

--- Read the claims of a pasted portal page.
-- The readers only take text apart. They check no value and trust none; the caller
-- checks every value before it saves anything.
-- @param pasted string  The text as pasted.
-- @return table, table|nil  A list of claims, and what was read. Each claim holds what
--         was found of: filled_on (YYYY-MM-DD when the page wrote a date the readers
--         know), drug_name, pharmacy_name, pharmacy_address, pharmacy_phone,
--         pharmacy_npi, rx_number, days_supply, quantity, amount_paid, plan_paid,
--         deductible, status, details_open (whether the details were in the text) and
--         has_status (false when the page tells nothing about payment). What was read
--         holds `name`, the name of the page, and `left_out_note`, a sentence about
--         what the page held that is not a fill, or nil. It is nil, and the list is
--         empty, when no reader knows the text.
function portal_reader.read(pasted)
  if type(pasted) ~= 'string' then return {}, nil end
  local page = common.page_of(pasted)
  for _, layout in ipairs(LAYOUTS) do
    if layout.recognizes(page) then
      local claims, left_out = layout.read(page)
      local about = { name = layout.NAME }
      if left_out and left_out > 0 then about.left_out_note = layout.left_out_note(left_out) end
      return claims, about
    end
  end
  return {}, nil
end

return portal_reader
