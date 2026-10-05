<?--
This file is part of Prescription Tracker
apps/meds/views/_people_filter.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-05
Summary: The row of links that narrows a list to one person. Hidden when the household has
         one person or none.
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

<? if #filter.people > 1 then ?>
  <? -- person_tab.js, loaded from the manifest, remembers the tab chosen last in the
     -- browser. The Everyone link names an empty person on purpose, so the script knows
     -- it was chosen and leaves it. ?>
  <nav aria-label="Show one person" data-person-filter>
    <ul class="pv-subnav meds-filter">
      <li><a href="<?= url(base .. '?person=') ?>"<? if filter.id == '' then ?> aria-current="true"<? end ?>>Everyone</a></li>
      <? for _, person in ipairs(filter.people) do ?>
        <li><a href="<?= url(base .. '?person=' .. person.id) ?>"<? if filter.id == person.id then ?> aria-current="true"<? end ?>><?= person.display_name ?></a></li>
      <? end ?>
    </ul>
  </nav>
<? end ?>
