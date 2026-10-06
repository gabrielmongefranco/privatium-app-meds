-- This file is part of Medication Tracker
-- tests/lua/test_portal_reader.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: Unit tests for apps/meds/lib/portal_reader.lua and for the matching of names as
--          a portal writes them. Every name and number is invented.
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

local portal_reader = require 'portal_reader'
local match = require 'match'

-- An invented page in the claims layout: three fills with their details open, the
-- second with no amount from the plan, and a fourth with its details closed.
local PAGE = table.concat({
  'SERVICE DATEDRUG NAMEPHARMACYPLAN PAIDYOU PAIDCLAIM STATUS',
  "09/20/2026EXAMPLINE 10 MG TABLETEXAMPLE'S PHARMACY$ 1,240.12$ 5.00PaidLess Infosort Icon",
  "EXAMPLE'S PHARMACY",
  '',
  '1 EXAMPLE STREET. ANYTOWN, MI 480000000',
  '',
  '555-555-0100',
  '',
  'PHARMACY ID',
  '1234567893',
  '',
  'RX NUMBER',
  '100001',
  '',
  'DAYS SUPPLY',
  '30',
  '',
  'QUANTITY',
  '30',
  '',
  'Plan Paid',
  '',
  '$1,240.12',
  'Deductible',
  '',
  '$0.00',
  'Patient Responsibility',
  '',
  '$5.00',
  "09/21/2026SAMPLAMIDE SOD 5 MG CAPEXAMPLE'S PHARMACY$ 28.35PaidLess Infosort Icon",
  "EXAMPLE'S PHARMACY",
  '',
  '1 EXAMPLE STREET. ANYTOWN, MI 480000000',
  '',
  '555-555-0100',
  '',
  'PHARMACY ID',
  '1234567893',
  '',
  'RX NUMBER',
  '100002',
  '',
  'DAYS SUPPLY',
  '90',
  '',
  'QUANTITY',
  '90',
  '',
  'Plan Paid',
  '',
  '$',
  'Deductible',
  '',
  '$0.00',
  'Patient Responsibility',
  '',
  '$28.35',
  '09/22/2026TEST STRIPS 50CTSAMPLE SUPPLY CO$ 10.00$ 0.00ReversedLess Infosort Icon',
  'SAMPLE SUPPLY CO',
  '',
  'PHARMACY ID',
  '1234567893',
  'RX NUMBER',
  '100003',
  '09/23/2026EXAMPLINE 10 MG TABLETEXAMPLE PHARMACY$ 12.00$ 5.00PaidMore Infosort Icon',
}, '\r\n')

return function(equal)
  local claims = portal_reader.read(PAGE)
  equal('every fill is found', #claims, 4)
  equal('the heading line is not a fill', claims[1].filled_on, '2026-09-20')
  equal('the page is read as the claims page', select(2, portal_reader.read(PAGE)).name,
    'Prime Therapeutics recent claims')

  local first = claims[1]
  equal('the date is turned into year-month-day', first.filled_on, '2026-09-20')
  equal('the drug name is split from the pharmacy name', first.drug_name, 'EXAMPLINE 10 MG TABLET')
  equal('the pharmacy name keeps its apostrophe', first.pharmacy_name, "EXAMPLE'S PHARMACY")
  equal('the address is read', first.pharmacy_address, '1 EXAMPLE STREET. ANYTOWN, MI 480000000')
  equal('the phone number is read', first.pharmacy_phone, '555-555-0100')
  equal('the pharmacy identifier is read', first.pharmacy_npi, '1234567893')
  equal('the prescription number is read', first.rx_number, '100001')
  equal('the days supply is read', first.days_supply, '30')
  equal('the quantity is read', first.quantity, '30')
  equal('what the patient paid is read', first.amount_paid, '5.00')
  equal('what the plan paid keeps its comma for the check that follows', first.plan_paid, '1,240.12')
  equal('the status is read', first.status, 'Paid')
  equal('open details are noticed', first.details_open, true)

  local second = claims[2]
  equal('a second fill has its own number', second.rx_number, '100002')
  equal('a sign with no amount is an empty amount', second.plan_paid, nil)
  equal('the amount comes from the details, not from the row', second.amount_paid, '28.35')
  equal('a name with a salt is kept as written', second.drug_name, 'SAMPLAMIDE SOD 5 MG CAP')

  local third = claims[3]
  equal('a status other than Paid is read', third.status, 'Reversed')
  equal('a fill with no address still has its pharmacy', third.pharmacy_name, 'SAMPLE SUPPLY CO')
  equal('a label right after the name is not an address', third.pharmacy_address, nil)
  equal('values with no empty line between them are read', third.rx_number, '100003')

  local fourth = claims[4]
  equal('closed details are noticed', fourth.details_open, false)
  equal('closed details give no prescription number', fourth.rx_number, nil)
  equal('closed details cannot split the two names', fourth.names_joined, true)
  equal('two amounts in a row give what the patient paid', fourth.amount_paid, '5.00')

  --- Text that is not a claims page ---
  equal('an empty text gives no fill', #portal_reader.read(''), 0)
  equal('other text gives no fill', #portal_reader.read('Hello\nworld 09/20/2026'), 0)
  equal('a value that is not text gives no fill', #portal_reader.read(nil), 0)
  local hostile = portal_reader.read("09/20/2026<script>alert(1)</script>'; DROP TABLE fill;--$ 1.00$ 1.00PaidLess Info\nX")
  equal('markup and SQL are read as a name, nothing more', hostile[1].drug_name:find('<script>', 1, true) ~= nil, true)

  --- Names as a portal writes them ---
  local names = { 'Examplol (Exampline) 10 mg', 'Exampline', 'Examplol', 'Exampline hydrochloride' }
  equal('every word of a portal name that the catalog knows is counted',
    match.overlap('EXAMPLINE 10 MG TABLET', names), 3)
  equal('an abbreviation counts when it starts a word', match.overlap('EXAMPLINE HYDRO 10 MG', names), 4)
  equal('a name whose first word is unknown counts nothing', match.overlap('TABLET EXAMPLINE', names), 0)
  equal('a different drug counts nothing', match.overlap('SAMPLAMIDE 10 MG', names), 0)
end
