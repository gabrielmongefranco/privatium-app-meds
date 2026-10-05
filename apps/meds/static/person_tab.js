/*
This file is part of Prescription Tracker
apps/meds/static/person_tab.js
Author(s): Gabriel Mongefranco
Created: 2026-10-03
Last Modified: 2026-10-05
Summary: Remembers the person tab that was chosen last, in the local storage of the
         browser, and opens a page that names no person on that tab, by following the
         tab's own link so the page changes the way every other link does. The value is
         the id of a person, never a name.
         TODO: Replace with Privatium person profiles when they exist; see
         https://github.com/gabrielmongefranco/privatium-app-meds/issues/10
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
  if (window.medsPersonTabLoaded) { return; }
  window.medsPersonTabLoaded = true;

  var KEY = 'meds.person';   // The id of the person chosen last, or '' for everyone

  function remember(value) {
    try { window.localStorage.setItem(KEY, value); } catch (ignored) { /* Storage may be off. */ }
  }

  function remembered() {
    try { return window.localStorage.getItem(KEY); } catch (ignored) { return null; }
  }

  // The person a link names: an id, '' for everyone, or null when it names none.
  function personOf(href) {
    var address = new URL(href, window.location.href);
    return address.searchParams.has('person') ? address.searchParams.get('person') : null;
  }

  // One listener on the document serves every filter nav that is ever on the page.
  document.addEventListener('click', function (event) {
    var link = event.target.closest ? event.target.closest('nav[data-person-filter] a[href]') : null;
    if (!link) { return; }
    var person = personOf(link.href);
    if (person !== null) { remember(person); }
  });

  // True while the page is being changed to the remembered person's tab. The page that
  // answers is not looked at again, so a tab is never opened twice for one visit.
  var opening = false;

  // Opens the remembered person's tab on a page that names no person. Each filter nav is
  // looked at once, which the marker attribute records, so a page that is swapped in
  // is handled and a page that is still there is left alone.
  function openRemembered(root) {
    var filter = root.querySelector ? root.querySelector('nav[data-person-filter]:not([data-person-tab-seen])') : null;
    if (!filter) { return; }
    filter.setAttribute('data-person-tab-seen', '');
    if (opening) { opening = false; return; }
    // A page that names a person, even through a bookmark, becomes the memory.
    var here = new URL(window.location.href);
    if (here.searchParams.has('person')) {
      remember(here.searchParams.get('person'));
      return;
    }
    var wanted = remembered();
    if (!wanted) { return; }
    // Only a person who still has a tab is opened, so a removed person is forgotten.
    // The tab's own link is followed, so the page changes as it does for a click.
    var links = filter.querySelectorAll('a[href]');
    for (var index = 0; index < links.length; index += 1) {
      if (personOf(links[index].href) === wanted) {
        opening = true;
        links[index].click();
        return;
      }
    }
  }

  // The frame fires this for the first page and for every page swapped in after it.
  document.addEventListener('htmx:load', function (event) {
    openRemembered(event.detail && event.detail.elt ? event.detail.elt : document);
  });
}());
