<?--
This file is part of Prescription Tracker
apps/meds/views/merge_confirm.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The second page of a merge: what will move, and the button that does it.
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
<h1>Merge a medication</h1>

<? if err then ?>
  <p class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
<? end ?>

<div class="pv-card">
  <dl>
    <dt>Goes away</dt><dd><?= source.short_name ?></dd>
    <dt>Stays</dt><dd><?= target.short_name ?></dd>
  </dl>
</div>

<h2>What will happen</h2>
<ul>
  <? for _, change in ipairs(changes) do ?>
    <li><?= change ?></li>
  <? end ?>
  <li><?= source.short_name ?> will be removed from the catalog.</li>
</ul>
<p>A merge cannot be undone in the app. Privatium keeps every original line in its log.
   Merge only when both entries are the same product at the same strength.</p>

<form method="post" action="<?= url('/setup/catalog/' .. source.medication_id .. '/merge/' .. target.medication_id) ?>">
  <?= csrf() ?>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-danger"><?= icon('arrows-collapse') ?> Merge</button>
    <a class="pv-btn" href="<?= url('/setup/catalog/' .. source.medication_id) ?>">Keep both</a>
  </p>
</form>
