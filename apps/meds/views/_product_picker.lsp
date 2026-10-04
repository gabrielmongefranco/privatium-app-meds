<?--
This file is part of Prescription Tracker
apps/meds/views/_product_picker.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-03
Last Modified: 2026-10-04
Summary: The products of a tracked medication in its form: the box that finds a product, and,
         once a product is on the list, the Products box with the products chosen so far,
         each with a Remove button and carried in hidden fields, and the same search box
         folded inside it to add another.
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
  -- With products chosen, the box folds away until it is wanted, or until it has
  -- something to say.
  local box_err = pick and pick.problem
  local folded = #chosen > 0 and not pick and not box_err
  local box = {
    prefix = prefix, typed = typed, pick = pick, catalog_options = catalog_options,
    search_url = search_url, add_button = add_button, find_button = find_button,
    -- With no product yet, a problem about the products shows in the box itself.
    err = #chosen == 0 and err or nil,
    hide_legend = #chosen > 0,
  }
?>
<? if #chosen == 0 then ?>
  <?= render('_product_box', box) ?>
<? else ?>
<fieldset class="meds-choice meds-products-box" id="f-products">
  <legend>Products</legend>
  <p class="pv-help">The product named on the pharmacy label. Add more than one when the same medication comes in different package sizes.</p>
  <? if err then ?>
    <p id="f-products-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
  <? end ?>
  <ul class="meds-products" aria-label="Products of this medication">
    <? for index, product in ipairs(chosen) do ?>
      <li>
        <span><?= product.full_name ?><? if product.new_row then ?> <span class="pv-badge pv-badge-muted"><?= icon('plus-circle') ?> New</span><? end ?></span>
        <? for name, value in pairs(product.fields) do ?>
          <? if value then ?><input type="hidden" name="product_<?= index ?>_<?= name ?>" value="<?= value ?>"><? end ?>
        <? end ?>
        <button type="submit" class="pv-btn" name="step" value="remove_product_<?= index ?>"><?= icon('x-lg') ?> Remove<span class="pv-visually-hidden"> <?= product.full_name ?></span></button>
      </li>
    <? end ?>
  </ul>
  <details class="meds-another"<? if not folded then ?> open<? end ?>>
    <summary>
      <span class="meds-summary-title">Add another product</span>
      <span class="meds-summary-note">(e.g. different pack size of the same medication)</span>
    </summary>
    <?= render('_product_box', box) ?>
  </details>
</fieldset>
<? end ?>
