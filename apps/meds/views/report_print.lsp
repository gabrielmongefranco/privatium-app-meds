<?--
This file is part of Medication Tracker
apps/meds/views/report_print.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: The spending report, made for paper: who and what period it covers, the totals by
         person and year and by medication, and every fill with its receipt details. A print
         stylesheet hides the navigation.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.
--?>

<?= render('_nav', { section = section }) ?>
<p class="pv-actions"><a href="<?= back ?>">Back to Reports</a></p>
<h1>Medication spending report</h1>
<dl class="meds-report-facts">
  <dt>For</dt><dd><?= covers ?></dd>
  <dt>Period</dt><dd><?= period ?></dd>
  <? for _, words in ipairs(narrowed_by) do ?><dt>Only</dt><dd><?= words ?></dd><? end ?>
  <dt>Printed</dt><dd><?= fmt.date(today) ?></dd>
  <dt>Total paid</dt><dd><?= render('_money', { amount = total.amount_paid, missing = 'not given' }) ?> for <?= total.counted ?></dd>
</dl>
<p class="pv-actions">
  <? -- forms.js shows the button and prints; without scripts the browser's own command works. ?>
  <button type="button" class="pv-btn pv-btn-primary" data-print hidden><?= icon('printer') ?> Print</button>
  <span class="pv-help">You can also use the Print command of your browser.</span>
</p>
<p class="pv-help">An FSA or HSA may also ask for the receipts from the pharmacy.</p>

<? if total.fills == 0 then ?>
  <p class="pv-empty">No fills found.</p>
<? else ?>
  <h2>Totals by person and year</h2>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Total paid by each person in each year</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Year</th>
      <th scope="col" role="columnheader">Person</th>
      <th scope="col" role="columnheader">Fills</th>
      <th scope="col" role="columnheader">Total paid</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, row in ipairs(spending) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Year</span><?= row.year ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Person</span><?= row.person_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Fills</span><?= row.fills ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Total paid</span><?= render('_money', { amount = row.amount_paid }) ?></td>
      </tr>
    <? end ?>
    </tbody>
  </table>

  <h2>Totals by medication</h2>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Total paid for each medication</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Medication</th>
      <th scope="col" role="columnheader">Person</th>
      <th scope="col" role="columnheader">Fills</th>
      <th scope="col" role="columnheader">Total paid</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, row in ipairs(medications) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span><?= row.medication_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Person</span><?= row.person_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Fills</span><?= row.fills ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Total paid</span><?= render('_money', { amount = row.amount_paid }) ?></td>
      </tr>
    <? end ?>
    </tbody>
  </table>

  <? for _, person in ipairs(people) do ?>
    <section class="meds-report-person">
      <h2>Fills for <?= person.person_name ?></h2>
      <table class="pv-records meds-report-fills" role="table">
        <caption class="pv-visually-hidden">Fills for <?= person.person_name ?>, oldest first</caption>
        <thead role="rowgroup"><tr role="row">
          <th scope="col" role="columnheader">Date</th>
          <th scope="col" role="columnheader">Medication</th>
          <th scope="col" role="columnheader">Rx number</th>
          <th scope="col" role="columnheader">Pharmacy</th>
          <th scope="col" role="columnheader">Quantity</th>
          <th scope="col" role="columnheader">Days supply</th>
          <th scope="col" role="columnheader">Claim number</th>
          <th scope="col" role="columnheader">You paid</th>
        </tr></thead>
        <tbody role="rowgroup">
        <? for _, fill in ipairs(person.fills_list) do ?>
          <tr role="row">
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">Date</span><?= fmt.date(fill.filled_on) ?></td>
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span><?= fill.medication_name ?>
              <? if fill.product_name and fill.product_name ~= fill.medication_name then ?><span class="pv-meta meds-line"><?= fill.product_name ?></span><? end ?>
              <? if fill.prescriber_name then ?><span class="pv-meta meds-line">Prescribed by <?= fill.prescriber_name ?></span><? end ?></td>
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">Rx number</span><?= fill.rx_number or 'Not given' ?></td>
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">Pharmacy</span><?= fill.pharmacy_name ?></td>
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">Quantity</span><?= fill.quantity or 'Not given' ?></td>
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">Days supply</span><?= fill.days_supply or 'Not given' ?></td>
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">Claim number</span><?= fill.insurance_claim_number or 'Not given' ?></td>
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">You paid</span><?= render('_money', { amount = fill.amount_paid }) ?></td>
          </tr>
        <? end ?>
        </tbody>
        <tfoot role="rowgroup">
          <tr role="row">
            <th scope="row" role="rowheader" colspan="7">Total for <?= person.person_name ?>, <?= person.counted ?></th>
            <td role="cell"><span class="pv-cell-label" aria-hidden="true">Total paid</span><?= render('_money', { amount = person.amount_paid, missing = 'Not given' }) ?></td>
          </tr>
        </tfoot>
      </table>
    </section>
  <? end ?>
<? end ?>
