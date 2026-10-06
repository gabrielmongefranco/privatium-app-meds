-- This file is part of Medication Tracker
-- apps/meds/lib/starter.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-03
-- Last Modified: 2026-10-03
-- Summary: Loads the starter catalog into an app whose catalog is empty, so a fresh
--          node has medications to pick from without a step in the settings.
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

local pv = require 'privatium'

local starter = {}

--- Configuration ---
-- Events written in one batch. The node refuses a batch above its size limit, and a
-- smaller batch keeps each write short.
local BATCH_SIZE = 1000

--- Load the starter catalog when the catalog holds no medication at all.
-- The records carry fixed ids, so a load on a second device of the same household
-- repeats the same records instead of doubling them.
-- Call it from a page that shows or searches the catalog, before reading it.
-- @return boolean  True when the catalog was loaded by this call.
function starter.ensure()
  local count = pv.query1('SELECT count(*) AS medications FROM medication').medications
  if count > 0 then return false end

  local events = require 'starter_catalog'
  for first = 1, #events, BATCH_SIZE do
    local last = math.min(first + BATCH_SIZE - 1, #events)
    pv.batch(function(tx)
      for index = first, last do
        local event = events[index]
        tx.append(event.t, event.i, event.d)
      end
    end)
  end
  pv.log('info', 'loaded the starter catalog: ' .. #events .. ' records')
  return true
end

return starter
