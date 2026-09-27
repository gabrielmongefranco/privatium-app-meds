<?--
This file is part of Prescription Tracker
apps/meds/views/edit.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-09-26
Summary: The name form. One field, one POST, and the csrf() token every non-GET form needs.
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

<link rel="stylesheet" href="<?= url('/static/meds.css') ?>">
<div class="meds">
<h1>What should the app call your household?</h1>

<? if err then ?>
  <p class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
<? end ?>

<form method="post" action="<?= url('/name') ?>">
  <?= csrf() ?>
  <label for="display_name">Household name</label>
  <input id="display_name" name="display_name" type="text" maxlength="60" required autofocus
         autocomplete="off" aria-describedby="name-help" value="<?= me and me.display_name or '' ?>">
  <p id="name-help" class="pv-help">A family name or a nickname. You can change it whenever you like.</p>

  <button type="submit" class="pv-btn pv-btn-primary">Save</button>
  <a class="pv-btn" href="<?= url('/') ?>">Cancel</a>
</form>
</div>
