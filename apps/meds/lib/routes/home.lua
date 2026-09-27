-- This file is part of Prescription Tracker
-- apps/meds/lib/routes/home.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The home page, the household name and the reminder settings. All three read
--          and write the one profile row.
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
local clock    = require 'clock'
local page     = require 'page'
local store    = require 'store'
local validate = require 'validate'

--- Configuration ---
local NAME_MAX      = 60    -- Matches the maxlength of the name field
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

-- The one household using this node. At most one row exists.
local function profile()
  return pv.query1([[
    SELECT id, display_name, due_within_days, due_soon_within_days,
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

pv.get('/', function()
  return pv.render('index', {
    section  = 'home',
    me       = profile(),
    greeting = clock.greeting(clock.hour()),
  })
end)

--- Household name ---

pv.get('/edit', function()
  return pv.render('edit', { section = 'setup', me = profile() })
end)

pv.post('/name', function(req)
  local name, problem = validate.text(req.form.display_name, 'a name', NAME_MAX, true)
  local me = profile() or {}
  if not name then
    me.display_name = req.form.display_name
    return pv.render('edit', { section = 'setup', me = me, err = problem })
  end

  -- Reusing the existing id makes this an amendment, not a second household.
  -- An amendment replaces the whole row, so the day counts travel with the new name.
  local saved, refusal = store.save('profile', me.id, {
    display_name                   = name,
    due_within_days                = me.due_within_days,
    due_soon_within_days           = me.due_soon_within_days,
    specialty_due_within_days      = me.specialty_due_within_days,
    specialty_due_soon_within_days = me.specialty_due_soon_within_days,
    authorization_notice_days      = me.authorization_notice_days,
  })
  if not saved then
    me.display_name = name
    return pv.render('edit', { section = 'setup', me = me, err = refusal })
  end

  return pv.redirect(url('/'))
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
  local me = profile()
  if not me then return pv.redirect(url('/edit?notice=unnamed')) end
  return reminders_page(me, {})
end)

pv.post('/setup/reminders', function(req)
  local me = profile()
  if not me then return pv.redirect(url('/edit?notice=unnamed')) end

  local row, errors = { display_name = me.display_name }, {}
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
    me      = profile(),
  })
end)
