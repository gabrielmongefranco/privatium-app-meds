<?--
This file is part of Prescription Tracker
apps/meds/views/medications.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-05
Summary: What each person tracks, grouped by status, with a search box that narrows the
         list by any name, the prescriber or the person.
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

<? if filter.selected then menu('Print list', '/people/' .. filter.id .. '/medication-list', 'printer') end ?>
<?= render('_nav', { section = section }) ?>
<h1>Medications</h1>
<?= render('_notice', { notice = notice }) ?>
<?= render('_people_filter', { filter = filter, base = '/medications' }) ?>

<div class="meds-toolbar">
  <p class="pv-actions">
    <a class="pv-btn pv-btn-primary" href="<?= url('/medications/new' .. (filter.id ~= '' and ('?person=' .. filter.id) or '')) ?>"><?= icon('plus-lg') ?> Track a new medication</a>
  </p>
  <form method="get" action="<?= url('/medications') ?>" role="search" class="meds-search">
    <? if filter.id ~= '' then ?><input type="hidden" name="person" value="<?= filter.id ?>"><? end ?>
    <div>
      <label for="q">Search the list</label>
      <input id="q" name="q" type="search" value="<?= filter_text ?>" maxlength="100" autocomplete="off"
             data-filter-input>
    </div>
    <button type="submit" class="pv-btn"><?= icon('search') ?> Find</button>
    <? if filter_text ~= '' then ?>
      <a class="pv-btn" href="<?= url('/medications' .. (filter.id ~= '' and ('?person=' .. filter.id) or '')) ?>">Show all</a>
    <? end ?>
  </form>
</div>
<p class="pv-meta" role="status" data-filter-status><?= matched ?></p>
<? if filter.selected then ?>
  <p class="pv-help">To print this list, open the menu in the top bar and choose Print list.</p>
<? elseif #filter.people > 0 then ?>
  <p class="pv-help">Choose one person to print their list from the menu in the top bar.</p>
<? end ?>

<? local shown = 0 ?>
<? for _, group in ipairs(groups) do ?>
  <? if #group.rows > 0 then ?>
    <? shown = shown + #group.rows ?>
    <section data-filter-group>
      <h2><?= group.title ?></h2>
      <?= render('_entries_table', { rows = group.rows, caption = 'Medications with the status ' .. group.title }) ?>
    </section>
  <? end ?>
<? end ?>
<? if shown == 0 and #stopped.rows == 0 then ?>
  <? if filter_text ~= '' then ?>
    <p class="pv-empty">No medications found.</p>
  <? else ?>
    <p class="pv-empty">No medications yet. Choose Track a new medication to begin.</p>
  <? end ?>
<? end ?>

<? if #stopped.rows > 0 then ?>
  <details data-filter-group<? if stopped_open then ?> open<? end ?>>
    <summary>No longer taking (<?= #stopped.rows ?>)</summary>
    <?= render('_entries_table', { rows = stopped.rows, caption = 'Medications no longer taken' }) ?>
  </details>
<? end ?>
