<?--
This file is part of Prescription Tracker
apps/meds/views/index.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-10-03
Summary: The home page of a household with no people yet. Greets it and invites it to add
         the first person.
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
<div class="meds">
<p class="meds-mark"><?= icon('capsule') ?></p>
<h1>Welcome to your prescription tracker.</h1>
<p><?= greeting ?>. Add the first person to begin.</p>
<a class="pv-btn pv-btn-primary" href="<?= url('/setup/people/new') ?>">
  <?= icon('plus-lg') ?> Add a person
</a>
</div>
