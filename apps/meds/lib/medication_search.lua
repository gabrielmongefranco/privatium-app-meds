-- This file is part of Medication Tracker
-- apps/meds/lib/medication_search.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Finds the medications of the catalog that a typed name matches. Every screen that
--          asks for a medication searches here, so all of them find the same things.
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


local pv    = require 'privatium'
local match = require 'match'
local text  = require 'text'
local written_name = require 'written_name'

local medication_search = {}

--- Configuration ---
local TYPED_MAX = 100   -- Longer than any name a person would type to search
local FOUND_MAX = 50    -- The most medications one search returns, best first

-- The catalog can hold thousands of names, and a request may run only so many steps.
-- So every search asks the database for the few medications worth comparing, and
-- compares those in Lua. The database narrows by plain text; Lua decides.

--- Reads ---

-- Every name of the medications that have a name holding a text.
-- Grain: one row per medication per distinct name.
local function names_holding(part)
  return pv.query([[
    SELECT n.medication_id, n.name
      FROM v_medication_name n
     WHERE n.medication_id IN (SELECT c.medication_id
                                 FROM v_medication_name c
                                WHERE c.name LIKE '%' || ?1 || '%')
     ORDER BY n.name COLLATE NOCASE, n.medication_id]], { part })
end

-- Every name of the medications that have a name with a word starting with a letter.
-- Brackets and hyphens count as spaces, so 'Lipitor (Atorvastatin)' has a word that
-- starts with 'a'.
-- Grain: one row per medication per distinct name.
local function names_with_word_from(letter)
  return pv.query([[
    SELECT n.medication_id, n.name
      FROM v_medication_name n
     WHERE n.medication_id IN (
             SELECT c.medication_id
               FROM v_medication_name c
              WHERE ' ' || replace(replace(replace(c.name, '(', ' '), '-', ' '), '/', ' ')
                    LIKE '% ' || ?1 || '%')
     ORDER BY n.name COLLATE NOCASE, n.medication_id]], { letter })
end

-- One medication, as the screens show it.
local function medication(id)
  return pv.query1([[
    SELECT medication_id, short_name, full_name, is_specialty, is_controlled, brand_name, generic_name, strength
      FROM v_medication
     WHERE medication_id = ?]], { id })
end

local function words_of(key)
  local words = {}
  for word in key:gmatch('%S+') do words[#words + 1] = word end
  return words
end

-- The longest word of a key, which narrows a search the most.
local function longest(words)
  local best = words[1]
  for _, word in ipairs(words) do
    if #word > #best then best = word end
  end
  return best
end

--- Clean what a person typed into a search box.
-- @param raw any
-- @return string  The cleaned text, or '' when it is empty or too long to be a name.
function medication_search.typed(raw)
  local typed = text.clean(raw) or ''
  if (text.length(typed) or TYPED_MAX + 1) > TYPED_MAX then return '' end
  return typed
end

--- Search the catalog.
-- @param typed string  What the person typed, already cleaned.
-- @return table  { matches = list, close = list, exact = boolean }. Each list entry is a
--         medication row with `matched_name`, the name that matched. `matches` holds the
--         medications whose name is or contains what was typed. `close` holds the ones
--         that are near it, which a person must confirm; it is filled in only when
--         `matches` is empty. The two lists hold FOUND_MAX medications at most. `exact`
--         says whether a name is exactly what was typed.
function medication_search.find(typed)
  local found = { matches = {}, close = {}, exact = false }
  local words = words_of(text.key(typed))
  if #words == 0 then return found end

  -- A name that is or contains what was typed holds each typed word as it is written.
  local ranked = match.rank(typed, names_holding(longest(words)))
  if #ranked == 0 then
    -- A name with a typing mistake shares its first letter with what was typed, in
    -- nearly every case. The few that do not are found once the letter is corrected.
    ranked = match.rank(typed, names_with_word_from(words[1]:sub(1, 1)))
  end

  for position, result in ipairs(ranked) do
    if position > FOUND_MAX then break end
    local row = medication(result.medication_id)
    -- A name can outlive its medication for a moment while another device syncs.
    if row then
      row.matched_name = result.name
      row.exact = result.kind == match.EXACT
      if result.kind == match.CLOSE then
        found.close[#found.close + 1] = row
      else
        found.matches[#found.matches + 1] = row
        if result.kind == match.EXACT then found.exact = true end
      end
    end
  end
  return found
end

--- One medication, with how well a written name fits it.
-- @param id string       The id of the medication.
-- @param written string  The name as a pharmacy or an insurer wrote it.
-- @return table|nil, boolean  The medication as a row of v_medication, or nil when it
--         is gone; and whether the first word of the written name, the drug, is among
--         the names of the medication.
function medication_search.fit(id, written)
  local row = medication(id)
  if not row then return nil, false end
  local names = {}
  for _, name in ipairs(pv.query(
      'SELECT name FROM v_medication_name WHERE medication_id = ?', { id })) do
    names[#names + 1] = name.name
  end
  return row, match.overlap(written, names) > 0
end

--- Suggest medications for a name as a pharmacy or an insurer wrote it.
-- @param written string  The name as written, such as 'EXAMPLINE HCL 10 MG TABLET'.
-- @param limit integer   The most suggestions to return.
-- @return table, table|nil  The suggestions, best first, as rows of v_medication. The
--         second value is the one medication that answers to exactly this name, when
--         there is exactly one; only that one may be chosen without asking. A
--         suggestion has `sure` set when it is the only medication whose brand or
--         generic name starts the written name and whose strength the written name
--         holds. Such a suggestion comes first.
function medication_search.suggest(written, limit)
  local words = words_of(text.key(written))
  if #words == 0 then return {}, nil end

  -- The first word of a written name is the drug. The medications that hold it are
  -- compared; when none does, the ones whose words start with its first letter are.
  local names = names_holding(words[1])
  if #names == 0 then names = names_with_word_from(words[1]:sub(1, 1)) end

  local by_medication, order, exact = {}, {}, {}
  for _, row in ipairs(names) do
    if not by_medication[row.medication_id] then
      by_medication[row.medication_id] = {}
      order[#order + 1] = row.medication_id
    end
    table.insert(by_medication[row.medication_id], row.name)
    if match.kind(written, row.name) == match.EXACT then exact[row.medication_id] = true end
  end

  local scored = {}
  for position, id in ipairs(order) do
    local overlap = match.overlap(written, by_medication[id])
    if overlap > 0 then
      scored[#scored + 1] = { medication_id = id, overlap = overlap, position = position }
    end
  end
  table.sort(scored, function(a, b)
    if a.overlap ~= b.overlap then return a.overlap > b.overlap end
    return a.position < b.position
  end)

  local sure, rows = {}, {}
  for position, entry in ipairs(scored) do
    if position > FOUND_MAX then break end
    local row = medication(entry.medication_id)
    if row then
      rows[#rows + 1] = row
      if written_name.has_strength(written, row.strength)
         and (written_name.starts_with(written, row.generic_name)
              or written_name.starts_with(written, row.brand_name)) then
        sure[#sure + 1] = row
      end
    end
  end

  local suggestions = {}
  if #sure == 1 then
    sure[1].sure = true
    suggestions[1] = sure[1]
  end
  for _, row in ipairs(rows) do
    if not row.sure and #suggestions < limit then suggestions[#suggestions + 1] = row end
  end

  local known
  for _, row in ipairs(rows) do
    if exact[row.medication_id] then
      -- Two medications that answer to the same name leave the choice to the person.
      if known then return suggestions, nil end
      known = row
    end
  end
  return suggestions, known
end

return medication_search
