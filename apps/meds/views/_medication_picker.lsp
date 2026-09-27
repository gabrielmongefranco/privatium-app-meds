<?--
This file is part of Prescription Tracker
apps/meds/views/_medication_picker.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The medication box: a drop-down of the medications in use, a name to type,
         the choices when a name fits several, and the fields of a new medication.
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

<?
  local function typed_in(suffix) return typed[prefix .. suffix] end
  local err = err or (pick and pick.problem)
  local offered = candidates or (pick and pick.candidates) or {}
  local chosen = typed_in('_choice')
  local in_use = options or {}
  local asks = #offered > 0 or explicit
  local open_new = (pick and pick.open_new) or chosen == 'new'
    or (not explicit and ((typed_in('_brand') or '') ~= '' or (typed_in('_generic') or '') ~= ''))
  -- The parts under the drop-down are in use when a name was typed, a new medication
  -- was started, or the form came back with choices.
  local opened = open_new or asks or (typed_in('_name') or '') ~= ''
  local described = 'f-' .. prefix .. '-help' .. (err and (' f-' .. prefix .. '-err') or '')
?>
<fieldset class="meds-choice meds-picker" id="f-<?= prefix ?>_id">
  <legend><?= legend or 'Medication' ?></legend>
  <? if err then ?>
    <p id="f-<?= prefix ?>-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
  <? end ?>
  <? if #in_use > 0 then ?>
    <label for="f-<?= prefix ?>-list">Choose one that is already in use</label>
    <select id="f-<?= prefix ?>-list" name="<?= prefix ?>_id">
      <option value="">None chosen</option>
      <option value="new"<? if typed_in('_id') == 'new' or opened then ?> selected<? end ?>>-- Find another or add new --</option>
      <? for _, option in ipairs(in_use) do ?>
        <option value="<?= option.value ?>"<? if not opened and option.value == typed_in('_id') then ?> selected<? end ?>><?= option.label ?></option>
      <? end ?>
    </select>
  <? end ?>
  <? if asks then ?>
    <fieldset class="meds-options">
      <legend><? if explicit then ?>Which medication is it?<? else ?>Which one do you mean?<? end ?></legend>
      <? for position, medication in ipairs(offered) do ?>
        <label class="meds-option" for="f-<?= prefix ?>-choice-<?= position ?>">
          <input id="f-<?= prefix ?>-choice-<?= position ?>" type="radio" name="<?= prefix ?>_choice"
                 value="<?= medication.medication_id ?>"<? if chosen == medication.medication_id then ?> checked<? end ?>>
          <span><?= medication.short_name ?><? if medication.sure then ?> <span class="pv-badge pv-badge-ok"><?= icon('check-circle') ?> <?= medication.note or 'Same name and strength' ?></span><? elseif medication.note then ?> <span class="pv-badge pv-badge-muted"><?= icon('info-circle') ?> <?= medication.note ?></span><? end ?>
            <span class="pv-meta meds-line"><?= medication.full_name ?></span></span>
        </label>
      <? end ?>
      <? if explicit then ?>
        <label class="meds-option" for="f-<?= prefix ?>-choice-other">
          <input id="f-<?= prefix ?>-choice-other" type="radio" name="<?= prefix ?>_choice" value="other"<? if chosen == 'other' then ?> checked<? end ?>>
          <span>Another medication. I type its name below.</span>
        </label>
      <? end ?>
      <label class="meds-option" for="f-<?= prefix ?>-choice-new">
        <input id="f-<?= prefix ?>-choice-new" type="radio" name="<?= prefix ?>_choice" value="new"<? if chosen == 'new' then ?> checked<? end ?>>
        <span>A new medication. I check its details below.</span>
      </label>
    </fieldset>
  <? end ?>
  <? -- With a script, these parts show only after the choice to find or add. Without one, they are always there. ?>
  <div<? if #in_use > 0 then ?> data-show-when="<?= prefix ?>_id=new"<? end ?>>
  <? if explicit then ?><div data-show-when="<?= prefix ?>_choice=other"><? end ?>
  <label for="f-<?= prefix ?>-name"><? if #in_use > 0 and not asks then ?>Or type a name to search the catalog<? else ?>Type a name to search the catalog<? end ?></label>
  <input id="f-<?= prefix ?>-name" name="<?= prefix ?>_name" type="text" value="<?= typed_in('_name') ?>"
         list="medication-names" autocomplete="off" maxlength="100" aria-describedby="<?= described ?>"
         <? if err then ?>aria-invalid="true"<? end ?>>
  <p id="f-<?= prefix ?>-help" class="pv-help">Type a few letters of any name of the medication, then pick it from the suggestions. The catalog is the list of products the app knows.</p>
  <? if explicit then ?></div><div data-show-when="<?= prefix ?>_choice=new"><? end ?>
  <details<? if open_new or explicit then ?> open<? end ?>>
    <summary>It is not in the catalog. Add a new medication</summary>
    <? -- The lookup needs a script, so it stays hidden until the script shows it. ?>
    <div class="meds-lookup" data-lookup="<?= prefix ?>" hidden>
      <label for="f-<?= prefix ?>-lookup">Look it up in a drug reference</label>
      <input id="f-<?= prefix ?>-lookup" type="search" autocomplete="off" maxlength="100"
             aria-describedby="f-<?= prefix ?>-lookup-help" data-lookup-term>
      <button type="button" class="pv-btn" data-lookup-search><?= icon('search') ?> Look up</button>
      <p id="f-<?= prefix ?>-lookup-help" class="pv-help">Type a name and choose <strong>Look up</strong>. Pick a result, and the app fills in the fields below. You can also fill them in yourself.</p>
      <p role="status" class="pv-help" data-lookup-status></p>
      <ul class="meds-lookup-results" data-lookup-results></ul>
    </div>
    <input type="hidden" name="<?= prefix ?>_rxcui" value="<?= typed_in('_rxcui') ?>">
    <input type="hidden" name="<?= prefix ?>_source" value="<?= typed_in('_source') ?>">
    <input type="hidden" name="<?= prefix ?>_route" value="<?= typed_in('_route') ?>">
    <input type="hidden" name="<?= prefix ?>_dose_form" value="<?= typed_in('_dose_form') ?>">
    <label for="f-<?= prefix ?>-brand">Brand name <span class="meds-optional">(optional)</span></label>
    <input id="f-<?= prefix ?>-brand" name="<?= prefix ?>_brand" data-lookup-field="brand" type="text" value="<?= typed_in('_brand') ?>"
           autocomplete="off" maxlength="200">
    <label for="f-<?= prefix ?>-generic">Generic name <span class="meds-optional">(optional)</span></label>
    <input id="f-<?= prefix ?>-generic" name="<?= prefix ?>_generic" data-lookup-field="generic" type="text" value="<?= typed_in('_generic') ?>"
           autocomplete="off" maxlength="200" aria-describedby="f-<?= prefix ?>-new-help">
    <p id="f-<?= prefix ?>-new-help" class="pv-help">Type the brand name, the generic name, or both.</p>
    <label for="f-<?= prefix ?>-strength">Strength <span class="meds-optional">(optional)</span></label>
    <input id="f-<?= prefix ?>-strength" name="<?= prefix ?>_strength" data-lookup-field="strength" type="text" value="<?= typed_in('_strength') ?>"
           autocomplete="off" maxlength="60" aria-describedby="f-<?= prefix ?>-strength-help">
    <p id="f-<?= prefix ?>-strength-help" class="pv-help">As the label prints it, with the unit, such as 10 mg.</p>
    <label class="meds-option" for="f-<?= prefix ?>-specialty">
      <input id="f-<?= prefix ?>-specialty" name="<?= prefix ?>_specialty" type="checkbox" value="yes"<? if typed_in('_specialty') == 'yes' then ?> checked<? end ?>>
      <span>This is a specialty medication</span>
    </label>
    <p class="pv-help">Saving adds the medication to the catalog. You can add its route, form and package there later.</p>
  </details>
  <? if explicit then ?></div><? end ?>
  </div>
</fieldset>
