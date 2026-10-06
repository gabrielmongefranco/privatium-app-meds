<?--
This file is part of Medication Tracker
apps/meds/views/_product_box.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-04
Last Modified: 2026-10-04
Summary: The box that finds a product: a search of the catalog with a Find button, the
         results with a check box each (or one radio button each when the form takes one
         product), and the fields that add a medication the catalog lacks. Every form that
         needs a product shows this box.
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
  -- `single` is true when the form takes one product, as the fill form does: the
  -- results are then radio buttons named <prefix>_choice, which the server reads as
  -- the choice of the box. Otherwise each result is a check box named pick_<id>.
  local function typed_in(suffix) return typed[prefix .. suffix] end
  local box_err = err or (pick and pick.problem)
  local results = (pick and pick.results) or {}
  local term = (pick and pick.term) or typed_in('_q') or ''
  -- The fields of a new medication show when the box asked for them, or when they hold
  -- something a person typed.
  local open_new = (pick and pick.open_new)
    or (typed_in('_brand') or '') ~= '' or (typed_in('_generic') or '') ~= ''
  local described = 'f-' .. prefix .. '-help' .. (box_err and (' f-' .. prefix .. '-err') or '')
  local find_value = find_button or ('find_' .. prefix)
?>
<fieldset class="meds-choice meds-picker" id="f-<?= prefix ?>_id"
          data-product-search="<?= prefix ?>" data-search-url="<?= search_url ?>"<? if single then ?> data-pick-one<? end ?>>
  <legend<? if hide_legend then ?> class="pv-visually-hidden"<? end ?>><?= legend or 'Find the product' ?></legend>
  <? if box_err then ?>
    <p id="f-<?= prefix ?>-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= box_err ?></p>
  <? end ?>

  <label for="f-<?= prefix ?>-q">Search the catalog</label>
  <div class="meds-search-row">
    <input id="f-<?= prefix ?>-q" name="<?= prefix ?>_q" type="search" value="<?= term ?>"
           list="medication-names" autocomplete="off" maxlength="100"
           aria-describedby="<?= described ?>"<? if box_err then ?> aria-invalid="true"<? end ?> data-search-term>
    <button type="submit" class="pv-btn" name="step" value="<?= find_value ?>" data-search-find><?= icon('search') ?> Find</button>
  </div>
  <p id="f-<?= prefix ?>-help" class="pv-help">Type a few letters of any of its names, then press Enter or choose <strong>Find</strong>. Picking a suggestion finds it at once.</p>
  <? -- The online search runs in the browser, so the link waits for the script. ?>
  <p class="meds-online" hidden data-online-line>
    <button type="button" class="meds-link-button" data-search-online>Search online databases</button>
  </p>
  <p role="status" class="meds-searching" data-search-status><span class="meds-spinner" aria-hidden="true" hidden></span><span data-status-text></span></p>
  <div data-results>
    <?= render('_product_results', { prefix = prefix, results = results, term = term, legend = 'Products found',
          single = single, chosen = typed_in('_choice') }) ?>
  </div>

  <details data-new-product<? if open_new then ?> open<? end ?>>
    <summary>Not in the list? Add a medication to the catalog</summary>
    <input type="hidden" name="<?= prefix ?>_rxcui" value="<?= typed_in('_rxcui') ?>">
    <input type="hidden" name="<?= prefix ?>_source" value="<?= typed_in('_source') ?>">
    <input type="hidden" name="<?= prefix ?>_route_ref" value="<?= typed_in('_route_ref') ?>">
    <input type="hidden" name="<?= prefix ?>_dose_form_ref" value="<?= typed_in('_dose_form_ref') ?>">
    <label for="f-<?= prefix ?>-brand">Brand name <span class="meds-optional">(optional)</span></label>
    <input id="f-<?= prefix ?>-brand" name="<?= prefix ?>_brand" data-new-field="brand" type="text" value="<?= typed_in('_brand') ?>"
           autocomplete="off" maxlength="200">
    <label for="f-<?= prefix ?>-generic">Generic name <span class="meds-optional">(optional)</span></label>
    <input id="f-<?= prefix ?>-generic" name="<?= prefix ?>_generic" data-new-field="generic" type="text" value="<?= typed_in('_generic') ?>"
           autocomplete="off" maxlength="200" aria-describedby="f-<?= prefix ?>-new-help">
    <p id="f-<?= prefix ?>-new-help" class="pv-help">Type the brand name, the generic name, or both.</p>
    <p role="status" class="meds-searching" data-similar-status><span class="meds-spinner" aria-hidden="true" hidden></span><span data-status-text></span></p>
    <div data-results data-similar></div>
    <label for="f-<?= prefix ?>-strength">Strength <span class="meds-optional">(optional)</span></label>
    <input id="f-<?= prefix ?>-strength" name="<?= prefix ?>_strength" data-new-field="strength" type="text" value="<?= typed_in('_strength') ?>"
           autocomplete="off" maxlength="60" aria-describedby="f-<?= prefix ?>-strength-help">
    <p id="f-<?= prefix ?>-strength-help" class="pv-help">As the label prints it, with the unit, such as 10 mg.</p>
    <?= render('_choice', { name = prefix .. '_route', legend = 'Route', value = typed_in('_route'),
          typed_new = typed_in('_route_new'), offered = catalog_options.route }) ?>
    <?= render('_choice', { name = prefix .. '_dose_form', legend = 'Form', value = typed_in('_dose_form'),
          typed_new = typed_in('_dose_form_new'), offered = catalog_options.dose_form }) ?>
    <label for="f-<?= prefix ?>-package_size">Package size <span class="meds-optional">(optional)</span></label>
    <input id="f-<?= prefix ?>-package_size" name="<?= prefix ?>_package_size" type="text"
           value="<?= typed_in('_package_size') ?>" autocomplete="off" maxlength="40"
           aria-describedby="f-<?= prefix ?>-package-help">
    <p id="f-<?= prefix ?>-package-help" class="pv-help">For medications sold by the box. For a box of two pens, type 2 as the size and choose Pack as the type.</p>
    <?= render('_choice', { name = prefix .. '_package_type', legend = 'Package type',
          value = typed_in('_package_type'), typed_new = typed_in('_package_type_new'),
          offered = catalog_options.package_type }) ?>
    <fieldset>
      <legend>Special handling</legend>
      <label class="meds-option" for="f-<?= prefix ?>-controlled">
        <input id="f-<?= prefix ?>-controlled" name="<?= prefix ?>_controlled" type="checkbox" value="yes"
               aria-describedby="f-<?= prefix ?>-controlled-help"<? if typed_in('_controlled') == 'yes' then ?> checked<? end ?>>
        <span>This is a controlled medication</span>
      </label>
      <p id="f-<?= prefix ?>-controlled-help" class="pv-help">A controlled medication can usually be refilled only when the supply runs out.</p>
      <label class="meds-option" for="f-<?= prefix ?>-specialty">
        <input id="f-<?= prefix ?>-specialty" name="<?= prefix ?>_specialty" type="checkbox" value="yes"<? if typed_in('_specialty') == 'yes' then ?> checked<? end ?>>
        <span>This is a specialty medication</span>
      </label>
    </fieldset>
  </details>
  <? if add_button then ?>
    <p class="pv-actions"><button type="submit" class="pv-btn" name="step" value="<?= add_button ?>"><?= icon('plus-lg') ?> Add to this medication</button></p>
  <? end ?>
</fieldset>
