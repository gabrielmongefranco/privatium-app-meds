<?--
This file is part of Prescription Tracker
apps/meds/views/medication_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The form that adds or changes a medication of the catalog.
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
  <p>Enter a brand name, a generic name, or both.</p>
  <?= render('_field', { name = 'brand_name', label = 'Brand name', value = typed.brand_name,
        err = errors.brand_name, maxlength = 200,
        suggestions = known.brand_names }) ?>
  <?= render('_field', { name = 'generic_name', label = 'Generic name', value = typed.generic_name,
        err = errors.generic_name, maxlength = 200,
        suggestions = known.generic_names }) ?>
  <?= render('_field', { name = 'strength', label = 'Strength', value = typed.strength,
        err = errors.strength, maxlength = 60,
        help = 'As the label prints it, with the unit: 10 mg, 100 units/mL, or 875-125 mg for a product with two drugs.',
        suggestions = known.strengths }) ?>

  <?= render('_choice', { name = 'route', legend = 'Route', value = typed.route,
        typed_new = typed.route_new, offered = offered.route, err = errors.route }) ?>
  <?= render('_choice', { name = 'dose_form', legend = 'Form', value = typed.dose_form,
        typed_new = typed.dose_form_new, offered = offered.dose_form, err = errors.dose_form }) ?>
  <?= render('_field', { name = 'package_size', label = 'Package size', value = typed.package_size,
        err = errors.package_size, maxlength = 40,
        suggestions = known.package_sizes }) ?>
  <?= render('_choice', { name = 'package_type', legend = 'Package type', value = typed.package_type,
        typed_new = typed.package_type_new, offered = offered.package_type,
        err = errors.package_type }) ?>

  <fieldset>
    <legend>Specialty</legend>
    <label for="f-is_specialty">
      <input id="f-is_specialty" name="is_specialty" type="checkbox" value="yes"
             aria-describedby="f-is_specialty-help"<? if typed.is_specialty == 'yes' then ?> checked<? end ?>>
      This is a specialty medication
    </label>
    <p id="f-is_specialty-help" class="pv-help">A specialty medication takes longer to arrive, so its refill is due earlier.</p>
  </fieldset>

  <details<? if errors.rxcui then ?> open<? end ?>>
    <summary>Reference codes</summary>
    <?= render('_field', { name = 'rxcui', label = 'RxNorm identifier', value = typed.rxcui,
          err = errors.rxcui, inputmode = 'numeric', maxlength = 8,
          help = 'The number that RxNorm, the drug list of the United States National Library of Medicine, gives this product. It is also called the RxCUI. Leave it empty if you do not know it.' }) ?>
  </details>

  <?= render('_field', { name = 'short_name', label = 'Short name', value = typed.short_name,
        err = errors.short_name, maxlength = 200,
        help = 'The name the app shows everywhere. Leave it empty, and the app builds it from the brand name, the generic name and the strength.' }) ?>

  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/setup/catalog') ?>">Cancel</a>
  </p>
</form>
