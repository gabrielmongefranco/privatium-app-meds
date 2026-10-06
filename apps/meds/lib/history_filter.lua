-- This file is part of Medication Tracker
-- apps/meds/lib/history_filter.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: The filters that the fill history, the reports and the printable report share:
--          reading them from the page address, the fills under them with their totals, and
--          the links that keep them.
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

local pv                 = require 'privatium'
local clock              = require 'clock'
local medication_search  = require 'medication_search'
local people_filter      = require 'people_filter'
local periods            = require 'periods'
local quick_add          = require 'quick_add'
local text               = require 'text'

local history_filter = {}

--- Configuration ---
local WORDS_MAX = 8   -- Search words that count; a longer search is a pasted paragraph

--- Choices ---

--- The tracked medications with a fill, for the Medication drop-down.
-- @param person_id string  The chosen person, or '' for everyone.
-- @return table  { value, label } rows. A label names the person only when the list
--         holds everyone's medications.
function history_filter.medication_options(person_id)
  -- Grain: one row per tracked medication with at least one fill.
  local rows = pv.query([[
    SELECT pm.id, pm.display_name, p.display_name AS person_name
      FROM person_medication pm
      JOIN person p ON p.id = pm.person_id   -- many:1
     WHERE (?1 = '' OR pm.person_id = ?1)
       AND EXISTS (SELECT 1 FROM fill f WHERE f.person_medication_id = pm.id)
     ORDER BY p.display_name COLLATE NOCASE, pm.display_name COLLATE NOCASE, pm.id]], { person_id })
  local options = {}
  for _, row in ipairs(rows) do
    local label = person_id == '' and (row.person_name .. ': ' .. row.display_name) or row.display_name
    options[#options + 1] = { value = row.id, label = label }
  end
  return options
end

-- The years with a fill, newest first.
local function years()
  local list = {}
  for _, row in ipairs(pv.query("SELECT DISTINCT strftime('%Y', filled_on) AS year FROM fill ORDER BY 1 DESC")) do
    list[#list + 1] = row.year
  end
  return list
end

local function offered(options, value)
  for _, option in ipairs(options) do
    if option.value == value then return value end
  end
  return ''
end

--- Reading ---

--- Read the filters from the page address.
-- A value that names nothing on offer counts as no filter, so a medication of another
-- person goes back to "Every medication" when the person changes.
-- @param req table  The request. Its query may hold person, medication, pharmacy, period
--        (or year, the older name of a year period), q and page.
-- @return table  { people = the person filter, person, medication, pharmacy, period, q,
--         words, from, to, page, medications, pharmacies, periods } where every value is
--         text, '' meaning no filter, and the last three are the drop-down choices.
function history_filter.read(req)
  local query = req.query
  local people = people_filter.read(req)
  local chosen = { people = people, person = people.id }
  chosen.medications = history_filter.medication_options(people.id)
  chosen.medication = offered(chosen.medications, text.clean(query.medication))
  chosen.pharmacies = quick_add.options(quick_add.PHARMACY)
  chosen.pharmacy = offered(chosen.pharmacies, text.clean(query.pharmacy))
  chosen.periods = periods.options(years())

  local period = text.clean(query.period) or text.clean(query.year) or ''
  chosen.from, chosen.to = periods.range(period, clock.today())
  if not chosen.from then period, chosen.from, chosen.to = '', '', '' end
  chosen.period = period

  chosen.q = medication_search.typed(query.q)
  chosen.words = {}
  for word in text.key(chosen.q):gmatch('%S+') do
    if #chosen.words < WORDS_MAX then chosen.words[#chosen.words + 1] = word end
  end

  local page_number = math.tointeger(tonumber(query.page) or 1) or 1
  chosen.page = math.max(page_number, 1)
  return chosen
end

--- Fills ---

--- Every fill under the filters, newest first.
-- The search words are matched here rather than in SQL, so the server and the search box
-- of the page match the same text in the same way.
-- @param chosen table  What history_filter.read returned.
-- @return table  One row per fill, with its person, tracked medication, product,
--         pharmacy and prescriber names, and `search_key`, the words a search looks in.
function history_filter.fills(chosen)
  -- Grain: one row per fill under the filters. Every join is many:1 or many:0..1.
  local rows = pv.query([[
    SELECT f.id, f.filled_on, f.quantity, f.days_supply, f.amount_paid, f.rx_number, f.notes,
           f.insurance_claim_number, f.person_medication_id, pm.person_id,
           p.display_name  AS person_name,
           pm.display_name AS medication_name,
           m.short_name    AS product_name,
           m.route, m.form, m.package_type,
           ph.name         AS pharmacy_name,
           pr.name         AS prescriber_name
      FROM fill f
      JOIN person_medication pm ON pm.id = f.person_medication_id   -- many:1
      JOIN person p             ON p.id = pm.person_id              -- many:1
      LEFT JOIN medication m    ON m.id = f.medication_id           -- many:0..1
      LEFT JOIN pharmacy ph     ON ph.id = f.pharmacy_id            -- many:0..1
      LEFT JOIN prescriber pr   ON pr.id = pm.prescriber_id         -- many:0..1
     WHERE (?1 = '' OR pm.person_id = ?1)
       AND (?2 = '' OR f.person_medication_id = ?2)
       AND (?3 = '' OR f.pharmacy_id = ?3)
       AND (?4 = '' OR f.filled_on >= ?4)
       AND (?5 = '' OR f.filled_on <= ?5)
     ORDER BY f.filled_on DESC, f.id DESC]],
    { chosen.person, chosen.medication, chosen.pharmacy, chosen.from, chosen.to })

  local found = {}
  for _, row in ipairs(rows) do
    -- Every name and number a person might remember a fill by.
    row.search_key = text.key(table.concat({ row.medication_name, row.product_name or '',
      row.person_name, row.pharmacy_name or '', row.rx_number and ('rx ' .. row.rx_number) or '',
      row.insurance_claim_number or '', row.notes or '' }, ' '))
    local matches = true
    for _, word in ipairs(chosen.words) do
      if not row.search_key:find(word, 1, true) then matches = false; break end
    end
    if matches then found[#found + 1] = row end
  end
  return found
end

--- Add up fills in groups.
-- @param rows table  Fills from history_filter.fills.
-- @param key_of function  Gives the group of a fill, such as its year or its person.
-- @return table  One group per key, in the order the keys first appear: { key, first =
--         the first fill of the group, fills = count, amount_paid = exact decimal text,
--         or nil when no fill of the group gave an amount, rows = its fills }.
function history_filter.group(rows, key_of)
  local groups, by_key = {}, {}
  for _, row in ipairs(rows) do
    local key = key_of(row)
    local group = by_key[key]
    if not group then
      group = { key = key, first = row, fills = 0, rows = {} }
      by_key[key] = group
      groups[#groups + 1] = group
    end
    group.fills = group.fills + 1
    group.rows[#group.rows + 1] = row
    if row.amount_paid then
      -- pv.dec keeps money exact; a Lua number would not.
      group.sum = (group.sum or pv.dec('0')) + pv.dec(row.amount_paid)
    end
  end
  for _, group in ipairs(groups) do
    group.amount_paid = group.sum and tostring(group.sum)
    group.sum = nil
  end
  return groups
end

--- The number of fills and the total paid of a list of fills.
-- @return table  { fills, amount_paid } as history_filter.group gives them.
function history_filter.total(rows)
  local all = history_filter.group(rows, function() return 'all' end)[1]
  return all or { fills = 0 }
end

--- True when anything narrows the fills.
function history_filter.is_narrowed(chosen)
  return chosen.medication ~= '' or chosen.pharmacy ~= '' or chosen.period ~= '' or chosen.q ~= ''
end

--- Links ---

--- The query string that keeps the filters, for links between pages.
-- @param chosen table  What history_filter.read returned.
-- @param changes table|nil  Values to use instead, such as { page = 2 } or
--        { person = false } to leave the person out.
-- @return string  Such as 'person=01J...&period=last-month', without a leading '?';
--         empty values are left out.
function history_filter.query(chosen, changes)
  changes = changes or {}
  local parts = {}
  for _, name in ipairs({ 'person', 'medication', 'pharmacy', 'period', 'q', 'page' }) do
    local value = chosen[name]
    if changes[name] ~= nil then value = changes[name] end
    if name == 'page' and value == 1 then value = nil end
    if value and value ~= '' then parts[#parts + 1] = name .. '=' .. text.url_encode(value) end
  end
  return table.concat(parts, '&')
end

--- A page address under the filters.
-- @param path string  The path of the page, such as '/fills/reports'.
function history_filter.link(path, chosen, changes)
  local query = history_filter.query(chosen, changes)
  return path .. (query ~= '' and ('?' .. query) or '')
end

--- The tabs of the History section, each keeping the filters.
-- @param chosen table  What history_filter.read returned.
-- @param current string  'fills' or 'reports', the tab on show.
-- @return table  { label, href, is_current } rows, in the order they are shown.
function history_filter.tabs(chosen, current)
  return {
    { label = 'Fill history', is_current = current == 'fills',
      href = url(history_filter.link('/fills', chosen, { page = 1 })) },
    { label = 'Reports', is_current = current == 'reports',
      href = url(history_filter.link('/fills/reports', chosen, { page = 1 })) },
  }
end

return history_filter
