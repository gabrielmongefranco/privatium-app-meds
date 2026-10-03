-- This file is part of Prescription Tracker
-- apps/meds/lib/product_pick.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-03
-- Last Modified: 2026-10-03
-- Summary: The products of a tracked medication while its form is being filled in: the ones
--          chosen so far travel in hidden fields, one is added or removed per round trip, and
--          nothing is written until the form is saved.
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
local medication_pick = require 'medication_pick'
local text            = require 'text'

local product_pick = {}

--- Configuration ---
product_pick.MAX    = 12          -- Products one tracked medication can hold in the form
product_pick.PREFIX = 'product'   -- The box that finds or adds the next product
product_pick.ADD    = 'add_product'
local REMOVE        = '^remove_product_(%d+)$'

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
  end
  return product
end

-- Two products are the same when they have one id, or one short name as new rows.
local function same(one, other)
  if one.id or other.id then return one.id == other.id end
  return text.key(one.short_name) == text.key(other.short_name)
end

--- The products that the hidden fields of a form carry.
-- @param form table  The values of the form.
-- @return table|nil, string|nil  The products, in order, or nil and a message when a
--         carried field names nothing or fails a check, as a changed form would.
function product_pick.read(form)
  local chosen = {}
  for index = 1, product_pick.MAX do
    local prefix = 'product_' .. index
    if text.clean(form[prefix .. '_id']) or text.clean(form[prefix .. '_brand'])
       or text.clean(form[prefix .. '_generic']) then
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

--- Apply what the form asked of the products: add one, remove one, or nothing.
-- A name typed into the box counts as a request to add, whichever button was pressed,
-- so a product is never lost because the Enter key saved the form.
-- @param form table  The values of the form.
-- @return table, table|nil, string|nil, boolean  The products after the request; what
--         the box answered, when it was read; a message about the products; and
--         whether the form acted on the products, in which case it comes back to the
--         person instead of saving.
function product_pick.handle(form)
  local chosen, problem = product_pick.read(form)
  if not chosen then return {}, nil, problem, false end

  local action = text.clean(form.action) or ''
  local removed = action:match(REMOVE)
  if removed then
    table.remove(chosen, math.tointeger(tonumber(removed)) or 0)
    return chosen, nil, nil, true
  end

  if action ~= product_pick.ADD and not medication_pick.filled(form, product_pick.PREFIX) then
    return chosen, nil, nil, false
  end
  local pick = medication_pick.read(form, product_pick.PREFIX, true)
  if pick.problem then return chosen, pick, nil, true end
  if #chosen >= product_pick.MAX then
    return chosen, nil, 'A medication can hold ' .. product_pick.MAX .. ' products at most.', true
  end
  local product = described(form, product_pick.PREFIX, pick)
  for _, other in ipairs(chosen) do
    if same(other, product) then
      return chosen, nil, 'This product is on the entry already.', true
    end
  end
  chosen[#chosen + 1] = product
  return chosen, nil, nil, true
end

--- The values of a form with the box emptied, for the round trip after a product was
-- added. The hidden fields of the products stay.
-- @return table  A copy of the form.
function product_pick.cleared(form)
  local copy = {}
  for key, value in pairs(form) do copy[key] = value end
  copy.action = nil
  copy[product_pick.PREFIX .. '_name'], copy[product_pick.PREFIX .. '_choice'] = nil, nil
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
