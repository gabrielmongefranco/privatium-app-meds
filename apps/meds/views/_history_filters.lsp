<?--
This file is part of Medication Tracker
apps/meds/views/_history_filters.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: The search box and drop-downs that narrow the fills on the History tabs.
         Parameters: chosen (from history_filter.read), path (the page the form asks),
         is_narrowed, and live (true when the box narrows the rows on the page while typing).
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

<form method="get" action="<?= url(path) ?>" role="search" class="meds-history-filters">
  <? if chosen.person ~= '' then ?><input type="hidden" name="person" value="<?= chosen.person ?>"><? end ?>
  <div class="meds-history-search">
    <label for="q">Search the list</label>
    <input id="q" name="q" type="search" value="<?= chosen.q ?>" maxlength="100" autocomplete="off"<? if live then ?> data-filter-input<? end ?>>
  </div>
  <div>
    <?= render('_select', { name = 'medication', label = 'Medication', value = chosen.medication,
          options = chosen.medications, empty_label = 'Every medication', optional_mark = false }) ?>
  </div>
  <div>
    <?= render('_select', { name = 'pharmacy', label = 'Pharmacy', value = chosen.pharmacy,
          options = chosen.pharmacies, empty_label = 'Every pharmacy', optional_mark = false }) ?>
  </div>
  <div>
    <?= render('_select', { name = 'period', label = 'Time period', value = chosen.period,
          options = chosen.periods, empty_label = 'Any time', optional_mark = false }) ?>
  </div>
  <p class="pv-actions">
    <button type="submit" class="pv-btn"><?= icon('search') ?> Find</button>
    <? if is_narrowed then ?>
      <a class="pv-btn" href="<?= url(path .. (chosen.person ~= '' and ('?person=' .. chosen.person) or '')) ?>">Show all</a>
    <? end ?>
  </p>
</form>
