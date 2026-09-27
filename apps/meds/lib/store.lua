-- This file is part of Prescription Tracker
-- apps/meds/lib/store.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: The one place where a screen writes a record or removes one. A refusal by the
--          framework becomes a message for the person and a masked line in the
--          diagnostic log.
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

local pv   = require 'privatium'
local page = require 'page'

local store = {}

--- Configuration ---
local REFUSED = 'The app could not save this. Check each field and try again.'

--- Write a whole record.
-- An amendment replaces the row, so `row` must hold every column of the table. A column
-- that is left out is cleared.
-- @param tbl string      The table name. Always a constant in the code, never typed.
-- @param id string|nil   The id to amend, or nil to add a record.
-- @param row table       Every column of the record.
-- @return string|nil, string|nil  The id of the record, or nil and a message. Writes one
--         event to the log. A refusal writes nothing.
function store.save(tbl, id, row)
  local saved, result = pcall(pv.append, tbl, id, row)
  if saved then return result end
  pv.log('warn', tbl .. ': save refused: ' .. page.masked(result))
  return nil, REFUSED
end

--- Write several changes that must land together.
-- @param tbl string     The table the batch is about, for the diagnostic log.
-- @param changes function  Receives the batch and calls its append and delete.
-- @return boolean, string|nil  True, or false and a message. A refusal writes nothing.
function store.together(tbl, changes)
  local saved, result = pcall(pv.batch, changes)
  if saved then return true end
  pv.log('warn', tbl .. ': batch refused: ' .. page.masked(result))
  return false, REFUSED
end

return store
