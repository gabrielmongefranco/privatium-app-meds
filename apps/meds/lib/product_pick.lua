-- This file is part of Prescription Tracker
-- apps/meds/lib/product_pick.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-03
-- Last Modified: 2026-10-03
-- Summary: The products of a tracked medication while its form is being filled in: the ones
--          chosen so far travel in hidden fields, a search of the catalog lists products to
--          check, the checked ones are added per round trip, and nothing is written until
--          the form is saved.
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

local pv                = require 'privatium'
local medication_pick   = require 'medication_pick'
local medication_search = require 'medication_search'
local text              = require 'text'

local product_pick = {}

--- Configuration ---
product_pick.MAX         = 12          -- Products one tracked medication can hold in the form
product_pick.PREFIX      = 'product'   -- The box that finds or adds the next product
product_pick.QUERY       = 'product_q' -- The search box of the catalog
product_pick.ADD         = 'add_product'
product_pick.FIND        = 'find_product'
product_pick.RESULTS_MAX = 25          -- Products one search lists, best first
local REMOVE             = '^remove_product_(%d+)$'
-- A checked result of the search. The browser and the server name them alike.
local PICKED             = '^pick_(%w+)$'

--- Reads ---

-- Described for the screens: the names, and the hidden fields that carry the product
-- to the next round trip. A product of the catalog travels by its id; a new one
-- travels by its fields, so nothing is written until the form is saved.
local function described(form, prefix, pick)
  local product = { id = pick.id, new_row = pick.new_row, fields = {} }
  product.short_name, product.full_name = medication_pick.names(pick)
  if pick.id then
    product.fields.id = pick.id
  else
    for _, ending in ipairs(medication_pick.NEW_FIELDS) do
      product.fields[ending] = text.clean(form[prefix .. '_' .. ending])
    end
    -- The choices travel as the values that were settled, so the next round trip
    -- reads one plain value each.
    product.fields.package_type, product.fields.package_type_new = pick.new_row.package_type, nil
    product.fields.route, product.fields.route_new, product.fields.route_ref = pick.new_row.route, nil, nil
    product.fields.dose_form, product.fields.dose_form_new, product.fields.dose_form_ref = pick.new_row.form, nil, nil
  end
  return product
end

-- Two products are the same when they have one id, or one short name as new rows.
local function same(one, other)
  if one.id or other.id then return one.id == other.id end
  return text.key(one.short_name) == text.key(other.short_name)
end

-- The ids of the results that were checked, in a fixed order.
local function picked_ids(form)
  local ids = {}
  for key, value in pairs(form) do
    local id = type(key) == 'string' and key:match(PICKED)
    if id and text.clean(value) then ids[#ids + 1] = id end
  end
  table.sort(ids)
  return ids
end

--- Search the catalog for the products a typed name fits.
-- @param typed string  What was typed, already cleaned by medication_search.typed.
-- @return table  Up to 25 rows of { medication_id, short_name, full_name, close }, the
--         ones that hold the name first and the close ones after them. `close` is true
--         for a name that is near what was typed, which a person must confirm.
function product_pick.search(typed)
  local results = {}
  if typed == '' then return results end
  local found = medication_search.find(typed)
  for _, group in ipairs({ found.matches, found.close }) do
    for _, row in ipairs(group) do
      if #results >= product_pick.RESULTS_MAX then break end
      results[#results + 1] = {
        medication_id = row.medication_id,
        short_name    = row.short_name,
        full_name     = row.full_name,
        close         = group == found.close,
      }
    end
  end
  return results
end

--- The products that the hidden fields of a form carry.
-- @param form table  The values of the form.
-- @return table|nil, string|nil  The products, in order, or nil and a message when a
--         carried field names nothing or fails a check, as a changed form would.
function product_pick.read(form)
  local chosen = {}
  for index = 1, product_pick.MAX do
    local prefix = 'product_' .. index
    if text.clean(form[prefix .. '_id']) or medication_pick.filled_new(form, prefix) then
      local pick = medication_pick.read(form, prefix, true)
      if pick.problem then return nil, pick.problem end
      local product = described(form, prefix, pick)
      local repeated = false
      for _, other in ipairs(chosen) do
        if same(other, product) then repeated = true end
      end
      if not repeated then chosen[#chosen + 1] = product end
    end
  end
  return chosen
end

-- The products the box asks to add: every checked result, or, when none is checked,
-- the new medication typed into the fields.
local function asked_for(form)
  local picks = {}
  for _, id in ipairs(picked_ids(form)) do picks[#picks + 1] = medication_pick.by_id(id) end
  if #picks == 0 and medication_pick.touched_new(form, product_pick.PREFIX) then
    picks[1] = medication_pick.as_new(form, product_pick.PREFIX)
  end
  return picks
end

--- Apply what the form asked of the products: search, add, remove, or nothing.
-- A name typed into the search box with nothing checked counts as a search, whichever
-- button was pressed, so pressing Enter in the box searches and never saves. Checked
-- results are added together; the fields of a new medication are added when nothing
-- is checked.
-- @param form table  The values of the form.
-- @return table, table|nil, string|nil, boolean  The products after the request; what
--         the box answered, as { term, results, problem, open_new }, when it was read;
--         a message about the products; and whether the form acted on the products,
--         in which case it comes back to the person instead of saving.
function product_pick.handle(form)
  local chosen, problem = product_pick.read(form)
  if not chosen then return {}, nil, problem, false end

  local action = text.clean(form.action) or ''
  local removed = action:match(REMOVE)
  if removed then
    table.remove(chosen, math.tointeger(tonumber(removed)) or 0)
    return chosen, nil, nil, true
  end

  local term = medication_search.typed(form[product_pick.QUERY])
  local picks = asked_for(form)
  local asked = action == product_pick.ADD or action == product_pick.FIND
  if not asked and #picks == 0 and term == '' then return chosen, nil, nil, false end

  local pick = { term = term }
  if #picks == 0 then
    -- A search, or an Add with nothing to add.
    if term == '' then
      pick.problem = 'Check a product in the results, or type a name to search for.'
      return chosen, pick, nil, true
    end
    pick.results = product_pick.search(term)
    if #pick.results == 0 then
      pick.problem = 'No medication found with this name. Check the spelling, or add it to the catalog below.'
      pick.open_new = true
    end
    return chosen, pick, nil, true
  end

  for _, one in ipairs(picks) do
    if one.problem then
      pick.problem, pick.open_new = one.problem, one.open_new
      if term ~= '' then pick.results = product_pick.search(term) end
      return chosen, pick, nil, true
    end
  end
  local added = 0
  for _, one in ipairs(picks) do
    if #chosen >= product_pick.MAX then
      return chosen, nil, 'A medication can have ' .. product_pick.MAX .. ' products at most.', true
    end
    local product = described(form, product_pick.PREFIX, one)
    local repeated = false
    for _, other in ipairs(chosen) do
      if same(other, product) then repeated = true end
    end
    if not repeated then
      chosen[#chosen + 1] = product
      added = added + 1
    end
  end
  if added == 0 then
    return chosen, nil, 'This product is already on this medication.', true
  end
  return chosen, nil, nil, true
end

--- The values of a form with the box emptied, for the round trip after a product was
-- added. The hidden fields of the products stay.
-- @return table  A copy of the form.
function product_pick.cleared(form)
  local copy = {}
  for key, value in pairs(form) do
    if not (type(key) == 'string' and key:match(PICKED)) then copy[key] = value end
  end
  copy.action = nil
  copy[product_pick.QUERY] = nil
  for _, ending in ipairs(medication_pick.NEW_FIELDS) do
    copy[product_pick.PREFIX .. '_' .. ending] = nil
  end
  return copy
end

--- The form values that carry the products of a stored tracked medication.
-- @param products table  What entries.products returned.
-- @return table  { product_1_id = ..., product_2_id = ... }.
function product_pick.carried(products)
  local typed = {}
  for index, product in ipairs(products) do
    typed['product_' .. index .. '_id'] = product.medication_id
  end
  return typed
end

--- Write the products that are new to the catalog, inside a batch.
-- @param tx table      The batch.
-- @param chosen table  What product_pick.handle returned.
-- @return table  The medication ids, in the order of the products.
function product_pick.write(tx, chosen)
  local ids = {}
  for _, product in ipairs(chosen) do
    ids[#ids + 1] = medication_pick.write(tx, product)
  end
  return ids
end

--- How many fills of a tracked medication name a product.
-- A product with fills stays on the entry, or the fills would name nothing.
-- @return integer
function product_pick.fills_naming(person_medication_id, medication_id)
  return pv.query1([[
    SELECT count(*) AS fills FROM fill
     WHERE person_medication_id = ? AND medication_id = ?]], { person_medication_id, medication_id }).fills
end

return product_pick
