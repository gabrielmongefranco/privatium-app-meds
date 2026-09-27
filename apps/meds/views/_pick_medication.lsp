<?--
This file is part of Prescription Tracker
apps/meds/views/_pick_medication.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The results of a medication search, each with a link that chooses it. Close names
         are shown apart, as questions.
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

<? if filter ~= '' and #found.matches == 0 and #found.close == 0 then ?>
  <p class="pv-empty">No medication answers to "<?= filter ?>".</p>
<? end ?>
<? if #found.matches > 0 then ?>
  <h2>Medications that answer to "<?= filter ?>"</h2>
  <ul class="meds-cards">
    <? for _, medication in ipairs(found.matches) do ?>
      <li class="pv-card">
        <h3><?= medication.short_name ?></h3>
        <p class="pv-meta"><?= medication.full_name ?></p>
        <p class="pv-actions"><a class="pv-btn" href="<?= url(base .. medication.medication_id) ?>">Choose<span class="pv-visually-hidden"> <?= medication.short_name ?></span></a></p>
      </li>
    <? end ?>
  </ul>
<? end ?>
<? if #found.close > 0 then ?>
  <h2>Did you mean one of these?</h2>
  <p>These names are close to "<?= filter ?>", and none is the same. Different medications
     can have names that look alike, so check the name before you choose.</p>
  <ul class="meds-cards">
    <? for _, medication in ipairs(found.close) do ?>
      <li class="pv-card">
        <h3><?= medication.short_name ?></h3>
        <p class="pv-meta"><?= medication.full_name ?></p>
        <p class="pv-actions"><a class="pv-btn" href="<?= url(base .. medication.medication_id) ?>">Choose<span class="pv-visually-hidden"> <?= medication.short_name ?></span></a></p>
      </li>
    <? end ?>
  </ul>
<? end ?>
