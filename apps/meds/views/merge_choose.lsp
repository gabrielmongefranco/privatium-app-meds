<?--
This file is part of Prescription Tracker
apps/meds/views/merge_choose.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The first page of a merge: choose the medication that stays.
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
<p><a href="<?= url('/setup/catalog/' .. source.medication_id) ?>">Back to <?= source.short_name ?></a></p>
<h1>Merge a medication</h1>

<p>Merge two entries of the catalog when both are the same product under different names.
   <strong><?= source.short_name ?></strong> will go away. Choose the medication that stays.</p>

<form method="get" action="<?= url('/setup/catalog/' .. source.medication_id .. '/merge') ?>" role="search" class="meds-search">
  <label for="q">Find the medication that stays</label>
  <input id="q" name="q" type="search" value="<?= filter ?>" maxlength="100" autocomplete="off">
  <button type="submit" class="pv-btn"><?= icon('search') ?> Find</button>
</form>

<? if #candidates == 0 then ?>
  <p class="pv-empty">No other medication answers to "<?= filter ?>".</p>
<? else ?>
  <ul class="meds-cards">
    <? for _, medication in ipairs(candidates) do ?>
      <li class="pv-card">
        <h2><?= medication.short_name ?></h2>
        <p class="pv-meta"><?= medication.full_name ?></p>
        <p class="pv-actions">
          <a class="pv-btn" href="<?= url('/setup/catalog/' .. source.medication_id .. '/merge/' .. medication.medication_id) ?>">Keep this one<span class="pv-visually-hidden">: <?= medication.short_name ?></span></a>
        </p>
      </li>
    <? end ?>
  </ul>
<? end ?>
