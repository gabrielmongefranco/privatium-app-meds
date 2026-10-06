<?--
This file is part of Medication Tracker
apps/meds/views/_product_results.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-03
Last Modified: 2026-10-04
Summary: The results of a search of the catalog in the product box: a check box for each
         product, so several can be added at once, or a radio button for each when the form
         takes one product. The browser script draws the same list from the search answer;
         this is what the form shows without a script.
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

<? if #results > 0 then ?>
  <p class="pv-help" data-results-count><?= #results ?> <? if #results == 1 then ?>result<? else ?>results<? end ?> for "<?= term ?>". <? if single then ?>Choose the one to use.<? else ?>Check the ones to add.<? end ?></p>
  <fieldset class="meds-options meds-results">
    <legend class="pv-visually-hidden"><?= legend ?></legend>
    <? for position, medication in ipairs(results) do ?>
      <label class="meds-option" for="f-<?= prefix ?>-pick-<?= position ?>">
        <? if single then ?>
          <input id="f-<?= prefix ?>-pick-<?= position ?>" type="radio" name="<?= prefix ?>_choice" value="<?= medication.medication_id ?>"<? if chosen == medication.medication_id then ?> checked<? end ?>>
        <? else ?>
          <input id="f-<?= prefix ?>-pick-<?= position ?>" type="checkbox" name="pick_<?= medication.medication_id ?>" value="yes">
        <? end ?>
        <span><?= medication.short_name ?><? if medication.close then ?> <span class="pv-badge pv-badge-muted"><?= icon('info-circle') ?> Close match</span><? end ?>
          <span class="pv-meta meds-line"><?= medication.full_name ?></span></span>
      </label>
    <? end ?>
  </fieldset>
<? end ?>
