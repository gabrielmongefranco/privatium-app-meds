-- This file is part of Prescription Tracker
-- tests/lua/test_validate.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Unit tests for apps/meds/lib/validate.lua: normal values, empty input, invalid
--          values and boundaries.
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

local validate = require 'validate'

-- The first result of a check, and whether it gave a message.
local function value_of(...) return (...) end
local function refused(...) return select(2, ...) ~= nil end

return function(equal)
  --- text ---
  equal('text returns the cleaned value', value_of(validate.text(' Alex ', 'the name', 10, true)), 'Alex')
  equal('text refuses an empty required field', refused(validate.text('', 'the name', 10, true)), true)
  equal('text names the field', select(2, validate.text('', 'the name', 10, true)), 'Enter the name.')
  equal('text accepts an empty optional field', refused(validate.text('', 'the clinic', 10)), false)
  equal('text accepts the longest value', value_of(validate.text('1234567890', 'the name', 10)), '1234567890')
  equal('text refuses one character too many', refused(validate.text('12345678901', 'the name', 10)), true)
  equal('text counts characters, not bytes', value_of(validate.text('éééé', 'the name', 4)), 'éééé')
  equal('text refuses bytes that are not UTF-8', refused(validate.text('\xff', 'the name', 10)), true)

  --- date ---
  equal('date accepts a real date', value_of(validate.date('1980-01-31', 'the birth date')), '1980-01-31')
  equal('date accepts 29 February in a leap year', value_of(validate.date('2024-02-29', 'the date')), '2024-02-29')
  equal('date refuses 29 February in another year', refused(validate.date('2026-02-29', 'the date')), true)
  equal('date refuses 29 February 1900', refused(validate.date('1900-02-29', 'the date')), true)
  equal('date accepts 29 February 2000', value_of(validate.date('2000-02-29', 'the date')), '2000-02-29')
  equal('date refuses 30 February', refused(validate.date('2026-02-30', 'the date')), true)
  equal('date refuses month 13', refused(validate.date('2026-13-01', 'the date')), true)
  equal('date refuses day 0', refused(validate.date('2026-01-00', 'the date')), true)
  equal('date refuses month-day-year', refused(validate.date('01/31/1980', 'the date')), true)
  equal('date refuses words', refused(validate.date('yesterday', 'the date')), true)
  equal('date accepts an empty optional field', refused(validate.date('', 'the date')), false)
  equal('date refuses an empty required field', refused(validate.date('', 'the date', true)), true)

  --- not_after ---
  equal('not_after accepts the limit itself', value_of(validate.not_after('2026-09-27', '2026-09-27', 'late')), '2026-09-27')
  equal('not_after refuses the day after', refused(validate.not_after('2026-09-28', '2026-09-27', 'late')), true)
  equal('not_after passes nil through', refused(validate.not_after(nil, '2026-09-27', 'late')), false)

  --- whole_number ---
  equal('whole_number returns an integer', value_of(validate.whole_number('7', 'the days', 0, 365)), 7)
  equal('whole_number accepts the lowest value', value_of(validate.whole_number('0', 'the days', 0, 365)), 0)
  equal('whole_number accepts the highest value', value_of(validate.whole_number('365', 'the days', 0, 365)), 365)
  equal('whole_number refuses one above the highest', refused(validate.whole_number('366', 'the days', 0, 365)), true)
  equal('whole_number refuses a minus sign', refused(validate.whole_number('-1', 'the days', 0, 365)), true)
  equal('whole_number refuses a decimal point', refused(validate.whole_number('1.5', 'the days', 0, 365)), true)
  equal('whole_number refuses letters', refused(validate.whole_number('ten', 'the days', 0, 365)), true)
  equal('whole_number refuses a number too long to hold', refused(validate.whole_number('99999999999999999999999', 'the days', 0, 365)), true)
  equal('whole_number accepts an empty optional field', refused(validate.whole_number('', 'the days', 0, 365)), false)

  --- npi ---
  equal('npi accepts ten digits', value_of(validate.npi('1234567893')), '1234567893')
  equal('npi refuses nine digits', refused(validate.npi('123456789')), true)
  equal('npi refuses eleven digits', refused(validate.npi('12345678901')), true)
  equal('npi refuses a letter', refused(validate.npi('123456789X')), true)
  equal('npi accepts an empty field', refused(validate.npi('')), false)

  --- phone ---
  equal('phone keeps the number as written', value_of(validate.phone('(555) 555-0100', 'the phone number', 40)), '(555) 555-0100')
  equal('phone refuses text with no digit', refused(validate.phone('call me', 'the phone number', 40)), true)
  equal('phone accepts an empty field', refused(validate.phone('', 'the phone number', 40)), false)

  --- email ---
  equal('email accepts an address', value_of(validate.email('alex@example.com', 254)), 'alex@example.com')
  equal('email refuses a missing @', refused(validate.email('alex.example.com', 254)), true)
  equal('email refuses a space', refused(validate.email('alex @example.com', 254)), true)
  equal('email refuses a missing dot after the @', refused(validate.email('alex@example', 254)), true)

  --- website ---
  equal('website accepts https', value_of(validate.website('https://example.com', 200)), 'https://example.com')
  equal('website accepts http', value_of(validate.website('http://example.com/a?b=1', 200)), 'http://example.com/a?b=1')
  equal('website accepts capitals in the scheme', value_of(validate.website('HTTPS://example.com', 200)), 'HTTPS://example.com')
  equal('website refuses a script address', refused(validate.website('javascript:alert(1)', 200)), true)
  equal('website refuses a data address', refused(validate.website('data:text/html,x', 200)), true)
  equal('website refuses a missing scheme', refused(validate.website('www.example.com', 200)), true)
  equal('website refuses a space', refused(validate.website('https://example.com/a b', 200)), true)

  --- tel_href ---
  equal('tel_href keeps the digits', validate.tel_href('(555) 555-0100'), '5555550100')
  equal('tel_href keeps a leading plus sign', validate.tel_href('+1 555 555 0100'), '+15555550100')
  equal('tel_href leaves an extension out', validate.tel_href('555-0100 x12'), '5550100')
  equal('tel_href of too few digits is nil', validate.tel_href('12'), nil)
  equal('tel_href of nil is nil', validate.tel_href(nil), nil)
  equal('tel_href drops markup', validate.tel_href('555"><script>0100'), '555')
end
