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
local authorization_words = require 'authorization_words'

local authorization_watch = {}

--- The prior authorizations that expire within the days for due soon, or have expired.
-- Only the latest authorization of each person and medication counts, so one that was
-- renewed raises nothing.
-- @param person_id string  The id of one person, or '' for everyone.
-- @return table  Grain: one row per person per medication in use whose latest prior
--         authorization needs attention, soonest first. Each row has `level`, `phrase`,
--         `badge` and `icon_name`.
function authorization_watch.ending(person_id)
  local rows = pv.query([[
    SELECT pa.id, pa.valid_to,
           pm.id            AS entry_id,
           p.display_name   AS person_name,
           m.short_name     AS medication_name,
           pr.name          AS prescriber_name,
           pr.phone         AS prescriber_phone,
           r.authorization_due_within_days AS due_within,
           CAST(julianday(pa.valid_to) - julianday(date('now', 'localtime')) AS INTEGER) AS days_left
      FROM prior_authorization pa
      JOIN person_medication pm                       -- many:1; the list entry of the pair
        ON pm.person_id = pa.person_id AND pm.medication_id = pa.medication_id
      JOIN person p     ON p.id = pa.person_id        -- many:1
      JOIN medication m ON m.id = pa.medication_id    -- many:1
      LEFT JOIN prescriber pr ON pr.id = pm.prescriber_id   -- many:0..1
     CROSS JOIN v_reminder_setting r                  -- exactly one row
     WHERE pm.status <> 'not_taking'
       AND pa.valid_to = (SELECT max(later.valid_to)
                            FROM prior_authorization later
                           WHERE later.person_id = pa.person_id
                             AND later.medication_id = pa.medication_id)
       AND pa.valid_to <= date('now', 'localtime', '+' || r.authorization_notice_days || ' days')
       AND (?1 = '' OR pa.person_id = ?1)
     ORDER BY pa.valid_to, pa.id]], { person_id })
  local by_key = {}
  for _, level in ipairs(authorization_words.LEVELS) do by_key[level.key] = level end
  for _, row in ipairs(rows) do
    row.level = authorization_words.level(row.days_left, row.due_within)
    row.phrase = authorization_words.phrase(row.days_left)
    row.badge, row.icon_name = by_key[row.level].badge, by_key[row.level].icon
  end
  return rows
end

return authorization_watch
