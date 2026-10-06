<?--
This file is part of Medication Tracker
apps/meds/views/person_form.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-04
Summary: The form that adds or changes a person.
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

<form method="post" action="<?= action ?>">
  <?= csrf() ?>
  <? if typed.back then ?><input type="hidden" name="back" value="<?= typed.back ?>"><? end ?>
  <?= render('_field', { name = 'display_name', label = 'Name', value = typed.display_name,
        err = errors.display_name, required = true, maxlength = 120,
        help = 'The name the app shows for this person. A first name is enough.' }) ?>
  <?= render('_field', { name = 'birth_date', label = 'Birth date', value = typed.birth_date,
        err = errors.birth_date, input_type = 'date', max = today,
        help = 'A pharmacy asks for it at pickup. It also prints on the medication list.' }) ?>

  <?= render('_select_or_new', { name = 'plan_id', legend = 'Insurance plan', noun = 'plan',
        value = typed.plan_id, typed_new = typed.plan_id_new, options = plans,
        err = errors.plan_id, empty_label = 'No plan',
        help = 'The plan this person uses now. New fills start with it.' }) ?>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('check-lg') ?> Save</button>
    <a class="pv-btn" href="<?= back ?>">Cancel</a>
  </p>
</form>
