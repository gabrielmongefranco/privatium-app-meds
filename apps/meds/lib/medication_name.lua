-- This file is part of Prescription Tracker
-- apps/meds/lib/medication_name.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-03
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

--- The short name: the brand name, the generic name in brackets, the strength, then
-- the package. A carton of 2 is another thing to refill than a carton of 6, so the
-- package is part of the name. A part that is missing is left out, brackets included:
--   Examplol, Exampline, 10 mg           ->  Examplol (Exampline) 10 mg
--   Examplol, Exampline, 10 mg, 2, Pack  ->  Examplol (Exampline) 10 mg 2 Pack
--   nil,      Exampline, 10 mg           ->  Exampline 10 mg
--   Examplol, nil,       nil             ->  Examplol
-- @param brand string|nil
-- @param generic string|nil
-- @param strength string|nil
-- @param package_size string|nil  How much one package holds, such as '2' or '60 mL'.
-- @param package_type string|nil  The kind of package, such as 'Pack' or 'Bottle'.
-- @return string|nil  The name, or nil when there is neither a brand nor a generic name.
function medication_name.short(brand, generic, strength, package_size, package_type)
  local name
  if brand and generic then
    name = brand .. ' (' .. generic .. ')'
  else
    name = brand or generic
  end
  if not name then return nil end
  if strength then name = name .. ' ' .. strength end
  if package_size then name = name .. ' ' .. package_size end
  if package_type then name = name .. ' ' .. package_type end
  return name
end

--- The full name: the generic name, the brand name in brackets, then every other part
-- that is filled in, the way the view v_medication builds it:
--   Exampline, Examplol, 10 mg, Oral, Tablet  ->  Exampline (Examplol) 10 mg Oral Tablet
-- A tracked medication starts with this name as its preferred name.
-- @param generic string|nil
-- @param brand string|nil
-- @param strength string|nil
-- @param route string|nil
-- @param form string|nil
-- @param package_size string|nil
-- @param package_type string|nil
-- @return string|nil  The name, or nil when there is neither a brand nor a generic name.
function medication_name.full(generic, brand, strength, route, form, package_size, package_type)
  local name
  if generic and brand then
    name = generic .. ' (' .. brand .. ')'
  else
    name = generic or brand
  end
  if not name then return nil end
  if strength then name = name .. ' ' .. strength end
  if route then name = name .. ' ' .. route end
  if form then name = name .. ' ' .. form end
  if package_size then name = name .. ' ' .. package_size end
  if package_type then name = name .. ' ' .. package_type end
  return name
end

return medication_name
