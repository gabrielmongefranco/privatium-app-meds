<?--
This file is part of Prescription Tracker
apps/meds/views/reminders.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
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

<p>Each number is a day count or a percent. Leave a field empty to use the number the app starts with.</p>

<form method="post" action="<?= url('/setup/reminders') ?>" novalidate>
  <?= csrf() ?>
  <fieldset>
    <legend>Refills</legend>
    <?= render('_field', { name = 'due_within_days', label = 'Due, in days', value = typed.due_within_days,
          err = errors.due_within_days, inputmode = 'numeric', maxlength = 3,
          help = 'A refill is due when its next fill date is this many days away or fewer. Empty means ' .. defaults.due_within_days .. '.' }) ?>
    <?= render('_field', { name = 'due_soon_within_days', label = 'Due soon, in days', value = typed.due_soon_within_days,
          err = errors.due_soon_within_days, inputmode = 'numeric', maxlength = 3,
          help = 'A refill is due soon when its next fill date is this many days away or fewer. Empty means ' .. defaults.due_soon_within_days .. '.' }) ?>
  </fieldset>
  <fieldset>
    <legend>Refills of a specialty medication</legend>
    <?= render('_field', { name = 'specialty_due_within_days', label = 'Due, in days', value = typed.specialty_due_within_days,
          err = errors.specialty_due_within_days, inputmode = 'numeric', maxlength = 3,
          help = 'Empty means ' .. defaults.specialty_due_within_days .. '.' }) ?>
    <?= render('_field', { name = 'specialty_due_soon_within_days', label = 'Due soon, in days', value = typed.specialty_due_soon_within_days,
          err = errors.specialty_due_soon_within_days, inputmode = 'numeric', maxlength = 3,
          help = 'Empty means ' .. defaults.specialty_due_soon_within_days .. '.' }) ?>
  </fieldset>
  <fieldset>
    <legend>Prior authorizations</legend>
    <?= render('_field', { name = 'authorization_due_within_days', label = 'Due, in days', value = typed.authorization_due_within_days,
          err = errors.authorization_due_within_days, inputmode = 'numeric', maxlength = 3,
          help = 'A prior authorization is due when it expires in this many days or fewer. Ask for a new one by then. Empty means ' .. defaults.authorization_due_within_days .. '.' }) ?>
    <?= render('_field', { name = 'authorization_notice_days', label = 'Due soon, in days', value = typed.authorization_notice_days,
          err = errors.authorization_notice_days, inputmode = 'numeric', maxlength = 3,
          help = 'A prior authorization is due soon when it expires in this many days or fewer. Empty means ' .. defaults.authorization_notice_days .. '.' }) ?>
  </fieldset>

  <fieldset>
    <legend>Early refills</legend>
    <?= render('_field', { name = 'early_fill_percent', label = 'Early fill percent', value = typed.early_fill_percent,
          err = errors.early_fill_percent, inputmode = 'numeric', maxlength = 3,
          help = 'From 0 to 100. Plans can override this. Empty means ' .. defaults.early_fill_percent .. '.' }) ?>
    <?= render('_field', { name = 'supply_frame_days', label = 'Supply frame, in days', value = typed.supply_frame_days,
          err = errors.supply_frame_days, inputmode = 'numeric', maxlength = 4,
          help = 'Fills within this many days count toward the next fill date. Use 0 to count the last fill only, or 3650 to count every fill. Empty means ' .. defaults.supply_frame_days .. '.' }) ?>
    <?= render('_field', { name = 'controlled_early_days', label = 'Days early for controlled medications', value = typed.controlled_early_days,
          err = errors.controlled_early_days, inputmode = 'numeric', maxlength = 3,
          help = 'How many days early a controlled medication may be refilled. Empty means ' .. defaults.controlled_early_days .. '.' }) ?>
  </fieldset>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/setup') ?>">Cancel</a>
  </p>
</form>
