<?--
This file is part of Prescription Tracker
apps/meds/views/contact_list.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-04
Summary: The Prescribers page or the Pharmacies page under Setup: every record of the kind,
         each with its details, and the button that adds one.
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
<h1><?= heading ?></h1>
<?= render('_notice', { notice = notice }) ?>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url(path .. '/new') ?>"><?= icon('plus-lg') ?> <?= add_label ?></a>
</p>
<? if #contacts == 0 then ?>
  <p class="pv-empty"><?= empty ?></p>
<? else ?>
  <ul class="meds-cards">
    <? for _, contact in ipairs(contacts) do ?>
      <?= render('_contact', { contact = contact, path = path }) ?>
    <? end ?>
  </ul>
<? end ?>
