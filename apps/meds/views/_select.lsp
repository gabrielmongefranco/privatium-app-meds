<?--
This file is part of Prescription Tracker
apps/meds/views/_select.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: One labeled drop-down of a form, with its help text and its problem.
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
  local described = {}
  if help then described[#described + 1] = 'f-' .. name .. '-help' end
  if err then described[#described + 1] = 'f-' .. name .. '-err' end
?>
<label for="f-<?= name ?>"><?= label ?><? if not required then ?> <span class="meds-optional">(optional)</span><? end ?></label>
<select id="f-<?= name ?>" name="<?= name ?>"
        <? if required then ?>required<? end ?>
        <? if err then ?>aria-invalid="true"<? end ?>
        <? if #described > 0 then ?>aria-describedby="<?= table.concat(described, ' ') ?>"<? end ?>>
  <option value=""><?= empty_label or 'None' ?></option>
  <? for _, option in ipairs(options) do ?>
    <option value="<?= option.value ?>"<? if option.value == value then ?> selected<? end ?>><?= option.label ?></option>
  <? end ?>
</select>
<? if help then ?>
  <p id="f-<?= name ?>-help" class="pv-help"><?= help ?></p>
<? end ?>
<? if err then ?>
  <p id="f-<?= name ?>-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
<? end ?>
