-- This file is part of Medication Tracker
-- tests/lua/test_portals.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-10-05
-- Last Modified: 2026-10-05
-- Summary: Unit tests for the readers of pasted portal pages under apps/meds/lib/portals/ and
--          for how apps/meds/lib/portal_reader.lua picks one. Every name and number is invented.
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

local common           = require 'portals.common'
local dromos_statement = require 'portals.dromos_statement'
local mychart          = require 'portals.mychart'
local portal_reader    = require 'portal_reader'
local prime_claims     = require 'portals.prime_claims'
local prime_export     = require 'portals.prime_export'

local LAYOUTS = { prime_export, dromos_statement, mychart, prime_claims }

--- Invented pages ---

-- A MyChart medications page: one medication with its value after each label, one with
-- no fill, and one copied by a browser that puts each value on its own line.
local MYCHART = table.concat({
  'Examplol 10 mg tablet',
  'Generic name: exampline',
  'Learn more',
  'Take 1 tablet by mouth once daily.',
  '1 refill before May 1, 2027',
  'Prescription Details',
  'PrescribedJune 2, 2026',
  'Approved bySample, Pat',
  'Prescription number200001-03',
  'Refill Details',
  'Quantity30 tablets',
  'Day supply30',
  'Last filledSeptember 3, 2026',
  'Next fillOctober 3, 2026',
  'Pharmacy Details',
  'Anytown Drug - Anytown, MI - 1 Main St',
  '1 Main St, Anytown MI 48000',
  '555-555-0110',
  'Map',
  'Samplamide 5 mg capsule',
  'Commonly known as: SAMPLAMIDE',
  'Learn more',
  'This prescription cannot be refilled through MyChart. Contact your pharmacy for a refill.',
  'Details',
  'Started takingAugust 1, 2026',
  'Documented bySample N, MA',
  '<b>Testorin</b> 2 mg/mL solution',
  'Learn more',
  'Prescription Details',
  'Prescribed',
  'July 1, 2026',
  'Refill Details',
  'Quantity',
  '150 mL',
  'Days supply',
  '25',
  'Last filled',
  'Sept. 12, 2026',
  'Pharmacy Details',
  'Mail Order Example Pharmacy',
  '555-555-0120',
  'Map',
}, '\r\n')

-- A Prime claims history export as a spreadsheet copies it, with its columns in another
-- order than usual, a pharmacy run together on one line, a pharmacy cell with line breaks
-- in quotation marks, and an empty row.
local EXPORT = table.concat({
  'Date of Service\tRx Number\tDrug Name\tDays Supply\tQuantity\tPharmacy\tPharmacy ID\tPatient Responsibility\tPlan Paid Amount\tDeductible\tClaim Status',
  '09/20/2026\t200010\tEXAMPLINE 10 MG TABLET\t30\t30\tANYTOWN DRUG #12 1 MAIN ST ANYTOWN, MI 48000 (555) 555-0110\t1234567893     \t$5.00\t$12.00\t$0.00\tPaid',
  '9/2/2026\t200011\t"SAMPLAMIDE ""SOD"" 5 MG CAP"\t90\t90\t"MAIL ORDER EXAMPLE',
  '2 SECOND AVE',
  'SAMPLETON, MI 48001',
  '(555) 555-0120"\t1245319599\t$0.00\t$40.00\t$0.00\tDenied',
  '\t\t\t\t\t\t\t\t\t\t',
}, '\n')

-- A DromosPTM patient tax statement without its heading row. The second row was copied
-- from a narrow window, which hides columns.
local STATEMENT = table.concat({
  ' \tSep 03, 2026\t200020\tEXAMPLINE 10MG TABS',
  'NDC: 00000-0000-00\t30\t30\tDr. PAT SAMPLE\tAnytown Drug',
  '(555) 555-0110\tEXAMPLE PLAN\t$12.00\t$5.00',
  ' \tJul 01, 2026\t200022\tTESTORIN 2MG TABS',
  'NDC: 00000-0000-02\t30\tAnytown Drug',
  '(555) 555-0110\t$5.00',
  '\194\160\tAug 4, 2026\t200021\tSAMPLAMIDE 5MG CAPS',
  'NDC: 00000-0000-01\t90\t90\tDr. PAT SAMPLE\tAnytown Drug',
  '(555) 555-0110\tCash\t$\t$30.00',
}, '\n')

-- The same statement with the heading row of a narrow window, which names the columns
-- that are left.
local NARROW = table.concat({
  '\194\160\tDate Sold\tRx Number\tMedication\tQuantity\tPharmacy\tPatient Copay',
  ' \tSep 03, 2026\t200020\tEXAMPLINE 10MG TABS',
  'NDC: 00000-0000-00\t30\tAnytown Drug',
  '(555) 555-0110\t$5.00',
}, '\n')

local CLAIMS = table.concat({
  'SERVICE DATEDRUG NAMEPHARMACYPLAN PAIDYOU PAIDCLAIM STATUS',
  '09/20/2026EXAMPLINE 10 MG TABLETANYTOWN DRUG$ 12.00$ 5.00PaidMore Infosort Icon',
}, '\n')

-- Pages that list medications with no fill to read.
local MEDICATION_LIST = table.concat({
  'Your Medications', 'Examplol 10 mg tablet', 'Take 1 tablet daily', 'Refills Remaining: 1',
  'Quantity Dispensed: 30', 'Days Supply:', 'Last Pickup Date:', 'Rx#: 200030', 'Rx expires', '3/27/2028',
}, '\n')
local PRESCRIPTION_LIST = table.concat({
  ' \t\t200031', 'EXAMPLINE 10MG TABS', 'Quantity: 30', 'Dr. SAMPLE', '',
  'Image of EXAMPLINE 10MG TABS\tSep 03, 2026\t4\tREFILLABLE This prescription is refillable.\t Anytown Drug',
  ', Anytown', '(555) 555-0110',
}, '\n')

-- The names of the layouts that recognize a text.
local function recognized_by(pasted)
  local page = common.page_of(pasted)
  local names = {}
  for _, layout in ipairs(LAYOUTS) do
    if layout.recognizes(page) then names[#names + 1] = layout.NAME end
  end
  return table.concat(names, ', ')
end

return function(equal)
  --- Which page a text is ---
  -- Export rows open with a date, so the claims page knows them too. It is asked last
  -- for that reason, and the export is read as the export.
  equal('the export is recognized by the export first', recognized_by(EXPORT),
    prime_export.NAME .. ', ' .. prime_claims.NAME)
  equal('the export is read as the export', select(2, portal_reader.read(EXPORT)).name, prime_export.NAME)
  equal('the statement is recognized by one layout', recognized_by(STATEMENT), dromos_statement.NAME)
  equal('the narrow statement is recognized by one layout', recognized_by(NARROW), dromos_statement.NAME)
  equal('MyChart is recognized by one layout', recognized_by(MYCHART), mychart.NAME)
  equal('the claims page is recognized by one layout', recognized_by(CLAIMS), prime_claims.NAME)
  equal('a medication list is recognized by none', recognized_by(MEDICATION_LIST), '')
  equal('a prescription list is recognized by none', recognized_by(PRESCRIPTION_LIST), '')
  local none, about = portal_reader.read(MEDICATION_LIST)
  equal('a medication list gives no fill', #none, 0)
  equal('a medication list is not read as any page', about, nil)
  equal('the reader names every page it reads', #portal_reader.names(), 4)

  --- MyChart ---
  local claims, read = portal_reader.read(MYCHART)
  equal('MyChart gives one fill for each medication with a fill date', #claims, 2)
  equal('MyChart is named', read.name, mychart.NAME)
  equal('a medication with no fill date is counted', read.left_out_note,
    '1 medication shows no fill date, so it is not listed.')
  local first = claims[1]
  equal('the name is the line above the other name', first.drug_name, 'Examplol 10 mg tablet')
  equal('the fill date is the last one', first.filled_on, '2026-09-03')
  equal('the prescription number follows its label', first.rx_number, '200001-03')
  equal('the quantity drops its unit', first.quantity, '30')
  equal('the days supply is read', first.days_supply, '30')
  equal('the pharmacy name keeps its town', first.pharmacy_name, 'Anytown Drug - Anytown, MI - 1 Main St')
  equal('the pharmacy address is read', first.pharmacy_address, '1 Main St, Anytown MI 48000')
  equal('the pharmacy phone is read', first.pharmacy_phone, '555-555-0110')
  equal('MyChart gives no payment status', first.has_status, false)
  equal('MyChart gives no amount paid', first.amount_paid, nil)
  local third = claims[2]
  equal('markup in a name is kept as text', third.drug_name, '<b>Testorin</b> 2 mg/mL solution')
  equal('a value on the next line is read', third.quantity, '150')
  equal('days supply with an s is read', third.days_supply, '25')
  equal('a short month with a dot is read', third.filled_on, '2026-09-12')
  equal('a pharmacy with no address keeps its phone', third.pharmacy_phone, '555-555-0120')
  equal('a pharmacy with no address has none', third.pharmacy_address, nil)
  equal('a medication with no number has none', third.rx_number, nil)

  --- Prime claims history export ---
  claims, read = portal_reader.read(EXPORT)
  equal('every row of the export is a fill, the empty row is not', #claims, 2)
  equal('the export leaves nothing out', read.left_out_note, nil)
  first = claims[1]
  equal('columns are found by heading', first.drug_name, 'EXAMPLINE 10 MG TABLET')
  equal('the export date is turned around', first.filled_on, '2026-09-20')
  equal('the export prescription number is read', first.rx_number, '200010')
  equal('the export days supply is read', first.days_supply, '30')
  equal('the pharmacy identifier loses its spaces', first.pharmacy_npi, '1234567893')
  equal('what the patient paid is read', first.amount_paid, '5.00')
  equal('what the plan paid is read', first.plan_paid, '12.00')
  equal('the export status is read', first.status, 'Paid')
  equal('the export has its details', first.details_open, true)
  equal('a pharmacy on one line keeps its store number in the name', first.pharmacy_name, 'ANYTOWN DRUG #12')
  equal('the street starts the address', first.pharmacy_address, '1 MAIN ST ANYTOWN, MI 48000')
  equal('the phone is split off the end', first.pharmacy_phone, '(555) 555-0110')
  local second = claims[2]
  equal('a date with one-digit parts is read', second.filled_on, '2026-09-02')
  equal('doubled quotation marks in a cell are one', second.drug_name, 'SAMPLAMIDE "SOD" 5 MG CAP')
  equal('a pharmacy cell with line breaks gives its name', second.pharmacy_name, 'MAIL ORDER EXAMPLE')
  equal('the address lines are joined', second.pharmacy_address, '2 SECOND AVE, SAMPLETON, MI 48001')
  equal('the last line is the phone', second.pharmacy_phone, '(555) 555-0120')
  equal('a denied claim keeps its status', second.status, 'Denied')

  --- DromosPTM patient tax statement ---
  claims, read = portal_reader.read(STATEMENT)
  equal('rows of the statement are fills', #claims, 2)
  equal('a row that misses columns is counted', read.left_out_note,
    '1 row misses columns, so it is not listed. Make the window wider, then copy the table again.')
  first = claims[1]
  equal('the date sold is read', first.filled_on, '2026-09-03')
  equal('the product number is not part of the name', first.drug_name, 'EXAMPLINE 10MG TABS')
  equal('the statement prescription number is read', first.rx_number, '200020')
  equal('the statement quantity is read', first.quantity, '30')
  equal('the statement days supply is read', first.days_supply, '30')
  equal('the patient copay is what the patient paid', first.amount_paid, '5.00')
  equal('the insurance portion is what the plan paid', first.plan_paid, '12.00')
  equal('the statement pharmacy is read', first.pharmacy_name, 'Anytown Drug')
  equal('the statement pharmacy phone is read', first.pharmacy_phone, '(555) 555-0110')
  equal('the statement gives no payment status', first.has_status, false)
  second = claims[2]
  equal('a row after a short one is still read', second.rx_number, '200021')
  equal('a date with a one-digit day is read', second.filled_on, '2026-08-04')
  equal('an empty insurance portion is empty', second.plan_paid, nil)
  equal('a cash fill keeps what was paid', second.amount_paid, '30.00')

  claims = portal_reader.read(NARROW)
  equal('a heading row is not a fill', #claims, 1)
  equal('a heading row names the columns that are left', claims[1].amount_paid, '5.00')
  equal('a hidden column is empty', claims[1].days_supply, nil)
  equal('a heading row still finds the pharmacy', claims[1].pharmacy_name, 'Anytown Drug')

  --- Shared pieces ---
  equal('a month and day are padded', common.us_date('9/2/2026'), '2026-09-02')
  equal('a full month name is read', common.month_date('October 5, 2026'), '2026-10-05')
  equal('an unknown month name is not a date', common.month_date('Smarch 5, 2026'), nil)
  equal('a date written another way is kept for the check', common.any_date('the 5th'), 'the 5th')
  equal('a sign alone is no amount', common.money('$'), nil)
  equal('a number with a comma keeps it', common.leading_number('1,000 each'), '1,000')
  equal('a value with no number is kept for the check', common.leading_number('some'), 'some')
  equal('a pharmacy with no street is all name', common.pharmacy_parts('ANYTOWN DRUG'), 'ANYTOWN DRUG')
  equal('a cell that is only a phone has no name', common.pharmacy_parts('(555) 555-0110'), nil)
end
