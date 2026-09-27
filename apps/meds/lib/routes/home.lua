-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/home.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The home page, which is the Refills page once the household has people, and
--          the household name and the reminder settings, which share the one profile row.
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

local pv       = require 'privatium'
local authorization_watch = require 'authorization_watch'
local clock    = require 'clock'
local entries  = require 'entries'
local people_filter = require 'people_filter'
local refill   = require 'refill'
local page     = require 'page'
local store    = require 'store'
local validate = require 'validate'

--- Configuration ---
local DAY_COUNT_MAX = 365   -- A reminder more than a year ahead is a typing mistake

-- The day counts, in the order the form shows them. `label` completes the sentence
-- 'Write ... as a whole number'.
local DAY_COUNTS = {
  { name = 'due_within_days',                label = 'the days for due' },
  { name = 'due_soon_within_days',           label = 'the days for due soon' },
  { name = 'specialty_due_within_days',      label = 'the days for due, specialty' },
  { name = 'specialty_due_soon_within_days', label = 'the days for due soon, specialty' },
  { name = 'authorization_notice_days',      label = 'the days of notice' },
}

-- The reminder settings of this node. At most one row exists, and none until the
-- settings are saved for the first time.
local function profile()
  return pv.query1([[
    SELECT id, due_within_days, due_soon_within_days,
           specialty_due_within_days, specialty_due_soon_within_days,
           authorization_notice_days
      FROM profile
     LIMIT 1]])
end

-- The day counts that an empty field stands for. Always one row.
local function defaults()
  return pv.query1([[
    SELECT due_within_days, due_soon_within_days, specialty_due_within_days,
           specialty_due_soon_within_days, authorization_notice_days
      FROM v_reminder_default]])
end

--- Home ---

-- The sentence that confirms a fill, read from the fill itself. The page address
-- carries the id of the fill and nothing else.
local function fill_notice(fill_id)
  if type(fill_id) ~= 'string' then return nil end
  local saved = pv.query1([[
    SELECT m.short_name AS medication_name, s.next_fill_on
      FROM fill f
      JOIN medication m ON m.id = f.medication_id          -- many:1
      JOIN person_medication pm                            -- many:1; the list entry of the pair
        ON pm.person_id = f.person_id AND pm.medication_id = f.medication_id
      JOIN v_supply s ON s.person_medication_id = pm.id    -- 1:1
     WHERE f.id = ?
     LIMIT 1]], { fill_id })
  if not saved then return nil end
  return 'Saved the fill for ' .. saved.medication_name .. '. The next fill date is '
    .. tostring(fmt.date(saved.next_fill_on)) .. '.'
end

pv.get('/', function(req)
  local filter = people_filter.read(req)
  if #filter.people == 0 then
    return pv.render('index', { section = 'home', greeting = clock.greeting(clock.hour()) })
  end

  local groups, by_key = {}, {}
  for _, group in ipairs(refill.GROUPS) do
    local copy = { key = group.key, title = group.title, alert = group.alert,
                   icon = group.icon, rows = {} }
    groups[#groups + 1], by_key[group.key] = copy, copy
  end
  local next_row
  for _, row in ipairs(entries.list(filter.id)) do
    local group = by_key[row.group]
    if group then group.rows[#group.rows + 1] = row end
    if row.group == 'not_due' and (not next_row or row.next_fill_on < next_row.next_fill_on) then
      next_row = row
    end
  end
  -- Within a group, the medication that needs a fill soonest comes first.
  for _, group in ipairs(groups) do
    table.sort(group.rows, function(a, b)
      local left, right = a.next_fill_on or '9999', b.next_fill_on or '9999'
      if left ~= right then return left < right end
      return a.id < b.id
    end)
  end

  local ending = authorization_watch.ending(filter.id)
  return pv.render('refills', {
    section  = 'home',
    greeting = clock.greeting(clock.hour()),
    notice   = fill_notice(req.query.filled) or page.notice(req.query.notice),
    filter   = filter,
    groups   = groups,
    ending   = ending,
    alerts   = #by_key.overdue.rows + #by_key.due.rows + #by_key.due_soon.rows + #ending,
    next_row = next_row,
  })
end)

--- Reminder settings ---

local function reminders_page(typed, errors)
  return pv.render('reminders', {
    section  = 'setup',
    typed    = typed,
    errors   = errors,
    problems = page.problems(errors, {
      'due_within_days', 'due_soon_within_days', 'specialty_due_within_days',
      'specialty_due_soon_within_days', 'authorization_notice_days',
    }),
    defaults = defaults(),
  })
end

pv.get('/setup/reminders', function()
  return reminders_page(profile() or {}, {})
end)

pv.post('/setup/reminders', function(req)
  local me = profile() or {}
  local row, errors = {}, {}
  for _, count in ipairs(DAY_COUNTS) do
    row[count.name], errors[count.name] =
      validate.whole_number(req.form[count.name], count.label, 0, DAY_COUNT_MAX)
  end

  -- "Due soon" has to reach at least as far ahead as "due", or the two would overlap.
  -- An empty count stands for its default, so the comparison fills the defaults in.
  local default = defaults()
  local function effective(name) return row[name] or default[name] end
  if not errors.due_soon_within_days
     and effective('due_soon_within_days') < effective('due_within_days') then
    errors.due_soon_within_days = 'Make the days for due soon the same as the days for due, or more.'
  end
  if not errors.specialty_due_soon_within_days
     and effective('specialty_due_soon_within_days') < effective('specialty_due_within_days') then
    errors.specialty_due_soon_within_days =
      'Make the days for due soon the same as the days for due, or more.'
  end

  if next(errors) then return reminders_page(req.form, errors) end

  -- Reusing the id of the stored row makes this an amendment, so the node never holds
  -- a second row of settings.
  local saved, refusal = store.save('profile', me.id, row)
  if not saved then
    errors.due_within_days = refusal
    return reminders_page(req.form, errors)
  end
  return pv.redirect(url('/setup?notice=saved'))
end)

--- Setup ---

pv.get('/setup', function(req)
  local counts = pv.query1([[
    SELECT (SELECT count(*) FROM person)     AS people,
           (SELECT count(*) FROM medication) AS medications]])
  return pv.render('setup', {
    section = 'setup',
    notice  = page.notice(req.query.notice),
    counts  = counts,
  })
end)
