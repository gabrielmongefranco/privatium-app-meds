<?--
This file is part of Prescription Tracker
apps/meds/views/history.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-05
Summary: The Fill history tab: every fill under the filters, newest first, with the
         number of fills and the total paid. Each note sits on a row of its own.
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
<div class="meds-tab-row">
  <?= render('_history_tabs', { tabs = tabs }) ?>
  <?= render('_people_filter', { filter = filter, base = '/fills', keep = keep }) ?>
</div>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/fills/new' .. (filter.id ~= '' and ('?person=' .. filter.id) or '')) ?>"><?= icon('plus-lg') ?> Record a fill</a>
  <a class="pv-btn" href="<?= url('/fills/paste') ?>"><?= icon('clipboard-plus') ?> Copy refill history from patient portal</a>
</p>

<?= render('_history_filters', { chosen = chosen, path = '/fills', is_narrowed = is_narrowed, live = true }) ?>

<h2>Fills</h2>
<? -- The script's count says "on this page" while other pages hold fills it cannot see. ?>
<p class="pv-meta" role="status" data-filter-status data-filter-noun="fill|fills"<? if pages > 1 then ?> data-filter-paged<? end ?>></p>
<? if #rows == 0 then ?>
  <p class="pv-empty">No fills found.</p>
<? else ?>
  <p class="pv-meta"><?= counted ?>. Total paid: <?= render('_money', { amount = total.amount_paid, missing = 'not given' }) ?>.
    <? if pages > 1 then ?>Page <?= chosen.page ?> of <?= pages ?>.<? end ?></p>
  <? -- One row group per fill, so its note can sit on a row of its own under it. ?>
  <table class="pv-records meds-fills" role="table">
    <caption class="pv-visually-hidden">Fills, newest first</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Date</th>
      <th scope="col" role="columnheader">Medication</th>
      <th scope="col" role="columnheader">Person</th>
      <th scope="col" role="columnheader">Pharmacy</th>
      <th scope="col" role="columnheader">Quantity</th>
      <th scope="col" role="columnheader">Days supply</th>
      <th scope="col" role="columnheader">You paid</th>
      <th scope="col" role="columnheader">Action</th>
    </tr></thead>
    <? for _, row in ipairs(rows) do ?>
    <tbody role="rowgroup" data-search-group>
      <tr role="row" data-search="<?= row.search_key ?>">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Date</span><?= fmt.date(row.filled_on) ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span><?= render('_form_icon', { icon_name = row.form_icon, label = row.form_label }) ?> <?= row.medication_name ?>
          <? if row.product_name and row.product_name ~= row.medication_name then ?><span class="pv-meta meds-line"><?= row.product_name ?></span><? end ?>
          <? if row.rx_number then ?><span class="pv-meta meds-line">Rx <?= row.rx_number ?></span><? end ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Person</span><?= row.person_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Pharmacy</span><?= row.pharmacy_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Quantity</span><?= row.quantity or 'Not given' ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Days supply</span><?= row.days_supply or 'Not given' ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">You paid</span><?= render('_money', { amount = row.amount_paid }) ?></td>
        <td role="cell"><a class="pv-btn" href="<?= url('/fills/' .. row.id .. '/edit') ?>"><?= icon('pencil') ?> Change<span class="pv-visually-hidden"> the fill of <?= row.filled_on ?>, <?= row.medication_name ?></span></a></td>
      </tr>
      <? if row.notes then ?>
      <tr role="row" class="meds-note-row">
        <td role="cell" colspan="8" class="meds-notes-text"><span class="pv-visually-hidden">The fill of <?= row.filled_on ?>, <?= row.medication_name ?>. </span>Note: <?= row.notes ?></td>
      </tr>
      <? end ?>
    </tbody>
    <? end ?>
  </table>
  <? if pages > 1 then ?>
    <nav aria-label="Pages of fills">
      <p class="pv-actions">
        <? if newer then ?><a class="pv-btn" href="<?= newer ?>">Newer fills</a><? end ?>
        <? if older then ?><a class="pv-btn" href="<?= older ?>">Older fills</a><? end ?>
      </p>
    </nav>
  <? end ?>
<? end ?>
