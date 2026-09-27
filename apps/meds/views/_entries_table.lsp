<?--
This file is part of Prescription Tracker
apps/meds/views/_entries_table.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: A table of entries of medication lists, one row for each medication of each person.
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
  <caption class="pv-visually-hidden"><?= caption ?></caption>
  <thead role="rowgroup">
    <tr role="row">
      <th scope="col" role="columnheader">Medication</th>
      <th scope="col" role="columnheader">For</th>
      <th scope="col" role="columnheader">How to take it</th>
      <th scope="col" role="columnheader">Prescriber</th>
      <th scope="col" role="columnheader">Refill</th>
    </tr>
  </thead>
  <tbody role="rowgroup">
  <? for _, row in ipairs(rows) do ?>
    <tr role="row">
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span>
        <a href="<?= url('/medications/' .. row.id) ?>"><?= row.medication_name ?></a>
        <? if row.prescribed_for then ?><span class="pv-meta meds-line">For <?= row.prescribed_for ?></span><? end ?></td>
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">For</span><?= row.person_name ?></td>
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">How to take it</span>
        <?= row.instructions or 'Not given' ?>
        <? if row.when_to_take then ?><span class="pv-meta meds-line"><?= row.when_to_take ?></span><? end ?></td>
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">Prescriber</span><?= row.prescriber_name or 'Self-prescribed' ?></td>
      <td role="cell"><span class="pv-cell-label" aria-hidden="true">Refill</span>
        <? if row.status == 'not_taking' then ?>
          <? if row.last_filled_on then ?>Last filled <?= fmt.date(row.last_filled_on) ?><? else ?>No fill recorded<? end ?>
        <? else ?>
          <?= render('_refill_badge', { badge = row.badge, icon_name = row.icon_name, phrase = row.phrase }) ?>
          <? if row.next_fill_on then ?><span class="pv-meta meds-line">Next fill date <?= fmt.date(row.next_fill_on) ?></span><? end ?>
        <? end ?></td>
    </tr>
  <? end ?>
  </tbody>
</table>
