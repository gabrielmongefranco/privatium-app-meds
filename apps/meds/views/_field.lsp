<?--
This file is part of Medication Tracker
apps/meds/views/_field.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-05
Summary: One labeled field of a form, with its help text, its problem, and the values
         it suggests while a person types. Values are escaped by the output tag, so
         typed markup is shown and never run. A field that is not required is marked
         optional unless optional_mark is false, for a box that always holds a value.
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
  -- The ids of the help text and of the problem, for the field to point at.
  local described = {}
  if help then described[#described + 1] = 'f-' .. name .. '-help' end
  if err then described[#described + 1] = 'f-' .. name .. '-err' end
  -- Values already in use, offered while a person types. The field accepts any text.
  local offered = suggestions or {}
?>
<label for="f-<?= name ?>"><?= label ?><? if not required and optional_mark ~= false then ?> <span class="meds-optional">(optional)</span><? end ?></label>
<input id="f-<?= name ?>" name="<?= name ?>" type="<?= input_type or 'text' ?>" value="<?= value ?>"
       autocomplete="off"
       <? if maxlength then ?>maxlength="<?= maxlength ?>"<? end ?>
       <? if inputmode then ?>inputmode="<?= inputmode ?>"<? end ?>
       <? if max then ?>max="<?= max ?>"<? end ?>
       <? if #offered > 0 then ?>list="f-<?= name ?>-suggestions"<? end ?>
       <? if required then ?>required<? end ?>
       <? if err then ?>aria-invalid="true"<? end ?>
       <? if #described > 0 then ?>aria-describedby="<?= table.concat(described, ' ') ?>"<? end ?>>
<? if #offered > 0 then ?>
  <datalist id="f-<?= name ?>-suggestions">
    <? for _, suggestion in ipairs(offered) do ?><option value="<?= suggestion ?>"></option><? end ?>
  </datalist>
<? end ?>
<? if help then ?>
  <p id="f-<?= name ?>-help" class="pv-help"><?= help ?></p>
<? end ?>
<? if err then ?>
  <p id="f-<?= name ?>-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
<? end ?>
