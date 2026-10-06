-- This file is part of Medication Tracker
-- apps/meds/lib/routes/plans.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-01
-- Last Modified: 2026-10-01
-- Summary: Insurance plan settings and reference-safe removal.
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
local page = require 'page'
local quick_add = require 'quick_add'
local store = require 'store'
local text = require 'text'
local validate = require 'validate'

local LIST = '/setup/plans'
local FIELDS = { 'name', 'early_fill_percent', 'supply_frame_days' }

-- Grain: one row per plan; no member identifiers are stored here.
local function plans()
  return pv.query('SELECT id, name, early_fill_percent, supply_frame_days FROM plan ORDER BY name COLLATE NOCASE, id')
end

local function uses(id)
  -- Grain: one row of reference counts; each reference belongs to one plan.
  local counts = pv.query1([[
    SELECT (SELECT count(*) FROM person WHERE plan_id = ?1) AS people,
           (SELECT count(*) FROM fill WHERE plan_id = ?1) AS fills]], { id })
  local used = {}
  if counts.people > 0 then used[#used + 1] = page.counted(counts.people, 'person', 'people') end
  if counts.fills > 0 then used[#used + 1] = page.counted(counts.fills, 'fill', 'fills') end
  return used
end

local function read(form, except_id)
  local row, errors = {}, {}
  row.name, errors.name = validate.text(form.name, 'the plan name', quick_add.PLAN.max, true)
  row.early_fill_percent, errors.early_fill_percent =
    validate.whole_number(form.early_fill_percent, 'the early fill percent', 0, 100)
  row.supply_frame_days, errors.supply_frame_days =
    validate.whole_number(form.supply_frame_days, 'the supply frame days', 0, 3650)
  if row.name then
    for _, other in ipairs(plans()) do
      if other.id ~= except_id and text.key(other.name) == text.key(row.name) then
        errors.name = 'Choose another name. A plan with this name is already in the app.'
      end
    end
  end
  return row, errors
end

local function form_page(heading, action, typed, errors)
  return pv.render('plan_form', {
    section = 'setup', heading = heading, action = action, typed = typed,
    errors = errors, problems = page.problems(errors, FIELDS),
  })
end

pv.get(LIST, function(req)
  return pv.render('plans', { section = 'setup', plans = plans(), notice = page.notice(req.query.notice) })
end)

pv.get(LIST .. '/new', function()
  return form_page('Add an insurance plan', url(LIST .. '/new'), {}, {})
end)

pv.post(LIST .. '/new', function(req)
  local row, errors = read(req.form)
  if not next(errors) then
    local saved, refusal = store.save('plan', nil, row)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.name = refusal
  end
  return form_page('Add an insurance plan', url(LIST .. '/new'), req.form, errors)
end)

pv.get(LIST .. '/:id/edit', function(req)
  local plan = pv.get_row('plan', req.params.id)
  if not plan then return pv.redirect(url(LIST .. '?notice=missing')) end
  return form_page('Change an insurance plan', url(LIST .. '/' .. plan.id .. '/edit'), plan, {})
end)

pv.post(LIST .. '/:id/edit', function(req)
  local plan = pv.get_row('plan', req.params.id)
  if not plan then return pv.redirect(url(LIST .. '?notice=missing')) end
  local row, errors = read(req.form, plan.id)
  if not next(errors) then
    local saved, refusal = store.save('plan', plan.id, row)
    if saved then return pv.redirect(url(LIST .. '?notice=saved')) end
    errors.name = refusal
  end
  return form_page('Change an insurance plan', url(LIST .. '/' .. plan.id .. '/edit'), req.form, errors)
end)

pv.get(LIST .. '/:id/remove', function(req)
  local plan = pv.get_row('plan', req.params.id)
  if not plan then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'setup', heading = 'Remove an insurance plan', name = plan.name,
    used_by = uses(plan.id), action = url(LIST .. '/' .. plan.id .. '/remove'), back = url(LIST),
  })
end)

pv.post(LIST .. '/:id/remove', function(req)
  local plan = pv.get_row('plan', req.params.id)
  if not plan then return pv.redirect(url(LIST .. '?notice=missing')) end
  -- Referenced plans must remain available to explain historical refill dates.
  if #uses(plan.id) > 0 then return pv.redirect(url(LIST .. '/' .. plan.id .. '/remove')) end
  pv.delete('plan', plan.id)
  return pv.redirect(url(LIST .. '?notice=removed'))
end)
