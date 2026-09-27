<?--
This file is part of Prescription Tracker
apps/meds/views/entry_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The form that adds a medication to the list of a person, or changes one.
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
  <div class="pv-card">
    <dl>
      <dt>Medication</dt><dd><?= medication.short_name ?></dd>
      <? if fixed_person then ?><dt>For</dt><dd><?= fixed_person ?></dd><? end ?>
    </dl>
  </div>
  <input type="hidden" name="medication_id" value="<?= medication.medication_id ?>">
  <? if errors.medication_id then ?>
    <p id="f-medication_id" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= errors.medication_id ?></p>
  <? end ?>

  <? if not fixed_person then ?>
    <?= render('_select', { name = 'person_id', label = 'Who takes it', value = typed.person_id,
          options = offered.people, required = true, err = errors.person_id,
          empty_label = 'Choose a person' }) ?>
  <? end ?>
  <?= render('_select', { name = 'status', label = 'Status', value = typed.status,
        options = offered.statuses, required = true, err = errors.status,
        empty_label = 'Choose a status',
        help = 'Only a medication with the status Taking regularly raises a refill alert.' }) ?>
  <?= render('_field', { name = 'instructions', label = 'How to take it', value = typed.instructions,
        err = errors.instructions, maxlength = 300,
        help = 'As the label says, such as: Take one tablet by mouth every day.' }) ?>
  <?= render('_choice', { name = 'when_to_take', legend = 'When to take it', value = typed.when_to_take,
        typed_new = typed.when_to_take_new, offered = offered.when_to_take, err = errors.when_to_take }) ?>
  <?= render('_field', { name = 'prescribed_for', label = 'What it is for', value = typed.prescribed_for,
        err = errors.prescribed_for, maxlength = 200 }) ?>
  <?= render('_field', { name = 'refills_left', label = 'Refills left', value = typed.refills_left,
        err = errors.refills_left, required = true, inputmode = 'numeric', maxlength = 2,
        help = 'The number on the label. Type 0 when none is left.' }) ?>
  <?= render('_select', { name = 'prescriber_id', label = 'Prescriber', value = typed.prescriber_id,
        options = offered.prescribers, err = errors.prescriber_id,
        empty_label = 'None, self-prescribed' }) ?>
  <?= render('_select', { name = 'pharmacy_id', label = 'Pharmacy used now', value = typed.pharmacy_id,
        options = offered.pharmacies, err = errors.pharmacy_id }) ?>
  <?= render('_choice', { name = 'medication_type', legend = 'Type', value = typed.medication_type,
        typed_new = typed.medication_type_new, offered = offered.medication_type,
        err = errors.medication_type }) ?>

  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/medications') ?>">Cancel</a>
  </p>
</form>
