-- This file is part of Prescription Tracker
-- apps/meds/lib/authorization_watch.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Finds the prior authorizations that need attention: the latest one of a medication
--          in use, when it ends soon or has ended.
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

local authorization_watch = {}

--- The prior authorizations that end within the days of notice, or have ended.
-- Only the latest authorization of each person and medication counts, so one that was
-- renewed raises nothing.
-- @param person_id string  The id of one person, or '' for everyone.
-- @return table  Grain: one row per person per medication in use whose latest prior
--         authorization needs attention, soonest first.
function authorization_watch.ending(person_id)
  local rows = pv.query([[
    SELECT pa.id, pa.valid_to,
           pm.id            AS entry_id,
           p.display_name   AS person_name,
           m.short_name     AS medication_name,
           CAST(julianday(pa.valid_to) - julianday(date('now', 'localtime')) AS INTEGER) AS days_left
      FROM prior_authorization pa
      JOIN person_medication pm                       -- many:1; the list entry of the pair
        ON pm.person_id = pa.person_id AND pm.medication_id = pa.medication_id
      JOIN person p     ON p.id = pa.person_id        -- many:1
      JOIN medication m ON m.id = pa.medication_id    -- many:1
     CROSS JOIN v_reminder_setting r                  -- exactly one row
     WHERE pm.status <> 'not_taking'
       AND pa.valid_to = (SELECT max(later.valid_to)
                            FROM prior_authorization later
                           WHERE later.person_id = pa.person_id
                             AND later.medication_id = pa.medication_id)
       AND pa.valid_to <= date('now', 'localtime', '+' || r.authorization_notice_days || ' days')
       AND (?1 = '' OR pa.person_id = ?1)
     ORDER BY pa.valid_to, pa.id]], { person_id })
  for _, row in ipairs(rows) do
    if row.days_left < -1 then
      row.phrase = 'Authorization ended ' .. -row.days_left .. ' days ago'
    elseif row.days_left == -1 then
      row.phrase = 'Authorization ended 1 day ago'
    elseif row.days_left == 0 then
      row.phrase = 'Authorization ends today'
    elseif row.days_left == 1 then
      row.phrase = 'Authorization ends tomorrow'
    else
      row.phrase = 'Authorization ends in ' .. row.days_left .. ' days'
    end
  end
  return rows
end

return authorization_watch
