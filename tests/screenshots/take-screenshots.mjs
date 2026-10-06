/*
This file is part of Medication Tracker
tests/screenshots/take-screenshots.mjs
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: Loads the invented household of tests/fixtures/sample-household.json into a
         temporary node and drives a headless Firefox over WebDriver BiDi to save one
         PNG per screen for the documentation, plus the repository preview images.
         take-screenshots.sh starts the node and the browser and runs this script.
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

Usage: node take-screenshots.mjs <node base URL> <BiDi port> <fixture file> <output folder>
       <preview folder>
Exit codes: 0 every screenshot was saved, 1 a page or a load failed.
*/

import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

// ### Load Configuration ###
const [, , base, bidiPort, fixturePath, outputFolder, previewFolder] = process.argv;
const APP = base + '/a/meds';
const DESKTOP = { width: 1200, height: 900 };
const PHONE = { width: 390, height: 844 };
const MAX_HEIGHT = 2000;          // Taller pages are cut here so each image stays small
const WAIT_STEPS = 80;            // Times 100 ms: how long to wait for a page to settle
// The top of the desktop Refills page, from the title bar to the summary, in CSS pixels.
// It is drawn at the exact sizes the repository preview images need, never stretched.
const PREVIEW_BOX = { x: 96, y: 0, width: 994 };
const PREVIEWS = [
  { name: 'Repo-preview', width: 912, height: 512 },
  { name: 'Repo-preview-thumb', width: 360, height: 202 },
];

// ### Read The Fixture ###
const fixture = JSON.parse(await readFile(fixturePath, 'utf8'));

// Dates are written as offsets from today, so every Refills group has rows on any day.
function localDate(offsetDays) {
  const day = new Date();
  day.setDate(day.getDate() + offsetDays);
  const pad = n => String(n).padStart(2, '0');
  return { iso: `${day.getFullYear()}-${pad(day.getMonth() + 1)}-${pad(day.getDate())}`,
           us: `${pad(day.getMonth() + 1)}/${pad(day.getDate())}/${day.getFullYear()}` };
}
function resolveDates(fields) {
  const out = {};
  for (const [key, value] of Object.entries(fields)) {
    out[key] = value && typeof value === 'object' && 'days_from_today' in value
      ? localDate(value.days_from_today).iso : value;
  }
  return out;
}
const events = fixture.records.map(r => ({ op: 'put', tbl: r.table, id: r.id, d: resolveDates(r.fields) }));
const pastedText = fixture.portal_sample.text.replace(/\{\{days_from_today:(-?\d+)\}\}/g, (_, n) => localDate(Number(n)).us);

// ### Load The Household ###
// Opening the catalog loads the starter catalog, which the fixture's products point to.
const catalog = await fetch(APP + '/setup/catalog');
if (!catalog.ok) { console.error(`screenshots: the catalog page answered ${catalog.status}`); process.exit(1); }
const loaded = await fetch(APP + '/api/events', {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ events }),
});
if (!loaded.ok) { console.error(`screenshots: the fixture was refused: ${loaded.status} ${await loaded.text()}`); process.exit(1); }
console.log(`loaded ${events.length} invented records`);

// ### Connect To Firefox ###
const ws = new WebSocket(`ws://127.0.0.1:${bidiPort}/session`);
let lastId = 0;
const pending = new Map();
ws.onmessage = event => {
  const msg = JSON.parse(event.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
};
await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
const send = (method, params = {}) => new Promise((resolve, reject) => {
  const n = ++lastId;
  pending.set(n, msg => (msg.type === 'error' ? reject(new Error(`${method}: ${msg.error} ${msg.message}`)) : resolve(msg.result)));
  ws.send(JSON.stringify({ id: n, method, params }));
});
await send('session.new', { capabilities: {} });
const { contexts } = await send('browsingContext.getTree', {});
const context = contexts[0].context;

const sleep = ms => new Promise(r => setTimeout(r, ms));
const run = async expression => {
  const out = await send('script.evaluate', { expression, target: { context }, awaitPromise: true, resultOwnership: 'none' });
  if (out.type === 'exception') throw new Error(out.exceptionDetails.text);
  return out.result.value;
};
const until = async (expression, what) => {
  for (let i = 0; i < WAIT_STEPS; i++) {
    try { if (await run(expression)) return; } catch { /* The document may be changing. */ }
    await sleep(100);
  }
  throw new Error('timed out waiting for ' + what);
};
const go = async (path, heading) => {
  await send('browsingContext.navigate', { context, url: APP + path, wait: 'complete' });
  await until(`document.querySelector('#main h1')?.textContent.includes(${JSON.stringify(heading)})`, heading);
};
const viewport = size => send('browsingContext.setViewport', { context, viewport: size });

// Saves the whole page, cut at MAX_HEIGHT, as <name>.png in the output folder.
const saved = [];
async function shot(name) {
  await sleep(300);
  const height = Math.min(await run('document.documentElement.scrollHeight'), MAX_HEIGHT);
  const width = await run('document.documentElement.clientWidth');
  const { data } = await send('browsingContext.captureScreenshot', {
    context, origin: 'document', clip: { type: 'box', x: 0, y: 0, width, height } });
  await writeFile(join(outputFolder, name + '.png'), Buffer.from(data, 'base64'));
  saved.push(name);
  console.log(`saved ${name}.png`);
}

// Saves the PREVIEW_BOX at each preview size. A smaller pixel ratio shrinks the drawing
// instead of the layout, so the text stays sharp and the page looks as it does on screen.
// The clip gets a quarter pixel more on each side, since Firefox rounds the image size down.
async function previews() {
  for (const { name, width, height } of PREVIEWS) {
    const ratio = width / PREVIEW_BOX.width;
    await send('browsingContext.setViewport', { context, viewport: DESKTOP, devicePixelRatio: ratio });
    await sleep(300);
    const { data } = await send('browsingContext.captureScreenshot', {
      context, origin: 'document',
      clip: { type: 'box', ...PREVIEW_BOX, width: (width + 0.25) / ratio, height: (height + 0.25) / ratio } });
    await writeFile(join(previewFolder, name + '.png'), Buffer.from(data, 'base64'));
    console.log(`saved ${name}.png in ${previewFolder}`);
  }
  await send('browsingContext.setViewport', { context, viewport: DESKTOP, devicePixelRatio: 1 });
}

// ### Take The Screenshots ###
const ALEX = '01J9SAMPXE0000000000000003';
const LIPITOR = '01J9SAMPXE0000000000000012';
try {
  await viewport(DESKTOP);
  await go('/', 'Medications');
  await run('localStorage.clear(); true');
  await go('/', 'Medications');
  await shot('medications');

  await go('/medications/' + LIPITOR, 'Lipitor');
  await shot('medication-page');

  await go('/medications/new', 'Track');
  await run(`(() => { const box = document.querySelector('[data-search-term]');
    box.value = 'lisinopril'; document.querySelector('[data-search-find]').click(); return true; })()`);
  await until(`document.querySelectorAll('#main input[type=checkbox][name^="pick_"]').length > 0`, 'search results');
  await shot('track-new-medication');

  await go('/refills', 'Refills');
  await shot('refills');
  await previews();

  await go('/fills/new?entry=' + LIPITOR, 'fill');
  await shot('record-fill');

  await go('/fills/paste', 'Copy');
  await run(`(() => { const who = document.querySelector('select[name="person_id"]');
    who.value = ${JSON.stringify(fixture.portal_sample.person_id)};
    document.querySelector('textarea[name="pasted"]').value = ${JSON.stringify(pastedText)}; return true; })()`);
  await shot('copy-refill-history');
  await run(`document.querySelector('textarea[name="pasted"]').form.requestSubmit(); true`);
  await until(`!document.querySelector('textarea[name="pasted"]') && document.querySelector('#main h1')`, 'paste review');
  await shot('copy-refill-history-review');

  await go('/fills', 'History');
  await shot('history');

  await go('/fills/reports', 'History');
  await shot('reports');

  await go(`/fills/reports/print?person=${ALEX}`, 'spending report');
  await shot('printable-report');

  await go('/authorizations', 'Prior authorizations');
  await shot('authorizations');

  await go('/setup', 'Setup');
  await shot('setup');

  await go('/setup/reminders', 'Reminder');
  await shot('reminder-settings');

  await go('/setup/plans', 'Insurance');
  await shot('insurance-plans');

  await go(`/people/${ALEX}/medication-list`, 'Alex Example');
  await shot('printable-list');

  await viewport(PHONE);
  await go('/refills', 'Refills');
  await shot('refills-phone');
} catch (error) {
  console.error(`screenshots: ${error.message}`);
  process.exit(1);
}
console.log(`${saved.length} screenshots saved in ${outputFolder}`);
process.exit(0);
