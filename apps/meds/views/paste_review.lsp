<?--
This file is part of Prescription Tracker
apps/meds/views/paste_review.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
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
<p class="pv-help"><? if plan_name then ?>Each added fill uses this person's plan: <?= plan_name ?>.<? else ?>This person has no plan. Added fills have no payer recorded.<? end ?></p>
<p>Fills found in the text you pasted for <strong><?= person.display_name ?></strong>.
   Nothing is added yet.</p>
<p class="pv-notice pv-notice-info" role="status"><?= icon('info-circle') ?> <span><?= summary ?></span></p>
<? if err then ?>
  <p id="review-err" class="pv-notice pv-notice-error" role="alert" tabindex="-1"><?= icon('exclamation-triangle') ?> <span><?= err ?></span></p>
<? end ?>

<form method="post" action="<?= url('/fills/paste/add') ?>" novalidate>
  <?= csrf() ?>
  <input type="hidden" name="person_id" value="<?= person.id ?>">
  <input type="hidden" name="pasted" value="<?= pasted ?>">
  <?= render('_medication_names', { names = names }) ?>

  <h2>Medications</h2>
  <? if #found.medications == 0 then ?>
    <p class="pv-empty">No fills can be added from this text.</p>
  <? end ?>
  <p>The portal writes each name its own way. Tell the app once which medication a name
     means, and the app remembers it for the next paste.</p>
  <? for _, subject in ipairs(found.medications) do ?>
    <? if subject.known then ?>
      <div class="pv-card meds-claim">
        <h3><?= subject.name ?></h3>
        <p><span class="pv-badge pv-badge-ok"><?= icon('check-circle') ?> Known name</span>
           This is <strong><?= subject.known.short_name ?></strong>.</p>
      </div>
    <? else ?>
      <div class="meds-claim">
        <h3><?= subject.name ?></h3>
        <? if #subject.candidates == 0 then ?>
          <p><span class="pv-badge pv-badge-warn"><?= icon('question-circle') ?> New name</span>
             The catalog holds nothing like this name. The app filled in a new medication
             from it. Check the details, or type the name of the medication you mean.</p>
        <? elseif subject.by_number and subject.candidates[1].sure then ?>
          <p><span class="pv-badge pv-badge-ok"><?= icon('check-circle') ?> Matched</span>
             An earlier fill has the same prescription number, and its medication has this name. It is chosen for you.</p>
        <? elseif subject.by_number then ?>
          <p><span class="pv-badge pv-badge-warn"><?= icon('question-circle') ?> Choose a medication</span>
             An earlier fill has the same prescription number, under another name. Its medication comes first. Check it before you choose it.</p>
        <? elseif subject.candidates[1].sure then ?>
          <p><span class="pv-badge pv-badge-ok"><?= icon('check-circle') ?> Matched</span>
             One medication has the same name and the same strength. It is chosen for you.</p>
        <? else ?>
          <p><span class="pv-badge pv-badge-warn"><?= icon('question-circle') ?> Choose a medication</span>
             These medications are the closest. The best match comes first.</p>
        <? end ?>
        <?= render('_medication_picker', { prefix = subject.prefix, typed = typed,
              legend = 'Which medication is ' .. subject.name .. '?', candidates = subject.candidates,
              pick = subject.used and subject.pick or nil, explicit = true }) ?>
      </div>
    <? end ?>
  <? end ?>

  <h2>Pharmacies</h2>
  <? if #found.pharmacies == 0 then ?>
    <p class="pv-empty">No fills can be added from this text.</p>
  <? end ?>
  <? for _, subject in ipairs(found.pharmacies) do ?>
    <div class="pv-card meds-claim">
      <h3><?= subject.name or 'Pharmacy with no name' ?></h3>
      <? if subject.known then ?>
        <p><span class="pv-badge pv-badge-ok"><?= icon('check-circle') ?> Known pharmacy</span>
           This pharmacy is in the app.</p>
      <? else ?>
        <? local refused = subject.used and subject.problem ?>
        <label for="f-<?= subject.field ?>">Which pharmacy is <?= subject.name or 'this' ?>?</label>
        <select id="f-<?= subject.field ?>" name="<?= subject.field ?>"<? if refused then ?> aria-invalid="true" aria-describedby="f-<?= subject.field ?>-err"<? end ?>>
          <? if subject.can_add then ?>
            <option value="<?= new_pharmacy ?>"<? if typed[subject.field] == new_pharmacy then ?> selected<? end ?>>Add <?= subject.name ?>, with the address and phone number that were pasted</option>
          <? else ?>
            <option value="">Choose a pharmacy</option>
          <? end ?>
          <? for _, pharmacy in ipairs(found.known) do ?>
            <option value="<?= pharmacy.id ?>"<? if pharmacy.id == typed[subject.field] then ?> selected<? end ?>><?= pharmacy.name ?></option>
          <? end ?>
        </select>
        <? if refused then ?>
          <p id="f-<?= subject.field ?>-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= subject.problem ?></p>
        <? end ?>
      <? end ?>
    </div>
  <? end ?>

  <h2>Fills</h2>
  <? for _, row in ipairs(found.rows) do ?>
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
        <? if row.result == 'Already recorded' and row.same_day then ?>This person has a fill of this medication on the same date. It is left out.<? elseif row.result == 'Already recorded' then ?>This person has a fill with the same prescription number and date. It is left out.<? end ?>
        <? if row.result == 'Details missing' then ?>The details of this fill were not open in the portal. Open them and copy the list again.<? end ?>
        <? if row.result == 'Not paid' then ?>The claim status is "<?= claim.status ?>". Add this fill only if it took place.<? end ?>
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
        <label class="meds-option" for="f-include_<?= row.index ?>">
          <input id="f-include_<?= row.index ?>" name="include_<?= row.index ?>" type="checkbox" value="yes"<? if typed['include_' .. row.index] == 'yes' then ?> checked<? end ?>>
          <span>Add this fill</span>
        </label>
      <? end ?>
    </fieldset>
  <? end ?>

  <p>Adding a fill lowers the refills left of its medication by one. A product that is on
     no list of <?= person.display_name ?> is added to the list, with the status Taking
     regularly and the full name of the product as its name.</p>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Add fills</button>
    <a class="pv-btn" href="<?= url('/fills/paste?person=' .. person.id) ?>">Start over</a>
  </p>
</form>
