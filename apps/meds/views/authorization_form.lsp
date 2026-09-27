<?--
This file is part of Prescription Tracker
apps/meds/views/authorization_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The form that adds or changes a prior authorization.
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
  <?= render('_select_or_new', { name = 'person_id', legend = 'Who is it for', noun = 'person',
        value = typed.person_id, typed_new = typed.person_id_new, options = people, required = true,
        err = errors.person_id, empty_label = 'Choose a person' }) ?>
  <?= render('_medication_names', { names = names }) ?>
  <?= render('_medication_picker', { prefix = 'medication', typed = typed, options = in_use, pick = pick,
          err = errors.medication_id }) ?>
  <p class="pv-help">If the medication is not on the list of the person yet, saving adds it, with the status Not started.</p>
  <?= render('_field', { name = 'valid_to', label = 'Last day', value = typed.valid_to,
        err = errors.valid_to, required = true, input_type = 'date',
        help = 'The last day the approval covers. The letter from the insurer shows it.' }) ?>
  <?= render('_field', { name = 'valid_from', label = 'First day', value = typed.valid_from,
        err = errors.valid_from, input_type = 'date',
        help = 'Leave it empty if you do not know it.' }) ?>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/authorizations') ?>">Cancel</a>
  </p>
</form>
