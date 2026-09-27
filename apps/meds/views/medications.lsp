<?--
This file is part of Prescription Tracker
apps/meds/views/medications.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: What each person takes, grouped by status.
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
<h1>Medications</h1>
<?= render('_notice', { notice = notice }) ?>
<?= render('_people_filter', { filter = filter, base = '/medications' }) ?>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/medications/new' .. (filter.id ~= '' and ('?person=' .. filter.id) or '')) ?>"><?= icon('plus-lg') ?> Add a medication</a>
  <? if filter.selected then ?>
    <a class="pv-btn" href="<?= url('/people/' .. filter.id .. '/medication-list') ?>"><?= icon('printer') ?> Print list</a>
  <? end ?>
</p>
<? if not filter.selected and #filter.people > 0 then ?>
  <p class="pv-help">Choose one person to print their list.</p>
<? end ?>

<? local shown = 0 ?>
<? for _, group in ipairs(groups) do ?>
  <? if #group.rows > 0 then ?>
    <? shown = shown + #group.rows ?>
    <h2><?= group.title ?></h2>
    <?= render('_entries_table', { rows = group.rows, caption = 'Medications with the status ' .. group.title }) ?>
  <? end ?>
<? end ?>
<? if shown == 0 then ?>
  <p class="pv-empty">No medication is in use yet. Add the first one to begin.</p>
<? end ?>

<? if #stopped.rows > 0 then ?>
  <details>
    <summary>No longer taking (<?= #stopped.rows ?>)</summary>
    <?= render('_entries_table', { rows = stopped.rows, caption = 'Medications no longer taken' }) ?>
  </details>
<? end ?>
