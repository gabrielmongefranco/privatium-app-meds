<?--
This file is part of Medication Tracker
apps/meds/views/paste.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-04
Summary: The page where the text of a portal page is pasted.
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

<?= render('_nav', { section = section }) ?>
<h1>Copy refill history from patient portal</h1>
<?= render('_notice', { notice = notice }) ?>
<? if err then ?>
  <p id="paste-err" class="pv-error" role="alert"><?= icon('exclamation-triangle') ?> <?= err ?></p>
<? end ?>

<p>Use this screen to import your refill history from your patient, pharmacy or insurance
   portal. Medications will be automatically matched to your medication list and existing
   refills will be skipped, but you will be able to make edits before importing.</p>
<ol>
  <li>In the portal, open the details of each fill.</li>
  <li>Select the list, from the first date to the end of the last fill, and copy it.</li>
  <li>Paste it into the box below.</li>
</ol>

<? if #people == 0 then ?>
  <p class="pv-notice pv-notice-info"><?= icon('info-circle') ?> <span>Add a person first. A fill belongs to a person.</span></p>
  <p class="pv-actions"><a class="pv-btn" href="<?= url('/setup/people/new?back=history') ?>">Add a person</a></p>
<? else ?>
<form method="post" action="<?= url('/fills/paste/read') ?>" novalidate>
  <?= csrf() ?>
  <?= render('_select', { name = 'person_id', label = 'This refill history belongs to:', value = typed.person_id,
        options = people, required = true, empty_label = 'Choose a person' }) ?>
  <label for="f-pasted">Text of the portal page</label>
  <textarea id="f-pasted" name="pasted" class="meds-paste" required autocomplete="off" spellcheck="false"
            aria-describedby="f-pasted-help<? if err then ?> paste-err<? end ?>"><?= typed.pasted ?></textarea>
  <p id="f-pasted-help" class="pv-help">About 100 fills fit in one paste. Paste a longer list in parts.</p>
  <p class="pv-actions">
    <button type="submit" class="pv-btn pv-btn-primary"><?= icon('search') ?> Read the text</button>
    <a class="pv-btn" href="<?= url('/fills') ?>">Cancel</a>
  </p>
</form>
<? end ?>
