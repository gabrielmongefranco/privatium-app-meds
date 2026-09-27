<?--
This file is part of Prescription Tracker
apps/meds/views/setup.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The Setup page: one link to each thing a household sets up once and changes rarely.
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
<h1>Setup</h1>
<?= render('_notice', { notice = notice }) ?>

<ul class="pv-launcher meds-links">
  <li><a href="<?= url('/setup/people') ?>">
    <?= icon('people') ?>
    <span>People</span>
    <small>The members of the household. <?= counts.people ?> in the app.</small>
  </a></li>
  <li><a href="<?= url('/setup/catalog') ?>">
    <?= icon('capsule') ?>
    <span>Medication catalog</span>
    <small>Every product, with its other names. <?= counts.medications ?> in the app.</small>
  </a></li>
  <li><a href="<?= url('/setup/reminders') ?>">
    <?= icon('calendar-event') ?>
    <span>Reminder settings</span>
    <small>How many days ahead a refill counts as due.</small>
  </a></li>
</ul>
