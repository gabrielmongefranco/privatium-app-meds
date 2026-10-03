<?--
This file is part of Prescription Tracker
apps/meds/views/history.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
Summary: The history of fills, with filters, the total paid under the filters, and the total
         paid by each person in each year.
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
<h1>History</h1>
<?= render('_notice', { notice = notice }) ?>
<?= render('_people_filter', { filter = filter, base = '/fills' }) ?>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/fills/new' .. (filter.id ~= '' and ('?person=' .. filter.id) or '')) ?>"><?= icon('plus-lg') ?> Record a fill</a>
  <a class="pv-btn" href="<?= url('/fills/paste') ?>"><?= icon('clipboard-plus') ?> Copy refill history from patient portal</a>
</p>

<form method="get" action="<?= url('/fills') ?>" class="meds-filters">
  <input type="hidden" name="person" value="<?= filter.id ?>">
  <?= render('_select', { name = 'medication', label = 'Medication', value = chosen.medication,
        options = medications, empty_label = 'Every medication', required = true }) ?>
  <?= render('_select', { name = 'pharmacy', label = 'Pharmacy', value = chosen.pharmacy,
        options = pharmacies, empty_label = 'Every pharmacy', required = true }) ?>
  <label for="f-year">Year</label>
  <select id="f-year" name="year">
    <option value="">Every year</option>
    <? for _, row in ipairs(years) do ?>
      <option value="<?= row.year ?>"<? if row.year == chosen.year then ?> selected<? end ?>><?= row.year ?></option>
    <? end ?>
  </select>
  <button type="submit" class="pv-btn"><?= icon('funnel') ?> Show</button>
</form>

<h2>Fills</h2>
<? if #rows == 0 then ?>
  <p class="pv-empty">No fill matches.</p>
<? else ?>
  <p class="pv-meta"><?= counted ?>. Total paid: <? if total.amount_paid then ?><?= fmt.money(total.amount_paid) ?><? else ?>not given<? end ?>.
    <? if pages > 1 then ?>Page <?= chosen.page ?> of <?= pages ?>.<? end ?></p>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Fills, newest first</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Date</th>
      <th scope="col" role="columnheader">Medication</th>
      <th scope="col" role="columnheader">For</th>
      <th scope="col" role="columnheader">Pharmacy</th>
      <th scope="col" role="columnheader">Plan</th>
      <th scope="col" role="columnheader">Quantity</th>
      <th scope="col" role="columnheader">Days supply</th>
      <th scope="col" role="columnheader">You paid</th>
      <th scope="col" role="columnheader">Action</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, row in ipairs(rows) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Date</span><?= fmt.date(row.filled_on) ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span><?= render('_form_icon', { icon_name = row.form_icon, label = row.form_label }) ?> <?= row.medication_name ?>
          <? if row.product_name and row.product_name ~= row.medication_name then ?><span class="pv-meta meds-line"><?= row.product_name ?></span><? end ?>
          <? if row.rx_number then ?><span class="pv-meta meds-line">Rx <?= row.rx_number ?></span><? end ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">For</span><?= row.person_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Pharmacy</span><?= row.pharmacy_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Plan</span><?= row.plan_name or 'Not given' ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Quantity</span><?= row.quantity or 'Not given' ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Days supply</span><?= row.days_supply or 'Not given' ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">You paid</span><? if row.amount_paid then ?><?= fmt.money(row.amount_paid) ?><? else ?>Not given<? end ?></td>
        <td role="cell"><a class="pv-btn" href="<?= url('/fills/' .. row.id .. '/edit') ?>"><?= icon('pencil') ?> Change<span class="pv-visually-hidden"> the fill of <?= row.filled_on ?>, <?= row.medication_name ?></span></a></td>
      </tr>
    <? end ?>
    </tbody>
  </table>
  <? if pages > 1 then ?>
    <? local base = '/fills?person=' .. filter.id .. '&medication=' .. chosen.medication .. '&pharmacy=' .. chosen.pharmacy .. '&year=' .. chosen.year .. '&page=' ?>
    <nav aria-label="Pages of fills">
      <p class="pv-actions">
        <? if chosen.page > 1 then ?><a class="pv-btn" href="<?= url(base .. (chosen.page - 1)) ?>">Newer fills</a><? end ?>
        <? if chosen.page < pages then ?><a class="pv-btn" href="<?= url(base .. (chosen.page + 1)) ?>">Older fills</a><? end ?>
      </p>
    </nav>
  <? end ?>
<? end ?>

<h2>Paid by year</h2>
<? if #spending == 0 then ?>
  <p class="pv-empty">No fill is recorded.</p>
<? else ?>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Total paid by each person in each year</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Year</th>
      <th scope="col" role="columnheader">For</th>
      <th scope="col" role="columnheader">Fills</th>
      <th scope="col" role="columnheader">Total paid</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, row in ipairs(spending) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Year</span><?= row.year ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">For</span><?= row.person_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Fills</span><?= row.fills ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Total paid</span><? if row.amount_paid then ?><?= fmt.money(row.amount_paid) ?><? else ?>Not given<? end ?></td>
      </tr>
    <? end ?>
    </tbody>
  </table>
<? end ?>
