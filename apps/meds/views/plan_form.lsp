<?--
This file is part of Prescription Tracker
apps/meds/views/plan_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-01
Last Modified: 2026-10-05
Summary: The form for a payer and its refill rules.
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
<h1><?= heading ?></h1>
<?= render('_problems', { problems = problems }) ?>
<form method="post" action="<?= action ?>" novalidate>
  <?= csrf() ?>
  <?= render('_field', { name = 'name', label = 'Plan name', value = typed.name,
        err = errors.name, required = true, maxlength = 120,
        help = 'A name you recognize. Do not enter member numbers or other personal details.' }) ?>
  <?= render('_field', { name = 'early_fill_percent', label = 'Early fill percent', value = typed.early_fill_percent,
        err = errors.early_fill_percent, inputmode = 'numeric', maxlength = 3,
        help = 'From 0 to 100. Empty uses the household setting. At 25 percent, 30 days allows 7 days early and 90 allows 22. Use 0 for cash or over-the-counter purchases to wait until supply runs out.' }) ?>
  <?= render('_field', { name = 'supply_frame_days', label = 'Supply frame, in days', value = typed.supply_frame_days,
        err = errors.supply_frame_days, inputmode = 'numeric', maxlength = 4,
        help = 'Empty uses the household setting, 180 days by default. Fills this many days old still count on the next fill date. Use 0 for the last fill only, or 3650 for every fill.' }) ?>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/setup/plans') ?>">Cancel</a>
  </p>
</form>
