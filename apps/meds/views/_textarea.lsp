<?--
This file is part of Medication Tracker
apps/meds/views/_textarea.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-03
Last Modified: 2026-10-03
Summary: One labeled text area of a form, for notes of a few lines, with its help text and
         its problem. The value is escaped by the output tag, so typed markup is shown and
         never run.
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
<textarea id="f-<?= name ?>" name="<?= name ?>" class="meds-notes" rows="<?= rows or 3 ?>"
          autocomplete="off"
          <? if maxlength then ?>maxlength="<?= maxlength ?>"<? end ?>
          <? if required then ?>required<? end ?>
          <? if err then ?>aria-invalid="true"<? end ?>
          <? if #described > 0 then ?>aria-describedby="<?= table.concat(described, ' ') ?>"<? end ?>><?= value ?></textarea>
<? if help then ?>
  <p id="f-<?= name ?>-help" class="pv-help"><?= help ?></p>
<? end ?>
<? if err then ?>
  <p id="f-<?= name ?>-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
<? end ?>
