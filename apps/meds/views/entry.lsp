<?--
This file is part of Prescription Tracker
apps/meds/views/entry.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
Summary: The page of one tracked medication of one person: how to take it, its refills, who
         to call, its prior authorizations, its fills and its catalog products.
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
<p><a href="<?= url('/medications?person=' .. entry.person_id) ?>">Back to the medications of <?= entry.person_name ?></a></p>
<h1><?= render('_form_icon', { icon_name = entry.form_icon, label = entry.form_label }) ?> <?= entry.medication_name ?></h1>
<?= render('_notice', { notice = notice }) ?>
<p>Taken by <?= entry.person_name ?>. Status: <strong><?= entry.status_label ?></strong>.</p>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/fills/new?entry=' .. entry.id) ?>"><?= icon('plus-lg') ?> Record fill</a>
  <a class="pv-btn" href="<?= url('/medications/' .. entry.id .. '/edit') ?>"><?= icon('pencil') ?> Change</a>
  <a class="pv-btn" href="<?= url('/medications/' .. entry.id .. '/remove') ?>"><?= icon('trash') ?> Remove</a>
</p>

<form method="post" action="<?= url('/medications/' .. entry.id .. '/status') ?>" class="meds-inline-form">
  <?= csrf() ?>
  <label for="f-status">Change the status</label>
  <select id="f-status" name="status">
    <? for _, status in ipairs(statuses) do ?>
      <option value="<?= status.value ?>"<? if status.value == entry.status then ?> selected<? end ?>><?= status.label ?></option>
    <? end ?>
  </select>
  <button type="submit" class="pv-btn">Save the status</button>
</form>

<h2>How to take it</h2>
<div class="pv-card"><dl>
  <dt>Instructions</dt><dd><?= entry.instructions or 'Not given' ?></dd>
  <dt>When</dt><dd><?= entry.when_to_take or 'Not given' ?></dd>
  <dt>Reason</dt><dd><?= entry.prescribed_for or 'Not given' ?></dd>
  <? if entry.medication_type then ?><dt>Type</dt><dd><?= entry.medication_type ?></dd><? end ?>
</dl></div>

<h2>Refills</h2>
<div class="pv-card"><dl>
  <? if entry.status ~= 'not_taking' then ?>
    <dt>Refill status</dt>
    <dd><?= render('_refill_badge', { badge = entry.badge, icon_name = entry.icon_name, phrase = entry.phrase }) ?></dd>
  <? end ?>
  <dt>Last fill</dt>
  <dd><? if entry.last_filled_on then ?><?= fmt.date(entry.last_filled_on) ?><? if entry.last_fill_pharmacy_name then ?> at <?= entry.last_fill_pharmacy_name ?><? end ?><? if entry.last_days_supply then ?>, <?= entry.last_days_supply ?> days<? end ?><? else ?>No fill recorded<? end ?></dd>
  <? if entry.next_fill_on then ?>
    <dt>Next fill date</dt><dd><?= fmt.date(entry.next_fill_on) ?></dd>
    <dt>Lasts until</dt><dd><?= fmt.date(entry.lasts_until) ?></dd>
  <? end ?>
  <? if entry.days_supply_missing == 1 then ?>
    <dt>Missing</dt><dd>The last fill has no days supply, so it counts as 1 day. Change the fill to add it.</dd>
  <? end ?>
  <dt>Refills left</dt><dd><?= entry.refills_left ?><? if entry.refills_left == 0 then ?>. Ask for a new prescription.<? end ?></dd>
  <? if entry.is_controlled then ?><dt>Controlled</dt><dd>Yes.</dd><? end ?>
  <? if entry.is_specialty then ?><dt>Specialty</dt><dd>Yes. Refills are due earlier because delivery takes longer.</dd><? end ?>
</dl></div>
<p class="pv-help">The next fill date estimates when the plan will pay, using its refill rules. Lasts until is when all recorded supply runs out.</p>

<h2>Who to call</h2>
<div class="pv-card"><dl>
  <dt>Prescriber</dt>
  <dd><?= entry.prescriber_name or 'Self-prescribed' ?><? if entry.prescriber_href then ?>, <a href="tel:<?= entry.prescriber_href ?>"><?= entry.prescriber_phone ?></a><? end ?></dd>
  <dt>Pharmacy</dt>
  <dd><?= entry.pharmacy_name or 'Not given' ?><? if entry.pharmacy_href then ?>, <a href="tel:<?= entry.pharmacy_href ?>"><?= entry.pharmacy_phone ?></a><? end ?></dd>
</dl></div>

<h2>Prior authorizations</h2>
<? if #authorizations == 0 then ?>
  <p class="pv-empty">No prior authorization is recorded.</p>
<? else ?>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Prior authorizations, latest first</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">First day</th>
      <th scope="col" role="columnheader">Expires on</th>
      <th scope="col" role="columnheader">State</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, authorization in ipairs(authorizations) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">First day</span><? if authorization.valid_from then ?><?= fmt.date(authorization.valid_from) ?><? else ?>Not known<? end ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Expires on</span><?= fmt.date(authorization.valid_to) ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">State</span><?= authorization.state ?></td>
      </tr>
    <? end ?>
    </tbody>
  </table>
<? end ?>
<p class="pv-actions"><a class="pv-btn" href="<?= url('/authorizations/new?entry=' .. entry.id) ?>"><?= icon('plus-lg') ?> Add an authorization</a></p>

<h2>Fill history</h2>
<? if #fills == 0 then ?>
  <p class="pv-empty">No fill is recorded.</p>
<? else ?>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Fills of this medication, newest first</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Date</th>
      <? if #products > 1 then ?><th scope="col" role="columnheader">Product</th><? end ?>
      <th scope="col" role="columnheader">Pharmacy</th>
      <th scope="col" role="columnheader">Quantity</th>
      <th scope="col" role="columnheader">Days supply</th>
      <th scope="col" role="columnheader">You paid</th>
      <th scope="col" role="columnheader">Actions</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, fill in ipairs(fills) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Date</span><?= fmt.date(fill.filled_on) ?></td>
        <? if #products > 1 then ?><td role="cell"><span class="pv-cell-label" aria-hidden="true">Product</span><?= fill.product_name or 'Not given' ?></td><? end ?>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Pharmacy</span><?= fill.pharmacy_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Quantity</span><?= fill.quantity or 'Not given' ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Days supply</span><?= fill.days_supply or 'Not given' ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">You paid</span><? if fill.amount_paid then ?><?= fmt.money(fill.amount_paid) ?><? else ?>Not given<? end ?></td>
        <td role="cell"><a class="pv-btn" href="<?= url('/fills/' .. fill.id .. '/edit') ?>"><?= icon('pencil') ?> Change<span class="pv-visually-hidden"> the fill of <?= fill.filled_on ?></span></a></td>
      </tr>
    <? end ?>
    </tbody>
  </table>
  <p class="pv-meta"><?= paid.fills ?> fills. Total paid: <? if paid.amount_paid then ?><?= fmt.money(paid.amount_paid) ?><? else ?>not given<? end ?>.</p>
<? end ?>

<h2>Products</h2>
<p class="pv-help">The products this medication comes as. A fill of any of them counts here.</p>
<? if #products == 0 then ?>
  <p class="pv-empty">No product yet. Choose <strong>Change</strong> to add one.</p>
<? else ?>
  <ul class="meds-products">
    <? for _, product in ipairs(products) do ?>
      <li>
        <span><a href="<?= url('/setup/catalog/' .. product.medication_id) ?>"><?= product.short_name ?></a>
          <span class="pv-meta meds-line"><?= product.full_name ?><? if product.is_controlled then ?>. Controlled<? end ?><? if product.is_specialty then ?>. Specialty<? end ?></span></span>
        <? if #products > 1 then ?>
          <a class="pv-btn" href="<?= url('/medications/' .. entry.id .. '/products/' .. product.link_id .. '/remove') ?>"><?= icon('x-lg') ?> Remove<span class="pv-visually-hidden"> the product <?= product.short_name ?></span></a>
        <? end ?>
      </li>
    <? end ?>
  </ul>
<? end ?>
<p class="pv-help">To add another package size, choose <strong>Change</strong>.</p>
