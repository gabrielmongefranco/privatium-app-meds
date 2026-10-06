-- This file is part of Medication Tracker
-- apps/meds/lib/quick_add.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-01
-- Summary: A person, a pharmacy or a prescriber that a form adds by name, beside its own
--          record, so nobody leaves a form to add one.
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
local text     = require 'text'
local validate = require 'validate'

local quick_add = {}

--- Configuration ---
quick_add.NEW = 'new'   -- The choice of a drop-down that adds a record

-- The records a form can add by name alone, beside its own record. `column` holds the
-- name. `noun` completes the sentence 'Choose a ...'.
quick_add.PERSON     = { tbl = 'person',     column = 'display_name', noun = 'person',     max = 120 }
quick_add.PHARMACY   = { tbl = 'pharmacy',   column = 'name',         noun = 'pharmacy',   max = 120 }
quick_add.PLAN       = { tbl = 'plan', column = 'name', noun = 'plan', max = 120 }
quick_add.PRESCRIBER = { tbl = 'prescriber', column = 'name',         noun = 'prescriber', max = 120 }

--- Reads ---

-- Grain: one row per record of the kind, with its name.
local function named(kind)
  if kind == quick_add.PERSON then
    return pv.query('SELECT id, display_name AS name FROM person ORDER BY display_name COLLATE NOCASE, id')
  elseif kind == quick_add.PHARMACY then
    return pv.query('SELECT id, name FROM pharmacy ORDER BY name COLLATE NOCASE, id')
  elseif kind == quick_add.PLAN then
    return pv.query('SELECT id, name FROM plan ORDER BY name COLLATE NOCASE, id')
  end
  return pv.query('SELECT id, name FROM prescriber ORDER BY name COLLATE NOCASE, id')
end

--- The choices of a drop-down for one kind of record.
-- @param kind table  One of quick_add.PERSON, quick_add.PHARMACY, quick_add.PRESCRIBER, quick_add.PLAN.
-- @return table  A list of { value = id, label = name }, ordered by name.
function quick_add.options(kind)
  local options = {}
  for _, row in ipairs(named(kind)) do
    options[#options + 1] = { value = row.id, label = row.name }
  end
  return options
end

--- Read a choice that may be a new record.
-- The form holds a drop-down called `field` and a box called `field` .. '_new'. The box
-- wins when both are filled in, because typing is the more deliberate act. A typed name
-- that a record already has picks that record, so a name is never added twice.
-- @param form table      The values of the form.
-- @param field string    The name of the drop-down, such as 'pharmacy_id'.
-- @param kind table      One of the kinds above.
-- @param required boolean|nil
-- @return string|nil, table|nil, string|nil  The id of an existing record; or nil and
--         the row of a record to add; or nil, nil and a message. An empty optional
--         choice returns three nils. Reads only; writes nothing.
function quick_add.read(form, field, kind, required)
  local typed, problem = validate.text(form[field .. '_new'], 'the name of the new ' .. kind.noun, kind.max)
  if problem then return nil, nil, problem end
  if typed then
    local key = text.key(typed)
    for _, row in ipairs(named(kind)) do
      if text.key(row.name) == key then return row.id end
    end
    return nil, { [kind.column] = typed }
  end

  local id = text.clean(form[field])
  if id == quick_add.NEW then
    return nil, nil, 'Type the name of the new ' .. kind.noun .. '.'
  end
  if not id then
    if required then
      return nil, nil, 'Choose a ' .. kind.noun .. ', or type the name of a new one.'
    end
    return nil
  end
  if not pv.get_row(kind.tbl, id) then
    return nil, nil, 'Choose a ' .. kind.noun .. ' from the list.'
  end
  return id
end

--- Add the new record of a choice inside a batch.
-- @param tx table         The batch.
-- @param kind table       One of the kinds above.
-- @param id string|nil    The id that quick_add.read returned.
-- @param new_row table|nil  The row that quick_add.read returned.
-- @return string|nil  The id to store: the given one, or the id of the record just added.
function quick_add.write(tx, kind, id, new_row)
  if new_row then return tx.append(kind.tbl, new_row) end
  return id
end

return quick_add
