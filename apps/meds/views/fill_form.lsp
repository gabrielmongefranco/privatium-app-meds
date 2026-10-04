<?--
This file is part of Prescription Tracker
apps/meds/views/fill_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
Summary: The form that records a fill or changes one. A new fill starts with the values of
         the last fill of the same tracked medication, all of them visible.
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
    <? if #products > 1 then ?>
      <?= render('_select', { name = 'product_id', label = 'Product', value = typed.product_id,
            options = products, err = errors.product_id, empty_label = 'Not given',
            help = 'The package size of this fill.' }) ?>
    <? elseif #products == 1 then ?>
      <input type="hidden" name="product_id" value="<?= products[1].value ?>">
    <? end ?>
  <? else ?>
    <fieldset class="meds-choice" id="f-entry_id">
      <legend>Medication</legend>
      <label for="f-entry_id-list">Medication</label>
      <select id="f-entry_id-list" name="entry_id"<? if errors.entry_id then ?> aria-invalid="true" aria-describedby="f-entry_id-err"<? end ?>>
        <option value="">Choose a medication</option>
        <option value="<?= new_entry ?>"<? if typed.entry_id == new_entry or typed.medication_name or typed.medication_brand or typed.medication_generic or typed.medication_id then ?> selected<? end ?>>-- Another medication --</option>
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
        <?= render('_medication_picker', { prefix = 'medication', typed = typed, pick = pick,
              legend = 'Product', err = errors.medication_id, catalog_options = catalog_options }) ?>
        <p class="pv-help">If this person does not track this medication yet, it is added to their list.</p>
      </div>
    </fieldset>
  <? end ?>
  <?= render('_field', { name = 'filled_on', label = 'Date filled', value = typed.filled_on,
        err = errors.filled_on, required = true, input_type = 'date', max = today,
        help = 'The date on the pharmacy label.' }) ?>
  <?= render('_select_or_new', { name = 'pharmacy_id', legend = 'Pharmacy', noun = 'pharmacy',
        value = typed.pharmacy_id, typed_new = typed.pharmacy_id_new, options = pharmacies,
        required = true, err = errors.pharmacy_id, empty_label = 'Choose a pharmacy',
        help = 'Type the name. Saving adds the pharmacy, and you can add its phone number and address under Contacts.' }) ?>
  <?= render('_field', { name = 'days_supply', label = 'Days supply', value = typed.days_supply,
        err = errors.days_supply, inputmode = 'numeric', maxlength = 3,
        help = 'How many days this fill should last. The pharmacy label shows it.' }) ?>
  <?= render('_field', { name = 'quantity', label = 'Quantity', value = typed.quantity,
        err = errors.quantity, inputmode = 'decimal', maxlength = 20 }) ?>
  <?= render('_field', { name = 'amount_paid', label = 'Amount you paid', value = typed.amount_paid,
        err = errors.amount_paid, inputmode = 'decimal', maxlength = 20,
        help = 'Such as 12.50. A currency sign is fine.' }) ?>
  <? if is_new then ?>
    <?= render('_field', { name = 'refills_left', label = 'Refills left after this fill',
          value = typed.refills_left, err = errors.refills_left,
          inputmode = 'numeric', maxlength = 2,
          help = 'The number on the label. Type 0 when none is left. Leave it empty, and the app lowers the count by one.' }) ?>
  <? end ?>
  <?= render('_field', { name = 'rx_number', label = 'Prescription number', value = typed.rx_number,
        err = errors.rx_number, maxlength = 40,
        help = 'The Rx number on the label. A new prescription has a new number.' }) ?>
  <?= render('_select_or_new', { name = 'plan_id', legend = 'Insurance plan', noun = 'plan',
        value = typed.plan_id, typed_new = typed.plan_id_new, options = plans,
        err = errors.plan_id, empty_label = 'No plan',
        help = 'The insurance plan that paid for this fill.' }) ?>

  <details<? if errors.insurance_claim_number or errors.notes then ?> open<? end ?>>
    <summary>More details</summary>
    <?= render('_field', { name = 'insurance_claim_number', label = 'Claim number',
          value = typed.insurance_claim_number, err = errors.insurance_claim_number, maxlength = 60 }) ?>
    <?= render('_textarea', { name = 'notes', label = 'Notes', value = typed.notes, err = errors.notes,
          maxlength = 500, help = 'Anything worth remembering about this fill.' }) ?>
  </details>

  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save the fill</button>
    <a class="pv-btn" href="<?= url('/refills') ?>">Cancel</a>
    <? if not is_new and typed.id then ?>
      <a class="pv-btn" href="<?= url('/fills/' .. typed.id .. '/remove') ?>"><?= icon('trash') ?> Remove this fill</a>
    <? end ?>
  </p>
</form>
