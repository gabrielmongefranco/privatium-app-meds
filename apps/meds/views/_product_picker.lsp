<?--
This file is part of Prescription Tracker
apps/meds/views/_product_picker.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-03
Last Modified: 2026-10-03
Summary: The products of a tracked medication in its form: the ones chosen so far, each with
         a Remove button and carried in hidden fields, and the medication box that finds or
         adds the next one.
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

<fieldset class="meds-choice" id="f-products">
  <legend>Catalog products</legend>
  <p class="pv-help">The catalog entries this medication stands for: the product on the label, or several when one medication comes in more than one carton. Every fill is counted under this medication.</p>
  <? if err then ?>
    <p id="f-products-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
  <? end ?>
  <? if #chosen == 0 then ?>
    <p class="pv-empty">No product yet. Find one in the catalog below, or add it to the catalog.</p>
  <? else ?>
    <ul class="meds-products" aria-label="Products on this entry">
      <? for index, product in ipairs(chosen) do ?>
        <li>
          <span><?= product.full_name ?><? if product.new_row then ?> <span class="pv-badge pv-badge-muted"><?= icon('plus-circle') ?> New to the catalog</span><? end ?></span>
          <? for name, value in pairs(product.fields) do ?>
            <? if value then ?><input type="hidden" name="product_<?= index ?>_<?= name ?>" value="<?= value ?>"><? end ?>
          <? end ?>
          <button type="submit" class="pv-btn" name="action" value="remove_product_<?= index ?>"><?= icon('x-lg') ?> Remove<span class="pv-visually-hidden"> <?= product.full_name ?></span></button>
        </li>
      <? end ?>
    </ul>
  <? end ?>
</fieldset>
<?= render('_medication_picker', { prefix = prefix, typed = typed, pick = pick,
      legend = #chosen == 0 and 'Find the product' or 'Find another product',
      add_button = add_button }) ?>
