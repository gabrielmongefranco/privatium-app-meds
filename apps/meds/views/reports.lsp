<?--
This file is part of Prescription Tracker
apps/meds/views/reports.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: The Reports tab of the History section: a bar chart of what was paid each year
         with its average line, the same totals by person in a table, and the
         link to the printable spending report. Everything follows the history filters.
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
<h1>History</h1>
<?= render('_history_tabs', { tabs = tabs }) ?>
<?= render('_people_filter', { filter = filter, base = '/fills/reports', keep = keep }) ?>

<?= render('_history_filters', { chosen = chosen, path = '/fills/reports', is_narrowed = is_narrowed, live = false }) ?>

<h2>Paid by year</h2>
<? if not chart then ?>
  <p class="pv-empty">No fills found.</p>
<? else ?>
  <p class="pv-meta"><?= total.counted ?>. Total paid: <?= render('_money', { amount = total.amount_paid, missing = 'not given' }) ?>.</p>
  <figure class="meds-chart">
    <? -- Drawn on the server; the table below holds every number of the chart as text. ?>
    <svg class="meds-chart-drawing" viewBox="0 0 <?= chart.width ?> <?= chart.height ?>" role="img" focusable="false" aria-labelledby="meds-chart-title meds-chart-desc">
      <title id="meds-chart-title">Total paid each year</title>
      <desc id="meds-chart-desc"><?= chart.description ?></desc>
      <? for _, tick in ipairs(chart.ticks) do ?>
        <line class="meds-chart-grid" x1="<?= chart.plot_left ?>" x2="<?= chart.plot_right ?>" y1="<?= tick.y ?>" y2="<?= tick.y ?>"/>
        <text class="meds-chart-axis" x="<?= tick.label_x ?>" y="<?= tick.label_y ?>" text-anchor="end"><?= tick.label ?></text>
      <? end ?>
      <? for _, bar in ipairs(chart.bars) do ?>
        <rect class="meds-chart-bar<? if bar.is_partial then ?> meds-chart-bar-partial<? end ?>" x="<?= bar.x ?>" y="<?= bar.y ?>" width="<?= bar.width ?>" height="<?= bar.height ?>"/>
        <text class="meds-chart-value" x="<?= bar.center ?>" y="<?= bar.value_y ?>" text-anchor="middle"><?= bar.value_label ?></text>
        <text class="meds-chart-year" x="<?= bar.center ?>" y="<?= bar.year_y ?>" text-anchor="middle"><?= bar.year_label ?></text>
      <? end ?>
      <? if chart.average then ?>
        <line class="meds-chart-average" x1="<?= chart.average.x1 ?>" x2="<?= chart.average.x2 ?>" y1="<?= chart.average.y ?>" y2="<?= chart.average.y ?>"/>
      <? end ?>
    </svg>
    <figcaption>
      <ul class="meds-chart-legend">
        <li><svg aria-hidden="true" focusable="false" width="28" height="14" viewBox="0 0 28 14"><rect class="meds-chart-bar" x="4" y="1" width="20" height="12"/></svg>
          Bars: the total paid in each year.<? if chart.has_partial then ?> The outlined bar is the year so far.<? end ?></li>
        <? if chart.average then ?>
          <li><svg aria-hidden="true" focusable="false" width="28" height="14" viewBox="0 0 28 14"><line class="meds-chart-average" x1="0" x2="28" y1="7" y2="7"/></svg>
            Dashed line: the average of the full years, <?= chart.average.label ?> a year.</li>
        <? else ?>
          <li>The average line needs at least two full years of fills.</li>
        <? end ?>
      </ul>
    </figcaption>
  </figure>

  <table class="pv-records" role="table">
    <caption class="pv-visually-hidden">Total paid by each person in each year</caption>
    <thead role="rowgroup"><tr role="row">
      <th scope="col" role="columnheader">Year</th>
      <th scope="col" role="columnheader">Person</th>
      <th scope="col" role="columnheader">Fills</th>
      <th scope="col" role="columnheader">Total paid</th>
    </tr></thead>
    <tbody role="rowgroup">
    <? for _, row in ipairs(spending) do ?>
      <tr role="row">
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Year</span><?= row.year ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Person</span><?= row.person_name ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Fills</span><?= row.fills ?></td>
        <td role="cell"><span class="pv-cell-label" aria-hidden="true">Total paid</span><?= render('_money', { amount = row.amount_paid }) ?></td>
      </tr>
    <? end ?>
    </tbody>
  </table>
<? end ?>

<h2>Printable report</h2>
<p>The printable report lists every fill under the filters above, with totals by person, by
  year and by medication. Use it for a flexible spending account (FSA) or health savings
  account (HSA) claim, for taxes, or for your own records.</p>
<p class="pv-actions">
  <a class="pv-btn pv-btn-primary" href="<?= printable ?>" target="_blank" rel="noopener"><?= icon('printer') ?> Printable report (opens in a new tab)</a>
</p>
