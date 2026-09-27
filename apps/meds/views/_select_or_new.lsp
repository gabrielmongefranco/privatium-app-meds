<?--
This file is part of Prescription Tracker
apps/meds/views/_select_or_new.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: One choice of a record: a drop-down and a box to add a new record by name, in
         one group. The box wins when both are filled in.
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

<?
  -- A problem belongs to the control that holds the refused value: the box when
  -- something was typed into it, the drop-down otherwise.
  local in_box = err and typed_new ~= nil and typed_new ~= ''
  local in_list = err and not in_box
?>
<fieldset class="meds-choice" id="f-<?= name ?>">
  <legend><?= legend ?><? if not required then ?> <span class="meds-optional">(optional)</span><? end ?></legend>
  <? if #options > 0 then ?>
    <label for="f-<?= name ?>-list">Choose from the list</label>
    <select id="f-<?= name ?>-list" name="<?= name ?>"<? if in_list then ?> aria-invalid="true" aria-describedby="f-<?= name ?>-err"<? end ?>>
      <option value=""><?= empty_label or 'None' ?></option>
      <? for _, option in ipairs(options) do ?>
        <option value="<?= option.value ?>"<? if option.value == value then ?> selected<? end ?>><?= option.label ?></option>
      <? end ?>
    </select>
  <? end ?>
  <label for="f-<?= name ?>-new"><? if #options > 0 then ?>Or add a new <?= noun ?><? else ?>Name of the <?= noun ?><? end ?></label>
  <input id="f-<?= name ?>-new" name="<?= name ?>_new" type="text" value="<?= typed_new ?>"
         autocomplete="off" maxlength="120" aria-describedby="f-<?= name ?>-help<? if in_box or (err and #options == 0) then ?> f-<?= name ?>-err<? end ?>"<? if in_box then ?> aria-invalid="true"<? end ?>>
  <p id="f-<?= name ?>-help" class="pv-help"><?= help or ('Type the name. Saving adds the ' .. noun .. ', and you can fill in the rest later.') ?></p>
  <? if err then ?>
    <p id="f-<?= name ?>-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
  <? end ?>
</fieldset>
