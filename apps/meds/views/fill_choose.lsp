<?--
This file is part of Prescription Tracker
apps/meds/views/fill_choose.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The first page of recording a fill that starts from no list entry: find the medication.
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
<h1>Record a fill</h1>
<p>First find the medication. The search looks through every name of a medication.</p>

<form method="get" action="<?= url('/fills/new') ?>" role="search" class="meds-search">
  <input type="hidden" name="person" value="<?= person ?>">
  <label for="q">Name of the medication</label>
  <input id="q" name="q" type="search" value="<?= filter ?>" maxlength="100" autocomplete="off" autofocus>
  <button type="submit" class="pv-btn pv-btn-primary"><?= icon('search') ?> Find</button>
</form>

<?= render('_pick_medication', { filter = filter, found = found,
      base = '/fills/new?person=' .. person .. '&medication=' }) ?>

<p><a href="<?= url('/setup/catalog/new') ?>">Add a new medication to the catalog</a></p>
