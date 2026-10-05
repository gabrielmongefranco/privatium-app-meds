-- This file is part of Prescription Tracker
-- apps/meds/lib/spending_chart.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: The bar chart of what was paid each year: where each bar, axis line and
--          label goes, the average line, and a sentence that says the same in words.
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

local spending_chart = {}

--- Configuration ---
-- The drawing is laid out in these units and scales to the width of the page.
local WIDTH, HEIGHT = 640, 300
local LEFT, RIGHT, TOP, BOTTOM = 76, 16, 28, 44   -- Room for the amounts, the value labels and the years
local BAR_SHARE   = 0.6    -- Share of each year's slot that its bar fills
local BAR_MAX     = 72     -- Widest bar, so two years do not draw two slabs
local TICKS       = 4      -- Lines across the chart above the zero line
local FULL_YEARS_MIN = 2   -- An average of one year would only repeat its bar

--- Money as whole cents ---
-- Totals arrive as exact decimal text. Whole cents in a 64-bit integer stay exact, so
-- the average never passes through a float.

local function cents_of(amount)
  if amount == nil then return nil end
  local whole, fraction = tostring(amount):match('^(%d+)%.?(%d*)$')
  if not whole then return nil end
  fraction = (fraction .. '00'):sub(1, 2)
  return math.tointeger(tonumber(whole)) * 100 + math.tointeger(tonumber(fraction))
end

local function text_of(cents)
  return ('%d.%02d'):format(cents // 100, cents % 100)
end

-- Rounds half up, the way the money columns round a positive amount.
local function divided(numerator, denominator)
  return (2 * numerator + denominator) // (2 * denominator)
end

--- Scale ---

-- The top of the scale: a round step of 1, 2 or 5 times a power of ten, in whole
-- dollars, so each line across the chart is an easy number.
local function scale_top(cents)
  local dollars = math.max(1, -((-cents) // 100))
  local step = 1
  while true do
    for _, factor in ipairs({ 1, 2, 5 }) do
      if factor * step * TICKS >= dollars then return factor * step * TICKS * 100 end
    end
    step = step * 10
  end
end

local function number(value) return ('%.1f'):format(value) end

--- Chart ---

--- Lay out the chart.
-- @param years table  One row per year, oldest first: { year = 'YYYY', amount_paid =
--        exact decimal text or nil when no fill gave an amount, fills = count }.
-- @param current_year string  This year as 'YYYY'. Its bar is the year so far, so it is
--        marked and left out of the average.
-- @param money function  Turns exact decimal text into money words, such as '$12.50'.
-- @return table|nil  Nil when there is no year. Otherwise { width, height, bars, ticks,
--         average, description, has_partial }. Every position is text ready for an SVG
--         attribute. `average` is nil with fewer than two full years.
function spending_chart.layout(years, current_year, money)
  if #years == 0 then return nil end
  local plot_width, plot_height = WIDTH - LEFT - RIGHT, HEIGHT - TOP - BOTTOM

  --- Average of the full years ---
  local full_years, total = 0, 0
  for _, row in ipairs(years) do
    row.cents = cents_of(row.amount_paid)
    if row.year < current_year and row.cents then
      full_years, total = full_years + 1, total + row.cents
    end
  end
  local average = full_years >= FULL_YEARS_MIN and divided(total, full_years) or nil

  --- Scale ---
  local highest = average or 0
  for _, row in ipairs(years) do highest = math.max(highest, row.cents or 0) end
  local top = scale_top(highest)
  local function y_of(cents) return TOP + plot_height - plot_height * math.max(cents, 0) / top end

  --- Bars ---
  local slot = plot_width / #years
  local bar_width = math.min(slot * BAR_SHARE, BAR_MAX)
  local chart = { width = WIDTH, height = HEIGHT, bars = {}, ticks = {} }
  local function center(place) return LEFT + slot * (place - 0.5) end
  for place, row in ipairs(years) do
    local y = y_of(row.cents or 0)
    chart.bars[#chart.bars + 1] = {
      x = number(center(place) - bar_width / 2), y = number(y), width = number(bar_width),
      height = number(TOP + plot_height - y), center = number(center(place)),
      year_y = number(HEIGHT - BOTTOM + 20), value_y = number(y - 8),
      year = row.year, is_partial = row.year >= current_year,
      year_label = row.year >= current_year and (row.year .. ' so far') or row.year,
      value_label = row.cents and money(text_of(row.cents)) or 'Not given',
    }
  end

  --- Lines across ---
  for step = 0, TICKS do
    local cents = top * step // TICKS
    chart.ticks[#chart.ticks + 1] = {
      y = number(y_of(cents)), label_y = number(y_of(cents) + 4), label_x = number(LEFT - 8),
      label = (money(text_of(cents)):gsub('%.00$', '')),
    }
  end
  chart.plot_left, chart.plot_right = number(LEFT), number(WIDTH - RIGHT)

  --- Average line and words ---
  local sentences = {}
  local first, last = years[1].year, years[#years].year
  sentences[1] = first == last and ('Total paid in ' .. first .. '.')
    or ('Total paid each year from ' .. first .. ' to ' .. last .. '.')
  chart.has_partial = last >= current_year
  if chart.has_partial then sentences[#sentences + 1] = last .. ' is the year so far.' end
  if average then
    chart.average = {
      x1 = chart.plot_left, x2 = chart.plot_right, y = number(y_of(average)),
      label = money(text_of(average)),
    }
    sentences[#sentences + 1] = 'The average of the full years is ' .. chart.average.label .. '.'
  else
    sentences[#sentences + 1] = 'The average needs at least ' .. FULL_YEARS_MIN .. ' full years of fills.'
  end
  chart.description = table.concat(sentences, ' ')
  return chart
end

return spending_chart
