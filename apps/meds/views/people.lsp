<?--
This file is part of Prescription Tracker
apps/meds/views/people.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
Summary: The list of the people of the household.
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
<p><a href="<?= url('/setup') ?>">Back to Setup</a></p>
<h1>Family</h1>
<?= render('_notice', { notice = notice }) ?>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/setup/people/new') ?>"><?= icon('plus-lg') ?> Add a family member</a>
</p>

<? if #people == 0 then ?>
  <p class="pv-empty">No one is in the family yet. Add the first person to begin.</p>
<? else ?>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">The people of the household, by name</caption>
    <thead role="rowgroup">
      <tr role="row">
        <th scope="col" role="columnheader">Name</th>
        <th scope="col" role="columnheader">Birth date</th>
        <th scope="col" role="columnheader">Actions</th>
      </tr>
    </thead>
    <tbody role="rowgroup">
    <? for _, person in ipairs(people) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Name</span><?= person.display_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Birth date</span>
          <? if person.birth_date then ?><?= fmt.date(person.birth_date) ?><? else ?>Not given<? end ?></td>
        <td role="cell" class="meds-row-actions">
          <a class="pv-btn" href="<?= url('/setup/people/' .. person.id .. '/edit') ?>"><?= icon('pencil') ?> Change<span class="pv-visually-hidden"> <?= person.display_name ?></span></a>
          <a class="pv-btn" href="<?= url('/setup/people/' .. person.id .. '/remove') ?>"><?= icon('trash') ?> Remove<span class="pv-visually-hidden"> <?= person.display_name ?></span></a>
        </td>
      </tr>
    <? end ?>
    </tbody>
  </table>
<? end ?>
