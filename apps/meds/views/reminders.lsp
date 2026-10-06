<?--
This file is part of Medication Tracker
apps/meds/views/reminders.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-05
Summary: The form for the reminder and early refill settings that decide when a refill or a prior authorization
         needs attention.
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
<h1>Reminder settings</h1>
<?= render('_problems', { problems = problems }) ?>

<p>Each box shows the number in use. Clear a box to go back to the number the app starts with.</p>

<form method="post" action="<?= url('/setup/reminders') ?>" novalidate>
  <?= csrf() ?>
  <fieldset>
    <legend>Refills</legend>
    <?= render('_field', { name = 'due_within_days', label = 'Due, in days', value = typed.due_within_days,
          err = errors.due_within_days, inputmode = 'numeric', maxlength = 3, optional_mark = false,
          help = 'A refill is due when its next fill date is this many days away or fewer.' }) ?>
    <?= render('_field', { name = 'due_soon_within_days', label = 'Due soon, in days', value = typed.due_soon_within_days,
          err = errors.due_soon_within_days, inputmode = 'numeric', maxlength = 3, optional_mark = false,
          help = 'A refill is due soon when its next fill date is this many days away or fewer.' }) ?>
  </fieldset>
  <fieldset>
    <legend>Refills of a specialty medication</legend>
    <?= render('_field', { name = 'specialty_due_within_days', label = 'Due, in days', value = typed.specialty_due_within_days,
          err = errors.specialty_due_within_days, inputmode = 'numeric', maxlength = 3, optional_mark = false }) ?>
    <?= render('_field', { name = 'specialty_due_soon_within_days', label = 'Due soon, in days', value = typed.specialty_due_soon_within_days,
          err = errors.specialty_due_soon_within_days, inputmode = 'numeric', maxlength = 3, optional_mark = false }) ?>
  </fieldset>
  <fieldset>
    <legend>Prior authorizations</legend>
    <?= render('_field', { name = 'authorization_due_within_days', label = 'Due, in days', value = typed.authorization_due_within_days,
          err = errors.authorization_due_within_days, inputmode = 'numeric', maxlength = 3, optional_mark = false,
          help = 'A prior authorization is due when it expires in this many days or fewer. Ask for a new one by then.' }) ?>
    <?= render('_field', { name = 'authorization_notice_days', label = 'Due soon, in days', value = typed.authorization_notice_days,
          err = errors.authorization_notice_days, inputmode = 'numeric', maxlength = 3, optional_mark = false }) ?>
  </fieldset>

  <fieldset>
    <legend>Early refills</legend>
    <?= render('_field', { name = 'early_fill_percent', label = 'Early fill percent', value = typed.early_fill_percent,
          err = errors.early_fill_percent, inputmode = 'numeric', maxlength = 3, optional_mark = false,
          help = "How early your insurer allows a refill, as a percent of the last fill's days supply. Plans can override this." }) ?>
    <?= render('_field', { name = 'backup_percent', label = 'Backup supply percent', value = typed.backup_percent,
          err = errors.backup_percent, inputmode = 'numeric', maxlength = 3, optional_mark = false,
          help = "Refill when this share of the last fill's days supply is left, but never before the plan allows." }) ?>
    <?= render('_field', { name = 'backup_min_days', label = 'Backup supply, at least, in days', value = typed.backup_min_days,
          err = errors.backup_min_days, inputmode = 'numeric', maxlength = 3, optional_mark = false }) ?>
    <?= render('_field', { name = 'specialty_backup_min_days', label = 'Backup supply for a specialty medication, at least, in days', value = typed.specialty_backup_min_days,
          err = errors.specialty_backup_min_days, inputmode = 'numeric', maxlength = 3, optional_mark = false }) ?>
    <?= render('_field', { name = 'supply_frame_days', label = 'Supply frame, in days', value = typed.supply_frame_days,
          err = errors.supply_frame_days, inputmode = 'numeric', maxlength = 4, optional_mark = false,
          help = 'Fills within this many days count toward the next fill date. Use 0 to count the last fill only, or 3650 to count every fill.' }) ?>
    <?= render('_field', { name = 'controlled_early_days', label = 'Days early for controlled medications', value = typed.controlled_early_days,
          err = errors.controlled_early_days, inputmode = 'numeric', maxlength = 3, optional_mark = false }) ?>
  </fieldset>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/setup') ?>">Cancel</a>
  </p>
</form>
