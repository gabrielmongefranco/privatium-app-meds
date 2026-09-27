<?--
This file is part of Prescription Tracker
apps/meds/views/paste_review.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The review of pasted fills: what was read, what it matched, and what will be added.
         Every value from the text is escaped by the output tag.
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
<h1>Check the fills</h1>
<p>These fills were read from the text you pasted, for <strong><?= person.display_name ?></strong>.
   Nothing is added yet.</p>
<p class="pv-notice pv-notice-info" role="status"><?= icon('info-circle') ?> <?= summary ?></p>

<form method="post" action="<?= url('/fills/paste/add') ?>" novalidate>
  <?= csrf() ?>
  <input type="hidden" name="person_id" value="<?= person.id ?>">
  <input type="hidden" name="pasted" value="<?= pasted ?>">

  <? for _, row in ipairs(rows) do ?>
    <? local claim = row.claim ?>
    <fieldset class="meds-claim">
      <legend>Fill <?= row.index ?>: <?= claim.drug_name or 'no name' ?>, <?= claim.filled_on ?></legend>
      <p>
        <? if row.ready then ?>
          <span class="pv-badge pv-badge-ok"><?= icon('check-circle') ?> <?= row.result ?></span>
        <? elseif row.can_add then ?>
          <span class="pv-badge pv-badge-warn"><?= icon('question-circle') ?> <?= row.result ?></span>
        <? else ?>
          <span class="pv-badge pv-badge-muted"><?= icon('dash-circle') ?> <?= row.result ?></span>
        <? end ?>
        <? if row.result == 'Already recorded' then ?>This person has a fill with the same prescription number and date. It is left out.<? end ?>
        <? if row.result == 'Not in the catalog' then ?>No medication in the catalog is close to this name. Add the medication to the catalog, then read the text again.<? end ?>
        <? if row.result == 'Details missing' then ?>The details of this fill were not open in the portal. Open them and copy the list again.<? end ?>
        <? if row.result == 'Not paid' then ?>The claim status is "<?= claim.status ?>". Add this fill only if it took place.<? end ?>
        <? if row.result == 'Choose a medication' then ?>The app does not know this name yet. Choose the medication, and the app remembers the name.<? end ?>
      </p>
      <? for _, problem in ipairs(row.problems) do ?>
        <p class="pv-error"><?= icon('exclamation-triangle') ?> <?= problem ?></p>
      <? end ?>

      <dl class="meds-read">
        <dt>Date filled</dt><dd><?= claim.filled_on ?></dd>
        <dt>Name in the portal</dt><dd><?= claim.drug_name ?></dd>
        <dt>Pharmacy in the portal</dt><dd><?= claim.pharmacy_name or 'Not read' ?></dd>
        <dt>Prescription number</dt><dd><?= claim.rx_number or 'Not read' ?></dd>
        <dt>Days supply</dt><dd><?= claim.days_supply or 'Not read' ?></dd>
        <dt>Quantity</dt><dd><?= claim.quantity or 'Not read' ?></dd>
        <dt>You paid</dt><dd><?= claim.amount_paid or 'Not read' ?></dd>
        <dt>Plan paid</dt><dd><?= claim.plan_paid or 'Not read' ?>, not stored</dd>
        <dt>Deductible</dt><dd><?= claim.deductible or 'Not read' ?>, not stored</dd>
      </dl>

      <? if row.can_add then ?>
        <label for="f-medication_<?= row.index ?>">Medication</label>
        <select id="f-medication_<?= row.index ?>" name="medication_<?= row.index ?>">
          <? if not row.known_name then ?><option value="">Choose a medication</option><? end ?>
          <? for _, option in ipairs(row.suggestions) do ?>
            <option value="<?= option.value ?>"<? if option.value == row.medication_id then ?> selected<? end ?>><?= option.label ?></option>
          <? end ?>
        </select>

        <label for="f-pharmacy_<?= row.index ?>">Pharmacy</label>
        <select id="f-pharmacy_<?= row.index ?>" name="pharmacy_<?= row.index ?>">
          <? if claim.pharmacy_name then ?>
            <option value="<?= new_pharmacy ?>"<? if row.pharmacy_id == new_pharmacy then ?> selected<? end ?>>Add <?= claim.pharmacy_name ?> from the pasted details</option>
          <? else ?>
            <option value="">Choose a pharmacy</option>
          <? end ?>
          <? for _, pharmacy in ipairs(pharmacies) do ?>
            <option value="<?= pharmacy.id ?>"<? if pharmacy.id == row.pharmacy_id then ?> selected<? end ?>><?= pharmacy.name ?></option>
          <? end ?>
        </select>

        <label for="f-include_<?= row.index ?>">
          <input id="f-include_<?= row.index ?>" name="include_<?= row.index ?>" type="checkbox" value="yes"<? if row.ready then ?> checked<? end ?>>
          Add this fill
        </label>
      <? end ?>
    </fieldset>
  <? end ?>

  <p>Adding a fill lowers the refills left of its medication by one. A medication that is
     not on the list of <?= person.display_name ?> is added to it, with the status Taking
     regularly.</p>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Add fills</button>
    <a class="pv-btn" href="<?= url('/fills/paste?person=' .. person.id) ?>">Start over</a>
  </p>
</form>
