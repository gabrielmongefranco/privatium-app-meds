-- This file is part of Medication Tracker
-- apps/meds/lib/when_icon.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Pure Lua: the icons that stand beside the time of day a medication is taken,
--          such as a sunrise for Morning, so the time can be seen at a glance.
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

local when_icon = {}

--- Configuration ---
-- The Bootstrap Icons of each time of day, by the key of its words. A time a household
-- typed itself has no icon, since no picture would be sure to fit it.
local BY_TIME = {
  ['anytime']                   = { 'clock' },
  ['morning']                   = { 'sunrise' },
  ['noon']                      = { 'sun' },
  ['evening']                   = { 'sunset' },
  ['night at bedtime']          = { 'moon-stars' },
  ['night']                     = { 'moon' },
  ['morning and evening']       = { 'sunrise', 'sunset' },
  ['before meals']              = { 'hourglass-top' },
  ['with meals']                = { 'egg-fried' },
  ['after meals']               = { 'hourglass-bottom' },
  ['as needed']                 = { 'activity' },
  ['morning after breakfast']   = { 'brightness-alt-high' },
}
local NONE = {}

--- The icons for a time of day.
-- @param when_to_take string|nil  The time of day as stored, such as 'Night - At Bedtime'.
--        Case, punctuation and spacing do not matter.
-- @return table  A list of icon names, in the order to show them; empty for a time
--         the list lacks or for none. The icons are decorative: the words beside them
--         say the same. Reads no data.
function when_icon.of(when_to_take)
  return BY_TIME[text.key(when_to_take)] or NONE
end

return when_icon
