-- This file is part of Medication Tracker
-- apps/meds/lib/entries.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Reads what people track: each tracked medication with its products, its refill
--          dates, its refill status in words, its group on the Refills page, and the text
--          the search of the Medications page looks through.
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

local pv        = require 'privatium'
local choices   = require 'choices'
local form_icon = require 'form_icon'
local refill    = require 'refill'
local text      = require 'text'
local validate  = require 'validate'
local when_icon = require 'when_icon'

local entries = {}

local GROUP_BY_KEY = {}
for _, group in ipairs(refill.GROUPS) do GROUP_BY_KEY[group.key] = group end

-- A mark of v_entry_mark arrives as 1 or 0. Lua treats 0 as true, so it becomes a boolean.
local function marked(value)
  return value == 1 or value == true
end

-- Adds to a row what the screens show beside the stored values.
local function dressed(row)
  row.is_specialty  = marked(row.is_specialty)
  row.is_controlled = marked(row.is_controlled)
  row.status_label = choices.status_label(row.status)
  row.group        = refill.group(row.status, row.refill_status, row.days_supply_missing)
  row.phrase       = refill.phrase(row.refill_status, row.days_until_next_fill, row.days_until_runs_out)
  local group      = GROUP_BY_KEY[row.group]
  -- A medication that raises no alert shows its status in a quiet badge.
  local shown      = group and group.alert and group or GROUP_BY_KEY[row.group or 'paused']
  row.badge, row.icon_name = shown.badge, shown.icon
  row.prescriber_href = validate.tel_href(row.prescriber_phone)
  row.pharmacy_href   = validate.tel_href(row.pharmacy_phone)
  return row
end

--- Reads ---

-- The products of the tracked medications of one person, or of everyone.
-- Grain: one row per tracked medication per product, in the order of the products.
local function products_of(person_id)
  return pv.query([[
    SELECT tp.person_medication_id, tp.link_id, tp.medication_id, tp.short_name, tp.full_name,
           tp.route, tp.form, tp.package_type, tp.is_specialty, tp.is_controlled, tp.position
      FROM v_tracked_product tp
     WHERE ?1 = '' OR tp.person_id = ?1
     ORDER BY tp.person_medication_id, tp.position]], { person_id })
end

-- Every name the products of those tracked medications answer to: short names, brand
-- and generic names and other names. Grain: one row per tracked medication per name.
local function names_of(person_id)
  return pv.query([[
    SELECT tp.person_medication_id, n.name
      FROM v_tracked_product tp
      JOIN v_medication_name n ON n.medication_id = tp.medication_id   -- 1:many
     WHERE ?1 = '' OR tp.person_id = ?1]], { person_id })
end

-- Attaches the products, the icons of the first product and of the time of day, and
-- the search text to rows.
local function with_products(rows, person_id)
  local by_id = {}
  for _, row in ipairs(rows) do
    row.products, row.names = {}, {}
    by_id[row.id] = row
  end
  for _, product in ipairs(products_of(person_id)) do
    local row = by_id[product.person_medication_id]
    if row then row.products[#row.products + 1] = product end
  end
  for _, name in ipairs(names_of(person_id)) do
    local row = by_id[name.person_medication_id]
    if row then row.names[#row.names + 1] = name.name end
  end
  for _, row in ipairs(rows) do
    local first = row.products[1] or {}
    row.product_name = first.short_name
    row.form_icon, row.form_label = form_icon.of(first.form, first.route, first.package_type)
    row.when_icons = when_icon.of(row.when_to_take)
    -- The search looks through the preferred name, the person, the prescriber, and
    -- every name of every product. Spaces around the key let a word match whole.
    local parts = { row.medication_name or '', row.person_name or '' }
    if row.prescriber_name then parts[#parts + 1] = row.prescriber_name end
    for _, product in ipairs(row.products) do parts[#parts + 1] = product.full_name end
    for _, name in ipairs(row.names) do parts[#parts + 1] = name end
    row.search_key = ' ' .. text.key(table.concat(parts, ' ')) .. ' '
  end
  return rows
end

--- The tracked medications.
-- @param person_id string  The id of one person, or '' for everyone.
-- @return table  Grain: one row per person_medication row, ordered by person and then
--         by preferred name. Each row carries `products`, the icon of its first
--         product as `form_icon` and `form_label`, the icons of its time of day as
--         `when_icons`, and `search_key`.
function entries.list(person_id)
  local rows = pv.query([[
    SELECT pm.id, pm.person_id, pm.display_name AS medication_name, pm.medication_type,
           pm.status, pm.prescribed_for, pm.instructions, pm.when_to_take, pm.notes, pm.refills_left,
           pm.pharmacy_id, pm.prescriber_id,
           p.display_name  AS person_name,
           coalesce(e.is_specialty, 0)  AS is_specialty,
           coalesce(e.is_controlled, 0) AS is_controlled,
           pr.name         AS prescriber_name,
           pr.phone        AS prescriber_phone,
           ph.name         AS pharmacy_name,
           ph.phone        AS pharmacy_phone,
           lph.name        AS last_fill_pharmacy_name,
           s.last_fill_id, s.last_filled_on, s.last_days_supply, s.last_medication_id,
           s.days_supply_missing, s.next_fill_on, s.lasts_until, s.allowance, a.plan_name,
           coalesce(a.refill_status, CASE WHEN s.next_fill_on IS NULL THEN 'no_fill' ELSE 'not_due' END) AS refill_status,
           CAST(julianday(s.next_fill_on) - julianday(date('now', 'localtime')) AS INTEGER) AS days_until_next_fill,
           CAST(julianday(s.lasts_until) - julianday(date('now', 'localtime')) AS INTEGER) AS days_until_runs_out
      FROM person_medication pm
      JOIN person p     ON p.id = pm.person_id                       -- many:1
      JOIN v_supply s   ON s.person_medication_id = pm.id            -- 1:1
      LEFT JOIN v_entry_mark e ON e.person_medication_id = pm.id     -- 1:0..1; absent with no product
      LEFT JOIN v_active_medication a ON a.person_medication_id = pm.id   -- 1:0..1; absent when no longer taken
      LEFT JOIN prescriber pr ON pr.id = pm.prescriber_id            -- many:0..1
      LEFT JOIN pharmacy ph   ON ph.id = pm.pharmacy_id              -- many:0..1
      LEFT JOIN pharmacy lph  ON lph.id = s.last_pharmacy_id         -- many:0..1
     WHERE ?1 = '' OR pm.person_id = ?1
     ORDER BY p.display_name COLLATE NOCASE, pm.display_name COLLATE NOCASE, pm.id]], { person_id })
  for _, row in ipairs(rows) do dressed(row) end
  return with_products(rows, person_id)
end

--- The rows whose search text holds every word that was typed.
-- @param rows table    What entries.list returned.
-- @param typed string|nil  What was typed into the search box.
-- @return table  The rows that match, in the same order; every row when nothing was typed.
function entries.filter(rows, typed)
  local words = {}
  for word in text.key(typed):gmatch('%S+') do words[#words + 1] = word end
  if #words == 0 then return rows end
  local kept = {}
  for _, row in ipairs(rows) do
    local all = true
    for _, word in ipairs(words) do
      if not row.search_key:find(word, 1, true) then all = false break end
    end
    if all then kept[#kept + 1] = row end
  end
  return kept
end

--- One tracked medication.
-- @param id string
-- @return table|nil  The row as entries.list returns it, or nil when there is none.
function entries.one(id)
  local stored = pv.get_row('person_medication', id)
  if not stored then return nil end
  for _, row in ipairs(entries.list(stored.person_id)) do
    if row.id == id then return row end
  end
  return nil
end

--- The products of one tracked medication.
-- @param id string
-- @return table  Grain: one row per product, in the order of the products.
function entries.products(id)
  return pv.query([[
    SELECT link_id, medication_id, short_name, full_name, route, form, package_type,
           is_specialty, is_controlled, position
      FROM v_tracked_product
     WHERE person_medication_id = ?
     ORDER BY position]], { id })
end

--- The tracked medication of a person that holds a product.
-- One product belongs to one tracked medication of a person, so its fills count once.
-- @return table|nil  { id, display_name }, or nil when no tracked medication holds it.
function entries.with_product(person_id, medication_id)
  if not person_id or not medication_id then return nil end
  return pv.query1([[
    SELECT tp.person_medication_id AS id, pm.display_name
      FROM v_tracked_product tp
      JOIN person_medication pm ON pm.id = tp.person_medication_id   -- many:1
     WHERE tp.person_id = ? AND tp.medication_id = ?
     ORDER BY pm.id
     LIMIT 1]], { person_id, medication_id })
end

--- The tracked medication of a person with a preferred name.
-- Two names are the same when they differ only by case, punctuation or spacing. Two
-- people may use the same name.
-- @param except_id string|nil  A tracked medication to leave out, the one being changed.
-- @return table|nil  { id, display_name }, or nil.
function entries.named(person_id, name, except_id)
  if not person_id or not name then return nil end
  local key = text.key(name)
  for _, row in ipairs(pv.query([[
      SELECT id, display_name FROM person_medication WHERE person_id = ? ORDER BY id]], { person_id })) do
    if row.id ~= except_id and text.key(row.display_name) == key then return row end
  end
  return nil
end

--- Every column of one person_medication row, as a save needs it.
-- @return table|nil
function entries.stored(id)
  return pv.query1([[
    SELECT id, person_id, display_name, medication_type, status, pharmacy_id,
           prescriber_id, prescribed_for, instructions, when_to_take, notes, refills_left
      FROM person_medication
     WHERE id = ?]], { id })
end

--- Add a tracked medication with one product inside a batch.
-- Used when a fill, a prior authorization or a pasted fill names a product that is on
-- no list of the person. The preferred name is the product's full name.
-- @param tx table      The batch.
-- @param fields table  { person_id, medication_id, display_name, status, pharmacy_id,
--        refills_left }. The product may be one added earlier in the same batch, which
--        is why its name comes from the caller.
-- @return string  The id of the tracked medication.
function entries.add(tx, fields)
  local id = tx.append('person_medication', {
    person_id    = fields.person_id,
    display_name = fields.display_name,
    status       = fields.status,
    pharmacy_id  = fields.pharmacy_id,
    refills_left = fields.refills_left or 0,
  })
  tx.append('person_medication_product', { person_medication_id = id, medication_id = fields.medication_id })
  return id
end

return entries
