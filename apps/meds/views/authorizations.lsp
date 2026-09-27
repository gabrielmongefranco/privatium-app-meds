<?--
This file is part of Prescription Tracker
apps/meds/views/authorizations.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The list of prior authorizations, with the state of each one in words.
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
<h1>Prior authorizations</h1>
<?= render('_notice', { notice = notice }) ?>
<p>A prior authorization is an insurer's approval to cover a medication for a set period.</p>
<?= render('_people_filter', { filter = filter, base = '/authorizations' }) ?>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/authorizations/new') ?>"><?= icon('plus-lg') ?> Add an authorization</a>
</p>

<? if #authorizations == 0 then ?>
  <p class="pv-empty">No prior authorization is recorded.</p>
<? else ?>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Prior authorizations, latest first</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Medication</th>
      <th scope="col" role="columnheader">For</th>
      <th scope="col" role="columnheader">First day</th>
      <th scope="col" role="columnheader">Last day</th>
      <th scope="col" role="columnheader">State</th>
      <th scope="col" role="columnheader">Actions</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, row in ipairs(authorizations) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span><?= row.medication_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">For</span><?= row.person_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">First day</span><?= fmt.date(row.valid_from) ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Last day</span><?= fmt.date(row.valid_to) ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">State</span><?= row.state ?></td>
        <td role="cell" class="meds-row-actions">
          <a class="pv-btn" href="<?= url('/authorizations/' .. row.id .. '/edit') ?>"><?= icon('pencil') ?> Change<span class="pv-visually-hidden"> the authorization of <?= row.medication_name ?></span></a>
          <a class="pv-btn" href="<?= url('/authorizations/' .. row.id .. '/remove') ?>"><?= icon('trash') ?> Remove<span class="pv-visually-hidden"> the authorization of <?= row.medication_name ?></span></a>
        </td>
      </tr>
    <? end ?>
    </tbody>
  </table>
<? end ?>
