<?--
This file is part of Prescription Tracker
apps/meds/views/fill_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The form that records a fill or changes one. A new fill starts with the values of
         the last fill of the same medication, all of them visible.
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
  <div class="pv-card"><dl>
    <dt>Medication</dt><dd><?= medication and medication.short_name or 'Not in the catalog' ?></dd>
  </dl></div>
  <input type="hidden" name="medication_id" value="<?= medication and medication.medication_id ?>">
  <? if errors.medication_id then ?>
    <p id="f-medication_id" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= errors.medication_id ?></p>
  <? end ?>
  <? if is_new and typed.person_id and not on_list then ?>
    <p class="pv-notice pv-notice-info"><?= icon('info-circle') ?>
      <span>This medication is not on the list of this person. Saving the fill adds it, with the status Taking regularly.</span></p>
  <? end ?>

  <?= render('_select', { name = 'person_id', label = 'Who is it for', value = typed.person_id,
        options = people, required = true, err = errors.person_id, empty_label = 'Choose a person' }) ?>
  <?= render('_field', { name = 'filled_on', label = 'Date filled', value = typed.filled_on,
        err = errors.filled_on, required = true, input_type = 'date', max = today,
        help = 'The date on the pharmacy label.' }) ?>
  <?= render('_select', { name = 'pharmacy_id', label = 'Pharmacy', value = typed.pharmacy_id,
        options = pharmacies, required = true, err = errors.pharmacy_id,
        empty_label = 'Choose a pharmacy' }) ?>
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
          value = typed.refills_left, err = errors.refills_left, required = true,
          inputmode = 'numeric', maxlength = 2,
          help = 'The number on the label. Type 0 when none is left.' }) ?>
  <? end ?>
  <?= render('_field', { name = 'rx_number', label = 'Prescription number', value = typed.rx_number,
        err = errors.rx_number, maxlength = 40,
        help = 'The Rx number on the label. A new prescription has a new number.' }) ?>
  <?= render('_field', { name = 'insurance_plan', label = 'Insurance plan', value = typed.insurance_plan,
        err = errors.insurance_plan, maxlength = 80 }) ?>

  <details<? if errors.insurance_claim_number or errors.notes then ?> open<? end ?>>
    <summary>More details</summary>
    <?= render('_field', { name = 'insurance_claim_number', label = 'Claim number',
          value = typed.insurance_claim_number, err = errors.insurance_claim_number, maxlength = 60 }) ?>
    <?= render('_field', { name = 'notes', label = 'Notes', value = typed.notes, err = errors.notes,
          maxlength = 500 }) ?>
  </details>

  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save the fill</button>
    <a class="pv-btn" href="<?= url('/') ?>">Cancel</a>
    <? if not is_new and typed.id then ?>
      <a class="pv-btn" href="<?= url('/fills/' .. typed.id .. '/remove') ?>"><?= icon('trash') ?> Remove this fill</a>
    <? end ?>
  </p>
</form>
