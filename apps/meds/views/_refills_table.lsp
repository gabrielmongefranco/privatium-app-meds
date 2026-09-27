<?--
This file is part of Prescription Tracker
apps/meds/views/_refills_table.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: One group of the Refills page as a table, with a button that records a fill for each row.
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

<table class="pv-records" role="table">
  <caption class="pv-visually-hidden">Medications in the group <?= caption ?>, soonest first</caption>
  <thead role="rowgroup"><tr role="row">
    <th scope="col" role="columnheader">Medication</th>
    <th scope="col" role="columnheader">For</th>
    <th scope="col" role="columnheader">Refill</th>
    <th scope="col" role="columnheader">Last fill</th>
    <th scope="col" role="columnheader">Refills left</th>
    <th scope="col" role="columnheader">Action</th>
  </tr></thead>
  <tbody role="rowgroup">
  <? for _, row in ipairs(rows) do ?>
    <tr role="row">
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span>
        <a href="<?= url('/medications/' .. row.id) ?>"><?= row.medication_name ?></a>
        <? if row.is_specialty then ?><span class="pv-meta meds-line">Specialty</span><? end ?></td>
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">For</span><?= row.person_name ?></td>
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">Refill</span>
        <? if alert then ?>
          <?= render('_refill_badge', { badge = row.badge, icon_name = row.icon_name, phrase = row.phrase }) ?>
        <? else ?>
          <?= row.status_label ?>
        <? end ?>
        <? if row.next_fill_on then ?>
          <span class="pv-meta meds-line">Next fill date <?= fmt.date(row.next_fill_on) ?></span>
          <span class="pv-meta meds-line">Recommended <?= fmt.date(row.recommended_next_fill_on) ?></span>
        <? end ?></td>
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">Last fill</span>
        <? if row.last_filled_on then ?><?= fmt.date(row.last_filled_on) ?><? if row.last_fill_pharmacy_name then ?> at <?= row.last_fill_pharmacy_name ?><? end ?><? if row.last_days_supply then ?>, <?= row.last_days_supply ?> days<? end ?><? else ?>No fill recorded<? end ?></td>
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">Refills left</span>
        <? if row.refills_left == 0 and alert then ?>
          None. Ask <?= row.prescriber_name or 'the prescriber' ?> for a new prescription<? if row.prescriber_href then ?>: <a href="tel:<?= row.prescriber_href ?>"><?= row.prescriber_phone ?></a><? else ?>.<? end ?>
        <? else ?>
          <?= row.refills_left ?>
        <? end ?></td>
      <td role="cell"><a class="pv-btn" href="<?= url('/fills/new?entry=' .. row.id) ?>">Record fill<span class="pv-visually-hidden"> for <?= row.medication_name ?>, <?= row.person_name ?></span></a></td>
    </tr>
  <? end ?>
  </tbody>
</table>
