<?--
This file is part of Prescription Tracker
apps/meds/views/pharmacy_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The form that adds or changes a pharmacy.
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
  <?= render('_field', { name = 'name', label = 'Name', value = typed.name, err = errors.name,
        required = true, maxlength = 120 }) ?>
  <?= render('_contact_fields', { typed = typed, errors = errors }) ?>

  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= url('/contacts') ?>">Cancel</a>
  </p>
</form>
