<?--
This file is part of Prescription Tracker
apps/meds/views/_nav.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-04
Summary: The app's stylesheet and the navigation bar. Every page includes it first, so the
         bar sits in the same place on every page and marks the current section.
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

<link rel="stylesheet" href="<?= url('/static/meds.css') ?>">
<script src="<?= url('/static/forms.js') ?>" defer></script>
<nav aria-label="Prescription Tracker">
  <ul class="pv-subnav meds-nav">
    <li><a href="<?= url('/medications') ?>"<? if section == 'medications' then ?> aria-current="page"<? end ?>><?= icon('capsule') ?> Medications</a></li>
    <li><a href="<?= url('/refills') ?>"<? if section == 'home' then ?> aria-current="page"<? end ?>><?= icon('bag-plus-fill') ?> Refills</a></li>
    <li><a href="<?= url('/fills') ?>"<? if section == 'history' then ?> aria-current="page"<? end ?>><?= icon('clock-history') ?> History</a></li>
    <li><a href="<?= url('/authorizations') ?>"<? if section == 'authorizations' then ?> aria-current="page"<? end ?>><?= icon('shield-check') ?> Authorizations</a></li>
    <li><a href="<?= url('/setup') ?>"<? if section == 'setup' then ?> aria-current="page"<? end ?>><?= icon('gear') ?> Setup</a></li>
  </ul>
</nav>
