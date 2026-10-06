<?--
This file is part of Medication Tracker
apps/meds/views/_choice.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: One choice of a form: a drop-down and a box to type a new choice, in one group.
         The box wins when both are filled in.
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
  -- something was typed into it or the choice to add was made, the drop-down otherwise.
  local adding = value == 'new' or (typed_new ~= nil and typed_new ~= '')
  local in_box = err and adding
  local in_list = err and not in_box
?>
<fieldset class="meds-choice" id="f-<?= name ?>">
  <legend><?= legend ?> <span class="meds-optional">(optional)</span></legend>
  <label for="f-<?= name ?>-list">Choose from the list</label>
  <select id="f-<?= name ?>-list" name="<?= name ?>"<? if in_list then ?> aria-invalid="true" aria-describedby="f-<?= name ?>-err"<? end ?>>
    <option value="">None</option>
    <option value="new"<? if adding then ?> selected<? end ?>>-- Add new --</option>
    <? for _, choice in ipairs(offered) do ?>
      <option value="<?= choice ?>"<? if not adding and choice == value then ?> selected<? end ?>><?= choice ?></option>
    <? end ?>
  </select>
  <? -- With a script, the box shows only after the choice to add. Without one, it is always there. ?>
  <div data-show-when="<?= name ?>=new">
    <label for="f-<?= name ?>-new">The new choice</label>
    <input id="f-<?= name ?>-new" name="<?= name ?>_new" type="text" value="<?= typed_new ?>"
           autocomplete="off" maxlength="60"<? if in_box then ?> aria-invalid="true" aria-describedby="f-<?= name ?>-err"<? end ?>>
  </div>
  <? if err then ?>
    <p id="f-<?= name ?>-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
  <? end ?>
</fieldset>
