<?--
This file is part of Prescription Tracker
apps/meds/views/_history_tabs.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: The tabs of the History section: Fill history and Reports. Parameters: tabs, as
         history_filter.tabs returns them.
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

<nav aria-label="History pages">
  <ul class="pv-subnav meds-tabs">
    <? for _, tab in ipairs(tabs) do ?>
      <li><a href="<?= tab.href ?>"<? if tab.is_current then ?> aria-current="page"<? end ?>><?= tab.label ?></a></li>
    <? end ?>
  </ul>
</nav>
