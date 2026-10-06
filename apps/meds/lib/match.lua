-- This file is part of Medication Tracker
-- apps/meds/lib/match.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Compares what a person typed with the names a medication answers to, and says
--          how well they match. Pure Lua with no framework calls, so plain Lua can test
--          it.
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

local text = require 'text'

local match = {}

--- Configuration ---
-- How many typing mistakes a word may hold and still count as close. A mistake is one
-- letter added, left out, changed, or swapped with its neighbor. Short words get none,
-- because one changed letter in a short word is usually another word.
local SHORT_WORD_LENGTH  = 4    -- Words this long or shorter must match exactly
local MEDIUM_WORD_LENGTH = 8    -- Words up to this length may hold one mistake
local MEDIUM_MISTAKES    = 1
local LONG_MISTAKES      = 2

-- The kinds of match, best first. The order is the order results are shown in.
match.EXACT    = 1   -- The whole name is what was typed
match.CONTAINS = 2   -- Every typed word starts a word of the name
match.CLOSE    = 3   -- Every typed word is near a word of the name

--- Distance ---

--- The number of typing mistakes between two words.
-- This is the optimal string alignment distance: insertions, deletions, substitutions
-- and swaps of two neighboring letters each count as one.
-- @param a string
-- @param b string
-- @return integer
function match.distance(a, b)
  local previous2, previous, current = nil, {}, {}
  for j = 0, #b do previous[j] = j end
  for i = 1, #a do
    current = { [0] = i }
    for j = 1, #b do
      local cost = a:byte(i) == b:byte(j) and 0 or 1
      local best = math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
      if previous2 and i > 1 and j > 1
         and a:byte(i) == b:byte(j - 1) and a:byte(i - 1) == b:byte(j) then
        best = math.min(best, previous2[j - 2] + 1)
      end
      current[j] = best
    end
    previous2, previous = previous, current
  end
  return previous[#b]
end

local function mistakes_allowed(word)
  if #word <= SHORT_WORD_LENGTH then return 0 end
  if #word <= MEDIUM_WORD_LENGTH then return MEDIUM_MISTAKES end
  return LONG_MISTAKES
end

local function words_of(key)
  local words = {}
  for word in key:gmatch('%S+') do words[#words + 1] = word end
  return words
end

--- Compare ---

-- How one typed word matches the words of a name: CONTAINS when it starts one of them,
-- CLOSE when it is near one of them, nil when neither.
local function word_kind(typed, name_words)
  local allowed = mistakes_allowed(typed)
  local kind
  for _, word in ipairs(name_words) do
    if word:sub(1, #typed) == typed then return match.CONTAINS end
    if allowed > 0 and math.abs(#word - #typed) <= allowed
       and match.distance(typed, word) <= allowed then
      kind = match.CLOSE
    end
  end
  return kind
end

--- How well a typed text matches one name.
-- @param typed string  What the person typed.
-- @param name string   One name of a medication.
-- @return integer|nil  match.EXACT, match.CONTAINS or match.CLOSE, or nil for no match.
function match.kind(typed, name)
  local typed_key, name_key = text.key(typed), text.key(name)
  if typed_key == '' or name_key == '' then return nil end
  if typed_key == name_key then return match.EXACT end

  local name_words = words_of(name_key)
  local kind = match.CONTAINS
  for _, word in ipairs(words_of(typed_key)) do
    local found = word_kind(word, name_words)
    if not found then return nil end
    if found > kind then kind = found end
  end
  return kind
end

--- How many words of a typed text are found among the words of some names.
-- A pharmacy or an insurer writes a name its own way, with a salt, a form or a package
-- after the drug. Such a name matches no catalog name as a whole, so this counts the
-- words that do match. The first typed word must be among them, because it is the drug.
-- @param typed string  The name as the pharmacy or the insurer wrote it.
-- @param names table   A list of strings: every name of one medication.
-- @return integer  The number of typed words found, or 0 when the first is not.
function match.overlap(typed, names)
  local name_words = {}
  for _, name in ipairs(names) do
    for _, word in ipairs(words_of(text.key(name))) do name_words[#name_words + 1] = word end
  end
  local found = 0
  for position, word in ipairs(words_of(text.key(typed))) do
    if word_kind(word, name_words) then
      found = found + 1
    elseif position == 1 then
      return 0
    end
  end
  return found
end

--- The medications that a typed text matches, best match first.
-- @param typed string  What the person typed.
-- @param names table   A list of { medication_id = id, name = text }, one for each name
--                      of each medication.
-- @return table  A list of { medication_id = id, kind = kind, name = the name that
--                matched }, one for each medication that matched, ordered by kind and
--                then by the order of `names`.
function match.rank(typed, names)
  local best, order = {}, {}
  for position, entry in ipairs(names) do
    local kind = match.kind(typed, entry.name)
    local known = best[entry.medication_id]
    if kind and (not known or kind < known.kind) then
      if not known then order[#order + 1] = entry.medication_id end
      best[entry.medication_id] = {
        medication_id = entry.medication_id,
        kind          = kind,
        name          = entry.name,
        position      = known and known.position or position,
      }
    end
  end
  local ranked = {}
  for _, id in ipairs(order) do ranked[#ranked + 1] = best[id] end
  table.sort(ranked, function(a, b)
    if a.kind ~= b.kind then return a.kind < b.kind end
    return a.position < b.position
  end)
  return ranked
end

return match
