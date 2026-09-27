-- This file is part of Prescription Tracker
-- apps/meds/lib/medication_name.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Builds the short name of a medication from its parts. Pure Lua with no
--          framework calls, so plain Lua can test it.
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

local medication_name = {}

--- The short name: the brand name, the generic name in brackets, then the strength.
-- A part that is missing is left out, brackets included:
--   Examplol, Exampline, 10 mg  ->  Examplol (Exampline) 10 mg
--   nil,      Exampline, 10 mg  ->  Exampline 10 mg
--   Examplol, nil,       nil    ->  Examplol
-- @param brand string|nil
-- @param generic string|nil
-- @param strength string|nil
-- @return string|nil  The name, or nil when there is neither a brand nor a generic name.
function medication_name.short(brand, generic, strength)
  local name
  if brand and generic then
    name = brand .. ' (' .. generic .. ')'
  else
    name = brand or generic
  end
  if not name then return nil end
  if strength then name = name .. ' ' .. strength end
  return name
end

return medication_name
