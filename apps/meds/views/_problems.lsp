<?--
This file is part of Medication Tracker
apps/meds/views/_problems.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The list of problems at the top of a form that was refused. Each entry links to its
         field. The list takes the focus when the page loads, so it is read first.
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

<? if #problems > 0 then ?>
  <div class="pv-notice pv-notice-alert meds-problems" tabindex="-1" autofocus>
    <?= icon('exclamation-triangle') ?>
    <div>
      <h2>Check these fields</h2>
      <ul>
        <? for _, problem in ipairs(problems) do ?>
          <li><a href="#f-<?= problem.field ?>"><?= problem.message ?></a></li>
        <? end ?>
      </ul>
    </div>
  </div>
<? end ?>
