<?--
This file is part of Prescription Tracker
apps/meds/views/catalog.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The medication catalog, with a search that finds a medication by any of its names,
         offers close matches as questions, and can learn a new name.
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
<p><a href="<?= url('/setup') ?>">Back to Setup</a></p>
<h1>Medication catalog</h1>
<?= render('_notice', { notice = notice }) ?>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/setup/catalog/new') ?>"><?= icon('plus-lg') ?> Add a medication</a>
</p>

<form method="get" action="<?= url('/setup/catalog') ?>" role="search" class="meds-search">
  <label for="q">Find a medication by any of its names</label>
  <input id="q" name="q" type="search" value="<?= filter ?>" maxlength="100" autocomplete="off">
  <button type="submit" class="pv-btn"><?= icon('search') ?> Find</button>
  <? if filter ~= '' then ?>
    <a class="pv-btn" href="<?= url('/setup/catalog') ?>">Show all</a>
  <? end ?>
</form>

<? if #medications == 0 and filter == '' then ?>
  <p class="pv-empty">The catalog is empty. Add the first medication to begin.</p>
<? elseif #medications == 0 then ?>
  <p class="pv-empty">No medication answers to "<?= filter ?>".</p>
<? else ?>
  <p class="pv-meta"><?= found ?><? if filter ~= '' then ?> answer to "<?= filter ?>"<? end ?>.</p>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Medications in the catalog, by short name</caption>
    <thead role="rowgroup">
      <tr role="row">
        <th scope="col" role="columnheader">Medication</th>
        <th scope="col" role="columnheader">Full name</th>
        <th scope="col" role="columnheader">Specialty</th>
      </tr>
    </thead>
    <tbody role="rowgroup">
    <? for _, medication in ipairs(medications) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span>
          <a href="<?= url('/setup/catalog/' .. medication.medication_id) ?>"><?= medication.short_name ?></a></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Full name</span><?= medication.full_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Specialty</span>
          <? if medication.is_specialty then ?><span class="pv-badge pv-badge-muted"><?= icon('truck') ?> Specialty</span><? else ?>No<? end ?></td>
      </tr>
    <? end ?>
    </tbody>
  </table>
<? end ?>

<? if #close > 0 then ?>
  <h2>Did you mean one of these?</h2>
  <p>These names are close to "<?= filter ?>", and none is the same. Different medications
     can have names that look alike, so check the name before you choose.</p>
  <ul class="meds-cards">
    <? for _, medication in ipairs(close) do ?>
      <li class="pv-card">
        <h3><a href="<?= url('/setup/catalog/' .. medication.medication_id) ?>"><?= medication.short_name ?></a></h3>
        <p class="pv-meta">Close to its name "<?= medication.matched_name ?>".</p>
      </li>
    <? end ?>
  </ul>
<? end ?>

<? if filter ~= '' and not exact and (#medications > 0 or #close > 0) then ?>
  <h2>Teach the app this name</h2>
  <p>If "<?= filter ?>" is another name for one of these medications, choose it. The
     search will find the medication by that name from then on.</p>
  <? for _, group in ipairs({ medications, close }) do ?>
    <? for _, medication in ipairs(group) do ?>
      <form method="post" action="<?= url('/setup/catalog/' .. medication.medication_id .. '/names') ?>" class="meds-teach">
        <?= csrf() ?>
        <input type="hidden" name="alias" value="<?= filter ?>">
        <button type="submit" class="pv-btn">"<?= filter ?>" is <?= medication.short_name ?></button>
      </form>
    <? end ?>
  <? end ?>
<? end ?>
