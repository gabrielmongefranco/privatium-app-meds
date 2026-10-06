-- This file is part of Medication Tracker
-- apps/meds/lib/authorization_words.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The levels of a prior authorization that needs attention, and the words for
--          each: expired, due, due soon.
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

local authorization_words = {}

--- Configuration ---
-- The levels of a prior authorization that needs attention, most urgent first.
authorization_words.LEVELS = {
  { key = 'expired',  title = 'Authorizations expired',  icon = 'shield-x',           badge = 'pv-badge-alert' },
  { key = 'due',      title = 'Authorizations due',      icon = 'shield-exclamation', badge = 'pv-badge-warn' },
  { key = 'due_soon', title = 'Authorizations due soon', icon = 'shield-exclamation', badge = 'pv-badge-warn' },
}

--- The level of a prior authorization.
-- @param days_left integer  Days until the expiration date; negative when it has passed.
-- @param due_within integer  The days for due.
-- @return string  'expired', 'due' or 'due_soon'. The caller has left out the ones
--         that expire later than the days for due soon.
function authorization_words.level(days_left, due_within)
  if days_left < 0 then return 'expired' end
  if days_left <= due_within then return 'due' end
  return 'due_soon'
end

--- The words for a prior authorization that needs attention.
-- @param days_left integer  Days until the expiration date; negative when it has passed.
-- @return string
function authorization_words.phrase(days_left)
  if days_left < -1 then return 'Expired ' .. -days_left .. ' days ago' end
  if days_left == -1 then return 'Expired 1 day ago' end
  if days_left == 0 then return 'Expires today' end
  if days_left == 1 then return 'Expires tomorrow' end
  return 'Expires in ' .. days_left .. ' days'
end

return authorization_words
