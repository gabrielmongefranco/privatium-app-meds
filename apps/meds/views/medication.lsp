<?--
This file is part of Prescription Tracker
apps/meds/views/medication.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: One medication of the catalog: its names and its details.
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
<p><a href="<?= url('/setup/catalog') ?>">Back to the medication catalog</a></p>
<h1><?= medication.short_name ?></h1>
<?= render('_notice', { notice = notice }) ?>

<? if medication.is_specialty then ?>
  <p><span class="pv-badge pv-badge-muted"><?= icon('truck') ?> Specialty</span>
     A specialty medication takes longer to arrive, so its refill is due earlier.</p>
<? end ?>

<h2>Details</h2>
<div class="pv-card">
  <dl>
    <dt>Full name</dt><dd><?= medication.full_name ?></dd>
    <? if medication.brand_name then ?><dt>Brand name</dt><dd><?= medication.brand_name ?></dd><? end ?>
    <? if medication.generic_name then ?><dt>Generic name</dt><dd><?= medication.generic_name ?></dd><? end ?>
    <? if medication.strength then ?><dt>Strength</dt><dd><?= medication.strength ?></dd><? end ?>
    <? if medication.route then ?><dt>Route</dt><dd><?= medication.route ?></dd><? end ?>
    <? if medication.form then ?><dt>Form</dt><dd><?= medication.form ?></dd><? end ?>
    <? if medication.package_size then ?><dt>Package size</dt><dd><?= medication.package_size ?></dd><? end ?>
    <? if medication.package_type then ?><dt>Package type</dt><dd><?= medication.package_type ?></dd><? end ?>
  </dl>
</div>

<h2>Other names</h2>
<p>The search finds this medication by its short name, its brand name, its generic name,
   and every name listed here.</p>
<? if #other_names == 0 then ?>
  <p class="pv-empty">This medication has no other names.</p>
<? else ?>
  <ul class="meds-names">
    <? for _, other in ipairs(other_names) do ?>
      <li><span><?= other.alias ?></span>
        <a class="pv-btn" href="<?= url('/setup/catalog/' .. medication.medication_id .. '/names/' .. other.id .. '/remove') ?>"><?= icon('trash') ?> Remove<span class="pv-visually-hidden"> the name <?= other.alias ?></span></a></li>
    <? end ?>
  </ul>
<? end ?>

<form method="post" action="<?= url('/setup/catalog/' .. medication.medication_id .. '/names') ?>" novalidate>
  <?= csrf() ?>
  <?= render('_field', { name = 'alias', label = 'Add another name', value = typed_alias,
        err = alias_err, required = true, maxlength = 200,
        help = 'A name as a label, a statement or a person writes it.' }) ?>
  <button type="submit" class="pv-btn"><?= icon('plus-lg') ?> Add the name</button>
</form>

<h2>Actions</h2>
<p class="pv-actions">
  <a class="pv-btn" href="<?= url('/setup/catalog/' .. medication.medication_id .. '/edit') ?>"><?= icon('pencil') ?> Change</a>
  <a class="pv-btn" href="<?= url('/setup/catalog/' .. medication.medication_id .. '/merge') ?>"><?= icon('arrows-collapse') ?> Merge into another medication</a>
  <a class="pv-btn" href="<?= url('/setup/catalog/' .. medication.medication_id .. '/remove') ?>"><?= icon('trash') ?> Remove</a>
</p>
