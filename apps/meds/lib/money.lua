-- This file is part of Prescription Tracker
-- apps/meds/lib/money.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Money as the screens show it: an exact amount with its currency sign.
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

local money = {}

--- Configuration ---
-- TODO: let the household choose its currency; every amount shows in US dollars.
-- views/_money.lsp writes the same sign for the templates.
money.SYMBOL = '$'

--- An amount with its currency sign, grouped as Privatium's locale setting says.
-- @param amount string|nil  Exact decimal text, as a DECIMAL column or decimal_sum returns it.
-- @return string|nil  Such as '$1,012.50', or nil when there is no amount.
function money.format(amount)
  if amount == nil then return nil end
  return money.SYMBOL .. fmt.money(amount)
end

return money
