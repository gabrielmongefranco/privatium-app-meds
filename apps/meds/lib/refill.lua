-- This file is part of Prescription Tracker
-- apps/meds/lib/refill.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-03
-- Summary: The words and the group for a refill status. Pure Lua with no framework calls, so
--          plain Lua can test it.
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

local refill = {}

--- Configuration ---
-- The groups of the Refills page, in the order the page shows them. `alert` marks the
-- groups that ask for action.
refill.GROUPS = {
  { key = 'overdue',  title = 'Overdue',             alert = true,  icon = 'exclamation-triangle', badge = 'pv-badge-alert' },
  { key = 'due',      title = 'Due',                 alert = true,  icon = 'clock',                badge = 'pv-badge-warn' },
  { key = 'due_soon', title = 'Due soon',            alert = true,  icon = 'calendar-event',       badge = 'pv-badge-warn' },
  { key = 'as_needed', title = 'As needed',          alert = false, icon = 'capsule',              badge = 'pv-badge-muted' },
  { key = 'missing',  title = 'Missing information', alert = false, icon = 'question-circle',      badge = 'pv-badge-muted' },
  { key = 'not_due',  title = 'Not due yet',         alert = false, icon = 'check-circle',         badge = 'pv-badge-ok' },
  { key = 'paused',   title = 'Paused',              alert = false, icon = 'pause-circle',         badge = 'pv-badge-muted' },
}

--- The group of the Refills page that a medication belongs to.
-- Only a medication taken regularly raises an alert. One taken as needed, or paused,
-- shows its dates without one.
-- @param status string          The status of the tracked medication.
-- @param refill_status string   The refill status from v_active_medication.
-- @param days_supply_missing boolean|integer  Whether the last fill lacks a days supply.
-- @return string|nil  A key of refill.GROUPS, or nil for a medication no longer taken.
function refill.group(status, refill_status, days_supply_missing)
  if status == 'not_taking' then return nil end
  if status == 'on_hold' or status == 'not_started' then return 'paused' end
  if status == 'taking_as_needed' then return 'as_needed' end
  if refill_status == 'no_fill' or days_supply_missing == true or days_supply_missing == 1 then
    return 'missing'
  end
  return refill_status
end

--- Whether to ask the prescriber for a new prescription.
-- A medication that is taken, regularly or as needed, with no refill left needs a new
-- prescription before its next fill. The reminder follows the days of the refill
-- reminders, so it appears when the next fill is due soon, due or overdue. Some
-- prescribers take such a request from the patient only, never from the pharmacy.
-- @param status string         The status of the tracked medication.
-- @param refills_left integer  The refills left.
-- @param refill_status string  The refill status from v_active_medication.
-- @return boolean
function refill.ask_for_more(status, refills_left, refill_status)
  if status ~= 'taking_regularly' and status ~= 'taking_as_needed' then return false end
  if refills_left ~= 0 then return false end
  return refill_status == 'overdue' or refill_status == 'due' or refill_status == 'due_soon'
end

--- Describe refill eligibility and remaining physical supply.
-- @param refill_status string  The status from v_active_medication.
-- @param days integer|nil  Days until eligibility; negative after that date.
-- @param runs_out integer|nil  Days until physical supply ends.
-- @return string  Plain text for badges; reads no data and writes nothing.
function refill.phrase(refill_status, days, runs_out)
  if refill_status == 'no_fill' or not days or not runs_out then return 'No fill recorded' end
  if refill_status == 'overdue' then
    if runs_out == -1 then return 'Overdue by 1 day' end
    return 'Overdue by ' .. -runs_out .. ' days'
  end
  if days < 0 then
    if runs_out == 0 then return 'Fill now. Runs out today' end
    if runs_out == 1 then return 'Fill now. Runs out in 1 day' end
    return 'Fill now. Runs out in ' .. runs_out .. ' days'
  end
  if days == 0 then return 'Due today' end
  if days == 1 then return 'Due tomorrow' end
  return 'Due in ' .. days .. ' days'
end

return refill
