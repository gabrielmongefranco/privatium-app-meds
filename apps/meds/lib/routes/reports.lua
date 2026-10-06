-- This file is part of Medication Tracker
-- apps/meds/lib/routes/reports.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: The Reports tab of the History section, with the chart and table of what was
--          paid each year, and the printable spending report, all under the history filters.
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

local pv              = require 'privatium'
local clock           = require 'clock'
local history_filter  = require 'history_filter'
local money           = require 'money'
local page            = require 'page'
local periods         = require 'periods'
local spending_chart  = require 'spending_chart'
local text            = require 'text'

--- Configuration ---
local REPORTS = '/fills/reports'
local PRINT   = REPORTS .. '/print'

--- Totals ---

local function by_name(a, b) return a:lower() < b:lower() end

local function total_of(found)
  local total = history_filter.total(found)
  total.counted = page.counted(total.fills, 'fill', 'fills')
  return total
end

-- Grain: one row per calendar year with a fill, oldest first.
local function by_year(found)
  local years = history_filter.group(found, function(row) return row.filled_on:sub(1, 4) end)
  table.sort(years, function(a, b) return a.key < b.key end)
  for _, row in ipairs(years) do row.year = row.key end
  return years
end

-- Grain: one row per person per calendar year with a fill, newest year first.
local function by_person_and_year(found)
  local rows = history_filter.group(found, function(row) return row.filled_on:sub(1, 4) .. ' ' .. row.person_id end)
  for _, row in ipairs(rows) do row.year, row.person_name = row.first.filled_on:sub(1, 4), row.first.person_name end
  table.sort(rows, function(a, b)
    if a.year ~= b.year then return a.year > b.year end
    if a.person_name ~= b.person_name then return by_name(a.person_name, b.person_name) end
    return a.key < b.key
  end)
  return rows
end

-- Words for the filters other than the person, for the heading of the report.
local function narrowed_by(chosen)
  local words = {}
  local function label_of(options, value)
    for _, option in ipairs(options) do
      if option.value == value then return option.label end
    end
  end
  if chosen.medication ~= '' then words[#words + 1] = 'Medication: ' .. label_of(chosen.medications, chosen.medication) end
  if chosen.pharmacy ~= '' then words[#words + 1] = 'Pharmacy: ' .. label_of(chosen.pharmacies, chosen.pharmacy) end
  if chosen.q ~= '' then words[#words + 1] = 'Search: ' .. chosen.q end
  return words
end

--- Routes ---

pv.get(REPORTS, function(req)
  local chosen = history_filter.read(req)
  local found = history_filter.fills(chosen)
  return pv.render('reports', {
    section     = 'history',
    filter      = chosen.people,
    chosen      = chosen,
    keep        = history_filter.query(chosen, { person = false, page = 1 }),
    is_narrowed = history_filter.is_narrowed(chosen),
    tabs        = history_filter.tabs(chosen, 'reports'),
    total       = total_of(found),
    chart       = spending_chart.layout(by_year(found), clock.today():sub(1, 4), money.format),
    spending    = by_person_and_year(found),
    printable   = url(history_filter.link(PRINT, chosen, { page = 1 })),
  })
end)

pv.get(PRINT, function(req)
  local chosen = history_filter.read(req)
  local found = history_filter.fills(chosen)

  -- Grain: one row per tracked medication with a fill, by person and then by name.
  local medications = history_filter.group(found, function(row) return row.person_medication_id end)
  for _, row in ipairs(medications) do
    row.person_name, row.medication_name = row.first.person_name, row.first.medication_name
  end
  table.sort(medications, function(a, b)
    if a.person_name ~= b.person_name then return by_name(a.person_name, b.person_name) end
    if a.medication_name ~= b.medication_name then return by_name(a.medication_name, b.medication_name) end
    return a.key < b.key
  end)

  -- Grain: one row per person with a fill. Each person's fills run oldest first, the
  -- order of a pile of pharmacy receipts.
  local people = history_filter.group(found, function(row) return row.person_id end)
  for _, person in ipairs(people) do
    person.person_name = person.first.person_name
    person.counted = page.counted(person.fills, 'fill', 'fills')
    local oldest_first = {}
    for index = #person.rows, 1, -1 do
      local fill = person.rows[index]
      fill.quantity = text.plain_number(fill.quantity)
      oldest_first[#oldest_first + 1] = fill
    end
    person.fills_list = oldest_first
  end
  table.sort(people, function(a, b)
    if a.person_name ~= b.person_name then return by_name(a.person_name, b.person_name) end
    return a.key < b.key
  end)

  return pv.render('report_print', {
    section     = 'history',
    chosen      = chosen,
    covers      = chosen.people.selected and chosen.people.selected.display_name or 'Everyone in the household',
    period      = chosen.period == '' and 'Every fill recorded'
                  or (periods.label(chosen.period) .. ', ' .. fmt.date(chosen.from) .. ' to ' .. fmt.date(chosen.to)),
    narrowed_by = narrowed_by(chosen),
    today       = clock.today(),
    total       = total_of(found),
    spending    = by_person_and_year(found),
    medications = medications,
    people      = people,
    back        = url(history_filter.link(REPORTS, chosen, { page = 1 })),
  })
end)
