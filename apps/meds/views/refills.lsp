<?--
This file is part of Prescription Tracker
apps/meds/views/refills.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
Summary: The Refills page: what needs attention now, most urgent first. Only a medication
         taken regularly raises an alert; the others show their dates without one.
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
<h1>Refills</h1>
<? if notice then ?>
  <p class="pv-notice pv-notice-info" role="status"><?= icon('check-circle') ?> <?= notice ?></p>
<? end ?>

<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= url('/fills/new' .. (filter.id ~= '' and ('?person=' .. filter.id) or '')) ?>"><?= icon('plus-lg') ?> Record a fill</a>
  <a class="pv-btn" href="<?= url('/fills/paste') ?>"><?= icon('clipboard-plus') ?> Copy refill history from patient portal</a>
</p>
<?= render('_people_filter', { filter = filter, base = '/' }) ?>

<? if alerts == 0 then ?>
  <p class="pv-notice pv-notice-info"><?= icon('check-circle') ?>
    <span>Nothing needs a refill.<? if next_row then ?> The next one is <?= next_row.medication_name ?> on <?= fmt.date(next_row.next_fill_on) ?>.<? end ?></span></p>
<? else ?>
  <h2>Summary</h2>
  <ul class="meds-summary">
    <? for _, group in ipairs(groups) do ?>
      <? if group.alert and #group.rows > 0 then ?>
        <li><a href="#<?= group.key ?>"><?= icon(group.icon) ?> <?= group.title ?>: <?= #group.rows ?></a></li>
      <? end ?>
    <? end ?>
    <? if #asking > 0 then ?>
      <li><a href="#asking"><?= icon('telephone') ?> New prescriptions to ask for: <?= #asking ?></a></li>
    <? end ?>
    <? for _, level in ipairs(levels) do ?>
      <? if #level.rows > 0 then ?>
        <li><a href="#authorizations"><?= icon(level.icon) ?> <?= level.title ?>: <?= #level.rows ?></a></li>
      <? end ?>
    <? end ?>
  </ul>
<? end ?>

<? for _, group in ipairs(groups) do ?>
  <? if #group.rows > 0 and group.key ~= 'not_due' then ?>
    <h2 id="<?= group.key ?>"><?= group.title ?></h2>
    <? if group.key == 'as_needed' then ?><p class="pv-help">Taken as needed. These dates are for reference only.</p><? end ?>
    <? if group.key == 'missing' then ?><p class="pv-help">Record a fill with a days supply, and the app can work out a refill date.</p><? end ?>
    <? if group.key == 'paused' then ?><p class="pv-help">On hold or not started. These dates are for reference only.</p><? end ?>
    <?= render('_refills_table', { rows = group.rows, alert = group.alert, caption = group.title }) ?>
  <? end ?>
  <? if group.key == 'due_soon' and #asking > 0 then ?>
    <h2 id="asking">New prescriptions to ask for</h2>
    <p class="pv-help">No refill is left, and the next fill is near. Ask the prescriber for a new prescription. Some prescribers take this request from the patient only.</p>
    <table class="pv-records" role="table">
      <caption class="pv-visually-hidden">Medications with no refill left whose next fill is near, soonest first</caption>
      <thead role="rowgroup"><tr role="row">
        <th scope="col" role="columnheader">Medication</th>
        <th scope="col" role="columnheader">For</th>
        <th scope="col" role="columnheader">Next fill</th>
        <th scope="col" role="columnheader">Ask</th>
      </tr></thead>
      <tbody role="rowgroup">
      <? for _, row in ipairs(asking) do ?>
        <tr role="row">
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span><?= render('_form_icon', { icon_name = row.form_icon, label = row.form_label }) ?> <a href="<?= url('/medications/' .. row.id) ?>"><?= row.medication_name ?></a>
            <span class="pv-meta meds-line"><?= row.status_label ?></span></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">For</span><?= row.person_name ?></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Next fill</span><span class="pv-badge pv-badge-warn"><?= icon('telephone') ?> No refills left</span>
            <? if row.status == 'taking_as_needed' then ?>
              <span class="pv-meta meds-line">Supply lasts until <?= fmt.date(row.lasts_until) ?></span>
            <? else ?>
              <span class="pv-meta meds-line"><?= row.phrase ?>
                <span class="meds-line">Next fill date <?= fmt.date(row.next_fill_on) ?></span>
                <span class="meds-line">Lasts until <?= fmt.date(row.lasts_until) ?></span></span>
            <? end ?></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Ask</span><?= row.prescriber_name or 'The prescriber' ?><? if row.prescriber_href then ?>: <a href="tel:<?= row.prescriber_href ?>"><?= row.prescriber_phone ?></a><? end ?></td>
        </tr>
      <? end ?>
      </tbody>
    </table>
  <? end ?>
  <? if group.key == 'due_soon' and #ending > 0 then ?>
    <h2 id="authorizations">Prior authorizations</h2>
    <p class="pv-help">An authorization that is due needs a new request now, so the insurer has time to decide.</p>
    <table class="pv-records" role="table">
      <caption class="pv-visually-hidden">Prior authorizations that have expired, are due or are due soon, soonest first</caption>
      <thead role="rowgroup"><tr role="row">
        <th scope="col" role="columnheader">Medication</th>
        <th scope="col" role="columnheader">For</th>
        <th scope="col" role="columnheader">Authorization</th>
        <th scope="col" role="columnheader">Expires on</th>
        <th scope="col" role="columnheader">Ask</th>
      </tr></thead>
      <tbody role="rowgroup">
      <? for _, level in ipairs(levels) do ?>
      <? for _, row in ipairs(level.rows) do ?>
        <tr role="row">
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Medication</span><a href="<?= url('/medications/' .. row.entry_id) ?>"><?= row.medication_name ?></a></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">For</span><?= row.person_name ?></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Authorization</span><span class="pv-badge <?= row.badge ?>"><?= icon(row.icon_name) ?> <? if row.level == 'due' then ?>Due<? elseif row.level == 'due_soon' then ?>Due soon<? else ?>Expired<? end ?></span>
            <span class="pv-meta meds-line"><?= row.phrase ?></span></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Expires on</span><?= fmt.date(row.valid_to) ?></td>
          <td role="cell"><span class="pv-cell-label" aria-hidden="true">Ask</span><?= row.prescriber_name or 'The prescriber' ?><? if row.prescriber_href then ?>: <a href="tel:<?= row.prescriber_href ?>"><?= row.prescriber_phone ?></a><? end ?></td>
        </tr>
      <? end ?>
      <? end ?>
      </tbody>
    </table>
  <? end ?>
<? end ?>

<? for _, group in ipairs(groups) do ?>
  <? if group.key == 'not_due' and #group.rows > 0 then ?>
    <details>
      <summary>Not due yet (<?= #group.rows ?>)</summary>
      <?= render('_refills_table', { rows = group.rows, alert = false, caption = 'Not due yet' }) ?>
    </details>
  <? end ?>
<? end ?>
