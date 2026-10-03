<?--
This file is part of Prescription Tracker
apps/meds/views/plans.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-01
Last Modified: 2026-10-03
Summary: Lists the payers and their refill overrides.
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
<h1>Insurance plans</h1>
<?= render('_notice', { notice = notice }) ?>
<p>Each plan sets how early a refill can be paid. Leave a setting empty to use the number from Reminder settings.</p>
<p><a class="pv-btn pv-btn-primary" href="<?= url('/setup/plans/new') ?>"><?= icon('plus-lg') ?> Add an insurance plan</a></p>
<? if #plans == 0 then ?>
  <p class="pv-empty">No plan is recorded.</p>
<? else ?>
  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Insurance plans and refill rules</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Plan</th>
      <th scope="col" role="columnheader">Early fill percent</th>
      <th scope="col" role="columnheader">Supply frame days</th>
      <th scope="col" role="columnheader">Actions</th>
    </tr></thead>
    <tbody role="rowgroup">
      <? for _, plan in ipairs(plans) do ?>
        <tr role="row">
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Plan</span><?= plan.name ?></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Early fill percent</span><?= plan.early_fill_percent or 'Household default' ?></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Supply frame days</span><?= plan.supply_frame_days or 'Household default' ?></td>
          <td role="cell"><a class="pv-btn" href="<?= url('/setup/plans/' .. plan.id .. '/edit') ?>">Change<span class="pv-visually-hidden"> <?= plan.name ?></span></a>
            <a class="pv-btn" href="<?= url('/setup/plans/' .. plan.id .. '/remove') ?>">Remove<span class="pv-visually-hidden"> <?= plan.name ?></span></a></td>
        </tr>
      <? end ?>
    </tbody>
  </table>
<? end ?>
