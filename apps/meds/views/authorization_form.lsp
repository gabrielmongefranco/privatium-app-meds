<?--
This file is part of Prescription Tracker
apps/meds/views/authorization_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-04
Summary: The form that adds a prior authorization for a tracked medication, or changes one.
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
  <? if entry then ?>
    <div class="pv-card"><dl>
      <dt>Medication</dt><dd><?= entry.display_name ?></dd>
      <dt>Person</dt><dd><?= entry.person_name ?></dd>
    </dl></div>
  <? else ?>
    <fieldset class="meds-choice" id="f-entry_id">
      <legend>Medication</legend>
      <label for="f-entry_id-list">Medication</label>
      <select id="f-entry_id-list" name="entry_id"<? if errors.entry_id then ?> aria-invalid="true" aria-describedby="f-entry_id-err"<? end ?>>
        <option value="">Choose a medication</option>
        <option value="<?= new_entry ?>"<? if typed.entry_id == new_entry or typed.medication_q or typed.medication_choice or typed.medication_brand or typed.medication_generic then ?> selected<? end ?>>-- Another medication --</option>
        <? for _, option in ipairs(listed) do ?>
          <option value="<?= option.value ?>"<? if option.value == typed.entry_id then ?> selected<? end ?>><?= option.label ?></option>
        <? end ?>
      </select>
      <? if errors.entry_id then ?>
        <p id="f-entry_id-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= errors.entry_id ?></p>
      <? end ?>
      <? -- With a script, these parts show only after the choice to find or add. Without one, they are always there. ?>
      <div data-show-when="entry_id=<?= new_entry ?>">
        <?= render('_select_or_new', { name = 'person_id', legend = 'Person', noun = 'person',
              value = typed.person_id, typed_new = typed.person_id_new, options = people, required = true,
              err = errors.person_id, empty_label = 'Choose a person' }) ?>
        <?= render('_medication_names', { names = names }) ?>
        <?= render('_product_box', { prefix = 'medication', typed = typed, pick = pick, single = true,
              legend = 'Product', err = errors.medication_id, catalog_options = catalog_options,
              search_url = search_url }) ?>
        <p class="pv-help">If this person does not track this medication yet, it is added to their list as Not started.</p>
      </div>
    </fieldset>
  <? end ?>
  <?= render('_field', { name = 'valid_from', label = 'First day', value = typed.valid_from,
        err = errors.valid_from, input_type = 'date',
        help = 'The form starts with the first day of this month. Clear the field if you do not know the first day.' }) ?>
  <?= render('_field', { name = 'valid_to', label = 'Expiration date', value = typed.valid_to,
        err = errors.valid_to, required = true, input_type = 'date',
        help = 'The last day the approval covers. The form starts with one year after the first day of this month. The letter from the insurer shows the date.' }) ?>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/authorizations') ?>">Cancel</a>
  </p>
</form>
