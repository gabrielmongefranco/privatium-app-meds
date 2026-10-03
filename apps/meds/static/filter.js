/*
This file is part of Prescription Tracker
apps/meds/static/filter.js
Author(s): Gabriel Mongefranco
Created: 2026-10-03
Last Modified: 2026-10-03
Summary: Filters the rows of the Medications page while a person types, hides the status
         groups that have no match, and opens the closed section of medications no longer
         taken when a match is inside it. The server does the same when the form is sent.
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
*/
(function () {
  'use strict';

  // A page can load this file more than once. The second copy does nothing.
  if (window.medsFilterLoaded) { return; }
  window.medsFilterLoaded = true;

  // The same key as the server builds: lower case, with punctuation as spaces.
  function keyOf(value) {
    return String(value || '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
  }

  function wordsOf(value) {
    var key = keyOf(value);
    return key === '' ? [] : key.split(' ');
  }

  function apply(input) {
    var words = wordsOf(input.value);
    var rows = document.querySelectorAll('tr[data-search]');
    var shown = 0;
    for (var index = 0; index < rows.length; index += 1) {
      var row = rows[index];
      var searched = ' ' + row.getAttribute('data-search') + ' ';
      var matches = words.every(function (word) { return searched.indexOf(word) !== -1; });
      row.hidden = !matches;
      if (matches) { shown += 1; }
    }
    // A group with no row left is hidden with its heading.
    var groups = document.querySelectorAll('[data-filter-group]');
    for (var place = 0; place < groups.length; place += 1) {
      var group = groups[place];
      var visible = group.querySelectorAll('tr[data-search]:not([hidden])').length;
      group.hidden = words.length > 0 && visible === 0;
      // A match among the medications no longer taken is shown, not hidden in a
      // closed section.
      if (words.length > 0 && visible > 0 && group.tagName === 'DETAILS') { group.open = true; }
    }
    var status = document.querySelector('[data-filter-status]');
    if (status) {
      status.textContent = words.length === 0 ? '' :
        shown + (shown === 1 ? ' medication matches.' : ' medications match.');
    }
  }

  function start() {
    var input = document.querySelector('[data-filter-input]');
    if (!input) { return; }
    var timer = null;
    input.addEventListener('input', function () {
      window.clearTimeout(timer);
      timer = window.setTimeout(function () { apply(input); }, 150);
    });
    if (input.value !== '') { apply(input); }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
}());
