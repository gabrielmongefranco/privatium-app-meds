<?--
This file is part of Prescription Tracker
apps/meds/views/medication_list.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The medication list of one person, made for paper: what the person takes now and
         how. A print stylesheet hides the navigation.
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
<p class="pv-actions"><a href="<?= url('/medications?person=' .. person.id) ?>">Back to the medications of <?= person.display_name ?></a></p>
<h1>Medication list for <?= person.display_name ?></h1>
<p><? if person.birth_date then ?>Born <?= fmt.date(person.birth_date) ?>. <? end ?>Printed <?= fmt.date(today) ?>.</p>
<p class="pv-help pv-actions">To print this page, use the print command of your browser.</p>

<? if #taking == 0 then ?>
  <p class="pv-empty">No medication is in use.</p>
<? else ?>
  <table role="table">
    <caption class="pv-visually-hidden">Medications in use</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Medication</th>
      <th scope="col" role="columnheader">How to take it</th>
      <th scope="col" role="columnheader">When</th>
      <th scope="col" role="columnheader">What it is for</th>
      <th scope="col" role="columnheader">Prescriber</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, row in ipairs(taking) do ?>
      <tr role="row">
        <td role="cell"><?= row.medication_name ?><? if row.status == 'taking_as_needed' then ?> (as needed)<? end ?></td>
        <td role="cell"><?= row.instructions ?></td>
        <td role="cell"><?= row.when_to_take ?></td>
        <td role="cell"><?= row.prescribed_for ?></td>
        <td role="cell"><?= row.prescriber_name or 'Self-prescribed' ?></td>
      </tr>
    <? end ?>
    </tbody>
  </table>
<? end ?>

<? if #on_hold > 0 then ?>
  <h2>On hold</h2>
  <table role="table">
    <caption class="pv-visually-hidden">Medications on hold</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Medication</th>
      <th scope="col" role="columnheader">What it is for</th>
      <th scope="col" role="columnheader">Prescriber</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, row in ipairs(on_hold) do ?>
      <tr role="row">
        <td role="cell"><?= row.medication_name ?></td>
        <td role="cell"><?= row.prescribed_for ?></td>
        <td role="cell"><?= row.prescriber_name or 'Self-prescribed' ?></td>
      </tr>
    <? end ?>
    </tbody>
  </table>
<? end ?>
