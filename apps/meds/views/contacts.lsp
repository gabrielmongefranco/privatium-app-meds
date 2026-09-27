<?--
This file is part of Prescription Tracker
apps/meds/views/contacts.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The Contacts page: the pharmacies and the prescribers, with their details.
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
<h1>Contacts</h1>
<?= render('_notice', { notice = notice }) ?>

<h2 id="pharmacies">Pharmacies</h2>
<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/contacts/pharmacies/new') ?>"><?= icon('plus-lg') ?> Add a pharmacy</a>
</p>
<? if #pharmacies == 0 then ?>
  <p class="pv-empty">No pharmacy is in the app yet.</p>
<? else ?>
  <ul class="meds-cards">
    <? for _, pharmacy in ipairs(pharmacies) do ?>
      <?= render('_contact', { contact = pharmacy, path = '/contacts/pharmacies' }) ?>
    <? end ?>
  </ul>
<? end ?>

<h2 id="prescribers">Prescribers</h2>
<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/contacts/prescribers/new') ?>"><?= icon('plus-lg') ?> Add a prescriber</a>
</p>
<? if #prescribers == 0 then ?>
  <p class="pv-empty">No prescriber is in the app yet.</p>
<? else ?>
  <ul class="meds-cards">
    <? for _, prescriber in ipairs(prescribers) do ?>
      <?= render('_contact', { contact = prescriber, path = '/contacts/prescribers' }) ?>
    <? end ?>
  </ul>
<? end ?>
