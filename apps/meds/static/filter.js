/*
This file is part of Prescription Tracker
apps/meds/static/filter.js
Author(s): Gabriel Mongefranco
Created: 2026-10-03
Last Modified: 2026-10-05
Summary: Filters the rows of the Medications page and the Fill history while a person types,
         hides the status groups that have no match, and opens the closed section of
         medications no longer taken when a match is inside it. The server does the same when
         the form is sent.
         The script loads once for the whole app and listens on the document, so it works
         on every page that is swapped in without a reload.
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

  // The frame loads this file once in the head; a second copy does nothing.
  if (window.medsFilterLoaded) { return; }
  window.medsFilterLoaded = true;

  var TYPING_PAUSE_MILLISECONDS = 150;   // Typing pauses this long before the rows are filtered

  // The same key as the server builds: lower case, with punctuation as spaces.
  function keyOf(value) {
    return String(value || '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
  }

  function wordsOf(value) {
    var key = keyOf(value);
    return key === '' ? [] : key.split(' ');
  }

  // A row may stand in a group with rows of its own, such as a fill and its note; the
  // whole group is shown or hidden with it.
  function targetOf(row) {
    return (row.closest && row.closest('[data-search-group]')) || row;
  }

  // The words of the count: data-filter-noun="fill|fills" on the status line, or
  // medications when it says nothing.
  function countText(status, shown) {
    var nouns = (status.getAttribute('data-filter-noun') || 'medication|medications').split('|');
    var words = shown + ' ' + (shown === 1 ? nouns[0] + ' matches' : nouns[1] + ' match');
    // Rows on other pages were never sent, so the count covers this page only.
    if (status.hasAttribute('data-filter-paged')) {
      return words + ' on this page. Choose Find to search every page.';
    }
    return words + '.';
  }

  function apply(input) {
    var words = wordsOf(input.value);
    var rows = document.querySelectorAll('tr[data-search]');
    var shown = 0;
    for (var index = 0; index < rows.length; index += 1) {
      var row = rows[index];
      var searched = ' ' + row.getAttribute('data-search') + ' ';
      var matches = words.every(function (word) { return searched.indexOf(word) !== -1; });
      targetOf(row).hidden = !matches;
      if (matches) { shown += 1; }
    }
    // A group with no row left is hidden with its heading.
    var groups = document.querySelectorAll('[data-filter-group]');
    for (var place = 0; place < groups.length; place += 1) {
      var group = groups[place];
      var inside = group.querySelectorAll('tr[data-search]');
      var visible = 0;
      for (var at = 0; at < inside.length; at += 1) {
        if (!targetOf(inside[at]).hidden) { visible += 1; }
      }
      group.hidden = words.length > 0 && visible === 0;
      // A match among the medications no longer taken is shown, not hidden in a
      // closed section.
      if (words.length > 0 && visible > 0 && group.tagName === 'DETAILS') { group.open = true; }
    }
    var status = document.querySelector('[data-filter-status]');
    if (status) {
      status.textContent = words.length === 0 ? '' : countText(status, shown);
    }
  }

  // One listener on the document serves every search box that is ever on the page. The
  // debounce timer is kept on the box itself, so a box that is swapped away takes its
  // timer with it.
  document.addEventListener('input', function (event) {
    var input = event.target;
    if (!input.matches || !input.matches('[data-filter-input]')) { return; }
    window.clearTimeout(input.medsFilterTimer);
    input.medsFilterTimer = window.setTimeout(function () { apply(input); }, TYPING_PAUSE_MILLISECONDS);
  });

  // A page that arrives with words in its box, from the first load or from a swap, shows
  // the rows those words match. Filtering only hides rows, so running it again is harmless.
  document.addEventListener('htmx:load', function (event) {
    var root = event.detail && event.detail.elt ? event.detail.elt : document;
    var input = root.querySelector ? root.querySelector('[data-filter-input]') : null;
    if (input && input.value !== '') { apply(input); }
  });
}());
