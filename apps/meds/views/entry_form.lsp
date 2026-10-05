<?--
This file is part of Prescription Tracker
apps/meds/views/entry_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-05
Summary: The form that adds a medication to the tracking list of a person, or changes one:
         its catalog products, its preferred name, and how it is taken.
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
  <? -- The first submit button answers the Enter key, so Enter saves rather than removing a
     -- product. Buttons are named step for the WebKit reason given in product_pick.lua. ?>
  <button type="submit" class="pv-visually-hidden" name="step" value="save" tabindex="-1">Save</button>
  <? if fixed then ?>
    <div class="pv-card"><dl>
      <dt>Person</dt><dd><?= fixed.person_name ?></dd>
    </dl></div>
  <? else ?>
    <?= render('_select_or_new', { name = 'person_id', legend = 'Who takes it', noun = 'person',
          value = typed.person_id, typed_new = typed.person_id_new, options = offered.people,
          required = true, err = errors.person_id, empty_label = 'Choose a person' }) ?>
  <? end ?>
  <?= render('_medication_names', { names = names }) ?>
  <?= render('_product_picker', { prefix = 'product', typed = typed, chosen = chosen, pick = pick,
        err = errors.products, add_button = add_action, find_button = find_action,
        search_url = search_url, catalog_options = offered.catalog_options }) ?>
  <?= render('_field', { name = 'display_name', label = 'Preferred name', value = typed.display_name,
        err = errors.display_name, required = true, maxlength = 200,
        help = 'The name you call this medication. You can shorten it.' }) ?>
  <?= render('_select', { name = 'status', label = 'Status', value = typed.status,
        options = offered.statuses, required = true, err = errors.status,
        empty_label = 'Choose a status',
        help = 'Only a medication with the status Taking regularly raises a refill alert.' }) ?>
  <?= render('_field', { name = 'instructions', label = 'How to take it', value = typed.instructions,
        err = errors.instructions, maxlength = 300, suggestions = offered.instructions,
        help = 'As the label says, such as: Take one tablet by mouth every day.' }) ?>
  <?= render('_choice', { name = 'when_to_take', legend = 'When to take it', value = typed.when_to_take,
        typed_new = typed.when_to_take_new, offered = offered.when_to_take, err = errors.when_to_take }) ?>
  <?= render('_field', { name = 'prescribed_for', label = 'Reason for taking it', value = typed.prescribed_for,
        err = errors.prescribed_for, maxlength = 200, suggestions = offered.purposes }) ?>
  <?= render('_textarea', { name = 'notes', label = 'Notes', value = typed.notes, err = errors.notes,
        maxlength = 500, help = 'Anything else worth remembering about this medication.' }) ?>
  <?= render('_field', { name = 'refills_left', label = 'Refills left', value = typed.refills_left,
        err = errors.refills_left, required = true, inputmode = 'numeric', maxlength = 2,
        help = 'The number on the label. Type 0 when none is left.' }) ?>
  <?= render('_select_or_new', { name = 'prescriber_id', legend = 'Prescriber', noun = 'prescriber',
        value = typed.prescriber_id, typed_new = typed.prescriber_id_new,
        options = offered.prescribers, err = errors.prescriber_id,
        empty_label = 'None, self-prescribed',
        help = 'Type the name. Saving adds the prescriber, and you can add the clinic and the phone number under Setup, Prescribers.' }) ?>
  <?= render('_select_or_new', { name = 'pharmacy_id', legend = 'Pharmacy used now', noun = 'pharmacy',
        value = typed.pharmacy_id, typed_new = typed.pharmacy_id_new,
        options = offered.pharmacies, err = errors.pharmacy_id,
        help = 'Type the name. Saving adds the pharmacy, and you can add its phone number and address under Setup, Pharmacies.' }) ?>
  <?= render('_choice', { name = 'medication_type', legend = 'Type', value = typed.medication_type,
        typed_new = typed.medication_type_new, offered = offered.medication_type,
        err = errors.medication_type }) ?>

  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary" name="step" value="save"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/medications') ?>">Cancel</a>
  </p>
</form>
