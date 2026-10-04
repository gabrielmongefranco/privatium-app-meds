// This file is part of Prescription Tracker
// apps/meds/static/product_search.js
// Author(s): Gabriel Mongefranco
// Created: 2026-10-03
// Last Modified: 2026-10-04
// Summary: The product box of every form that needs a product: searches the catalog as a
//          person asks, lists the results a page at a time with a check box or a radio
//          button each, asks the public drug references when the catalog has nothing, and
//          suggests products while a new medication is typed. Every form works without this
//          file; the server then searches when the form is sent.
// Notes: See README file for documentation and full license information.
//
// Copyright © 2026 Gabriel Mongefranco
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License along
// with this program. If not, see <https://www.gnu.org/licenses/>.

(function () {
  'use strict';

  // A page can load this file more than once. The second copy does nothing.
  if (window.medsProductSearchLoaded) { return; }
  window.medsProductSearchLoaded = true;

  /* Configuration */
  var refs = window.medsDrugReferences;   // Loaded by the page before this file
  var RESULTS_MAX = 25;                   // Results listed from either source
  var PAGE_SIZE_WIDE = 10;                // Results on one page on a tablet or a desktop
  var PAGE_SIZE_NARROW = 5;               // Results on one page on a phone
  var WIDE_SCREEN = '(min-width: 48em)';  // 768 CSS pixels: a tablet or wider
  var SIMILAR_DELAY_MILLISECONDS = 600;   // Typing pauses this long before similar products are searched
  var MINIMUM_LETTERS = 3;                // Shorter than any name worth searching for
  var CATALOG_TIMEOUT_MILLISECONDS = 8000;

  var wide = window.matchMedia(WIDE_SCREEN);

  function pageSize() { return wide.matches ? PAGE_SIZE_WIDE : PAGE_SIZE_NARROW; }

  /* Words */

  function text(value) {
    return typeof value === 'string' ? value.replace(/\s+/g, ' ').trim() : '';
  }

  function counted(count, one, many) {
    return count + ' ' + (count === 1 ? one : many);
  }

  /* The pieces of a picker */

  function within(picker, selector) { return picker.querySelector(selector); }

  function prefixOf(picker) { return picker.getAttribute('data-product-search'); }

  // A field of the new medication, by the end of its name.
  function field(picker, ending) {
    return picker.querySelector('[name="' + prefixOf(picker) + '_' + ending + '"]');
  }

  function setField(picker, ending, value) {
    var input = field(picker, ending);
    if (!input) { return; }
    if (input.type === 'checkbox') { input.checked = value === true; }
    else { input.value = value || ''; }
  }

  // Says something in a status line, with or without the turning ring.
  function say(status, message, busy) {
    if (!status) { return; }
    var ring = status.querySelector('.meds-spinner');
    var words = status.querySelector('[data-status-text]');
    if (ring) { ring.hidden = !busy; }
    if (words) { words.textContent = message; }
  }

  function clear(container) {
    while (container.firstChild) { container.removeChild(container.firstChild); }
  }

  /* Drawing the results */

  // One result as the server draws it: a check box with the short name and the full
  // name under it. A result of the catalog is named by the id of the medication, so the
  // server adds it like a checked box of its own list. A result of a drug reference
  // fills the fields of a new medication instead.
  function resultRow(picker, container, result, position, source) {
    var id = 'f-' + prefixOf(picker) + '-' + container.getAttribute('data-results-kind') + '-' + position;
    var label = document.createElement('label');
    label.className = 'meds-option';
    label.htmlFor = id;
    var box = document.createElement('input');
    var one = picker.hasAttribute('data-pick-one');   // The form takes one product
    box.type = one && source === 'catalog' ? 'radio' : 'checkbox';
    box.id = id;
    box.value = 'yes';
    if (source === 'catalog' && one) {
      box.name = prefixOf(picker) + '_choice';
      box.value = result.medication_id;
      box.setAttribute('data-result-id', result.medication_id);
    } else if (source === 'catalog') {
      box.name = 'pick_' + result.medication_id;
      box.setAttribute('data-result-id', result.medication_id);
    } else {
      // No name, so the server never sees it; the fields it fills in travel instead.
      box.setAttribute('data-online-result', String(position));
    }
    if (result.checked) { box.checked = true; }
    var words = document.createElement('span');
    words.appendChild(document.createTextNode(result.short_name));
    if (result.badge) {
      words.appendChild(document.createTextNode(' '));
      var badge = document.createElement('span');
      badge.className = 'pv-badge pv-badge-muted';
      badge.textContent = result.badge;
      words.appendChild(badge);
    }
    if (result.full_name && result.full_name !== result.short_name) {
      var line = document.createElement('span');
      line.className = 'pv-meta meds-line';
      line.textContent = result.full_name;
      words.appendChild(line);
    }
    label.appendChild(box);
    label.appendChild(words);
    return label;
  }

  // Shows one page of the rows and the buttons to move between pages.
  function showPage(container, page) {
    var rows = container.querySelectorAll('.meds-option');
    var size = pageSize();
    var pages = Math.max(1, Math.ceil(rows.length / size));
    if (page > pages) { page = pages; }
    if (page < 1) { page = 1; }
    container.setAttribute('data-page', String(page));
    for (var index = 0; index < rows.length; index += 1) {
      rows[index].hidden = Math.floor(index / size) !== page - 1;
    }
    var pager = container.querySelector('.meds-pager');
    if (!pager) { return; }
    pager.hidden = pages <= 1;
    pager.querySelector('[data-page-back]').disabled = page <= 1;
    pager.querySelector('[data-page-forward]').disabled = page >= pages;
    pager.querySelector('[data-page-words]').textContent = 'Page ' + page + ' of ' + pages;
  }

  function pagerOf(container) {
    var nav = document.createElement('nav');
    nav.className = 'meds-pager';
    nav.setAttribute('aria-label', 'Pages of results');
    var back = document.createElement('button');
    back.type = 'button';
    back.className = 'pv-btn';
    back.textContent = 'Previous';
    back.setAttribute('data-page-back', '');
    var words = document.createElement('span');
    words.setAttribute('data-page-words', '');
    words.setAttribute('aria-live', 'polite');
    var forward = document.createElement('button');
    forward.type = 'button';
    forward.className = 'pv-btn';
    forward.textContent = 'Next';
    forward.setAttribute('data-page-forward', '');
    back.addEventListener('click', function () {
      showPage(container, parseInt(container.getAttribute('data-page') || '1', 10) - 1);
    });
    forward.addEventListener('click', function () {
      showPage(container, parseInt(container.getAttribute('data-page') || '1', 10) + 1);
    });
    nav.appendChild(back);
    nav.appendChild(words);
    nav.appendChild(forward);
    return nav;
  }

  // Draws the results into a container: a count, the check boxes in a group, the pager.
  function draw(picker, container, results, source, sourceName, term) {
    clear(container);
    if (results.length === 0) { return; }
    var count = document.createElement('p');
    count.className = 'pv-help';
    count.setAttribute('data-results-count', '');
    count.textContent = counted(results.length, 'result', 'results') + ' from ' + sourceName +
      (term ? ' for "' + term + '"' : '') +
      (picker.hasAttribute('data-pick-one') ? '. Choose the one to use.'
        : '. Check the ' + (source === 'catalog' ? 'ones' : 'one') + ' to add.');
    container.appendChild(count);
    var group = document.createElement('fieldset');
    group.className = 'meds-options meds-results';
    var legend = document.createElement('legend');
    legend.className = 'pv-visually-hidden';
    legend.textContent = 'Products found';
    group.appendChild(legend);
    results.forEach(function (result, index) {
      group.appendChild(resultRow(picker, container, result, index + 1, source));
    });
    container.appendChild(group);
    container.appendChild(pagerOf(container));
    container.setAttribute('data-source', source);
    container.onlineResults = source === 'online' ? results : null;
    container.onlineName = sourceName;
    showPage(container, 1);
  }

  /* The catalog */

  // Asks the server for the products a name fits. Resolves to the list, or to an empty
  // list when the server does not answer.
  function searchCatalog(picker, term) {
    var url = picker.getAttribute('data-search-url') + '?q=' + encodeURIComponent(term);
    var controller = new AbortController();
    var timer = window.setTimeout(function () { controller.abort(); }, CATALOG_TIMEOUT_MILLISECONDS);
    return fetch(url, { signal: controller.signal, headers: { 'Accept': 'application/json' } })
      .then(function (response) {
        if (!response.ok) { throw new Error('status ' + response.status); }
        return response.json();
      })
      .then(function (answer) {
        var results = (answer && answer.results) || [];
        return results.slice(0, RESULTS_MAX).map(function (row) {
          return {
            medication_id: row.medication_id,
            short_name: row.short_name,
            full_name: row.full_name,
            badge: row.close ? 'Close match' : ''
          };
        });
      })
      .catch(function () { return []; })
      .finally(function () { window.clearTimeout(timer); });
  }

  /* The drug references */

  // Asks the references in order. Resolves to the list and the name of the reference.
  function searchOnline(term) {
    return refs.searchFrom(0, term).then(function (found) {
      var results = found.results.slice(0, RESULTS_MAX).map(function (result) {
        return { short_name: result.label, full_name: '', badge: '', answer: result };
      });
      return {
        results: results,
        name: found.reference ? found.reference.name : 'the drug references',
        source: found.reference ? found.reference.source : ''
      };
    });
  }

  // Empties the fields that describe a looked-up product, so a product a person edits
  // no longer claims the identifier of another.
  function forgetReference(picker) {
    ['rxcui', 'source', 'route_ref', 'dose_form_ref'].forEach(function (ending) { setField(picker, ending, ''); });
  }

  // Fills the fields of a new medication from a result of a drug reference, and opens
  // them so the person can check them.
  function fillFrom(picker, result, sourceName, source, status) {
    say(status, 'Getting the details of ' + result.short_name + '.', true);
    return refs.detailsOf(result.answer).then(refs.marksOf).then(function (fields) {
      setField(picker, 'brand', fields.brand);
      setField(picker, 'generic', fields.generic);
      setField(picker, 'strength', fields.strength);
      setField(picker, 'rxcui', fields.rxcui);
      setField(picker, 'source', fields.rxcui ? source : '');
      // The words of the reference travel as hints; the route and form drop-downs,
      // when a person sets them, win over the hints.
      setField(picker, 'route_ref', fields.route);
      setField(picker, 'dose_form_ref', fields.doseForm);
      setField(picker, 'route', '');
      setField(picker, 'dose_form', '');
      setField(picker, 'controlled', fields.controlled === true);
      setField(picker, 'specialty', fields.specialty === true);
      var details = within(picker, '[data-new-product]');
      if (details) { details.open = true; }
      say(status, 'Filled in from ' + sourceName + ': ' + result.short_name +
        '. Check the fields under "Add a medication to the catalog", then choose Add to this medication.' +
        (fields.marksUnavailable ? ' The controlled mark could not be checked. Check it yourself.' : ''), false);
    });
  }

  function emptyNewFields(picker) {
    ['brand', 'generic', 'strength', 'package_size'].forEach(function (ending) { setField(picker, ending, ''); });
    setField(picker, 'controlled', false);
    setField(picker, 'specialty', false);
    forgetReference(picker);
    ['package_type', 'route', 'dose_form'].forEach(function (ending) {
      var choice = field(picker, ending);
      if (choice) { choice.value = ''; }
      setField(picker, ending + '_new', '');
    });
  }

  /* The search box */

  // Searches the catalog for what is in the box. When the catalog has nothing, the drug
  // references are asked at once. `preselect` is the id of the medication a suggestion
  // named, which comes back checked.
  function runSearch(picker, preselect) {
    var box = within(picker, '[data-search-term]');
    var status = within(picker, '[data-search-status]');
    var container = within(picker, '[data-results]:not([data-similar])');
    var term = text(box.value).slice(0, refs.TERM_MAXIMUM_LENGTH);
    clear(container);
    within(picker, '[data-online-line]').hidden = true;
    if (term.length < MINIMUM_LETTERS) {
      say(status, 'Type ' + MINIMUM_LETTERS + ' letters or more.', false);
      return Promise.resolve();
    }
    say(status, 'Searching the catalog.', true);
    return searchCatalog(picker, term).then(function (results) {
      if (results.length === 0) {
        say(status, 'The catalog has nothing under this name. Searching the online databases.', true);
        return runOnline(picker, term);
      }
      results.forEach(function (result) { result.checked = result.medication_id === preselect; });
      draw(picker, container, results, 'catalog', 'the catalog', term);
      within(picker, '[data-online-line]').hidden = false;
      say(status, counted(results.length, 'product', 'products') + ' found in the catalog.' +
        (preselect ? ' The one you picked is checked.' : ''), false);
    });
  }

  function runOnline(picker, term) {
    var status = within(picker, '[data-search-status]');
    var container = within(picker, '[data-results]:not([data-similar])');
    term = term || text(within(picker, '[data-search-term]').value);
    if (term.length < MINIMUM_LETTERS) {
      say(status, 'Type ' + MINIMUM_LETTERS + ' letters or more.', false);
      return Promise.resolve();
    }
    say(status, 'Searching the online databases.', true);
    clear(container);
    return searchOnline(term).then(function (found) {
      if (found.results.length === 0) {
        say(status, 'No online database has "' + term + '". Check the spelling, or add it to the catalog below.', false);
        var details = within(picker, '[data-new-product]');
        if (details) { details.open = true; }
        return;
      }
      draw(picker, container, found.results, 'online', found.name, term);
      container.onlineSource = found.source;
      say(status, counted(found.results.length, 'product', 'products') + ' found in ' + found.name +
        '. Check one, and its details fill in below.', false);
    });
  }

  /* Similar products while a new medication is typed */

  var similarTimers = {};

  function runSimilar(picker) {
    var term = text(text(field(picker, 'brand').value) + ' ' + text(field(picker, 'generic').value));
    var status = within(picker, '[data-similar-status]');
    var container = within(picker, '[data-results][data-similar]');
    if (term.length < MINIMUM_LETTERS) {
      clear(container);
      say(status, '', false);
      return;
    }
    say(status, 'Searching for similar products...', true);
    var asked = term;
    searchCatalog(picker, term).then(function (results) {
      if (results.length > 0) { return { results: results, kind: 'catalog', name: 'the catalog', source: '' }; }
      return searchOnline(term).then(function (found) {
        return { results: found.results, kind: 'online', name: found.name, source: found.source };
      });
    }).then(function (found) {
      // A later search has started while this one ran; its answer is the one to show.
      if (asked !== container.getAttribute('data-asked')) { return; }
      say(status, '', false);
      if (found.results.length === 0) { clear(container); return; }
      draw(picker, container, found.results, found.kind, found.name, '');
      container.onlineSource = found.source;
    });
    container.setAttribute('data-asked', asked);
  }

  /* Events */

  // The datalist of names. A suggestion that is picked names its medication.
  function suggestedId(value) {
    var options = document.querySelectorAll('#medication-names option');
    var typed = text(value).toLowerCase();
    for (var index = 0; index < options.length; index += 1) {
      if (options[index].value.toLowerCase() === typed) { return options[index].getAttribute('data-id'); }
    }
    return null;
  }

  document.addEventListener('click', function (event) {
    var target = event.target.closest ? event.target : null;
    if (!target) { return; }
    var find = target.closest('[data-search-find]');
    if (find) {
      event.preventDefault();
      runSearch(find.closest('[data-product-search]'), null);
      return;
    }
    var online = target.closest('[data-search-online]');
    if (online) { runOnline(online.closest('[data-product-search]')); }
  });

  document.addEventListener('keydown', function (event) {
    // Enter in the search box searches. It must not send the form.
    if (event.key === 'Enter' && event.target.matches && event.target.matches('[data-search-term]')) {
      event.preventDefault();
      runSearch(event.target.closest('[data-product-search]'), suggestedId(event.target.value));
    }
  });

  document.addEventListener('input', function (event) {
    var target = event.target;
    if (!target.matches) { return; }
    if (target.matches('[data-search-term]')) {
      // A suggestion that was picked is searched for at once, and comes back checked.
      var id = suggestedId(target.value);
      if (id) { runSearch(target.closest('[data-product-search]'), id); }
      return;
    }
    if (target.matches('[data-new-field]')) {
      var picker = target.closest('[data-product-search]');
      if (!picker) { return; }
      forgetReference(picker);
      if (target.getAttribute('data-new-field') === 'strength') { return; }
      var key = prefixOf(picker);
      window.clearTimeout(similarTimers[key]);
      similarTimers[key] = window.setTimeout(function () { runSimilar(picker); }, SIMILAR_DELAY_MILLISECONDS);
    }
  });

  document.addEventListener('change', function (event) {
    var box = event.target;
    if (!box.matches) { return; }
    var picker = box.closest('[data-product-search]');
    if (!picker) { return; }
    var container = box.closest('[data-results]');
    if (box.matches('[data-online-result]')) {
      // One product of a reference at a time: its fields are the only set there is.
      var others = container.querySelectorAll('[data-online-result]');
      for (var index = 0; index < others.length; index += 1) {
        if (others[index] !== box) { others[index].checked = false; }
      }
      var status = container.hasAttribute('data-similar')
        ? within(picker, '[data-similar-status]') : within(picker, '[data-search-status]');
      if (box.checked) {
        var result = container.onlineResults[parseInt(box.getAttribute('data-online-result'), 10) - 1];
        fillFrom(picker, result, container.onlineName, container.onlineSource, status);
      } else {
        emptyNewFields(picker);
        say(status, 'The fields were emptied.', false);
      }
      return;
    }
    if (box.matches('[data-result-id]') && container.hasAttribute('data-similar') && box.checked) {
      // The product is in the catalog after all, so the typed fields would add a copy.
      emptyNewFields(picker);
      say(within(picker, '[data-similar-status]'),
        'This product is in the catalog. The fields were emptied, and the checked product is added instead.', false);
    }
  });

  // The page size follows the screen, so the list re-pages when the window changes.
  function repage() {
    var containers = document.querySelectorAll('[data-product-search] [data-results]');
    for (var index = 0; index < containers.length; index += 1) {
      if (containers[index].querySelector('.meds-pager')) { showPage(containers[index], 1); }
    }
  }
  if (wide.addEventListener) { wide.addEventListener('change', repage); }
  else if (wide.addListener) { wide.addListener(repage); }

  // Results the server drew get the pager and the page size too.
  function dress() {
    var pickers = document.querySelectorAll('[data-product-search]');
    for (var index = 0; index < pickers.length; index += 1) {
      var picker = pickers[index];
      var containers = picker.querySelectorAll('[data-results]');
      for (var place = 0; place < containers.length; place += 1) {
        var container = containers[place];
        if (!container.getAttribute('data-results-kind')) {
          container.setAttribute('data-results-kind', container.hasAttribute('data-similar') ? 'similar' : 'found');
        }
        if (container.querySelector('.meds-option') && !container.querySelector('.meds-pager')) {
          container.appendChild(pagerOf(container));
          container.setAttribute('data-source', 'catalog');
          showPage(container, 1);
        }
      }
      var line = within(picker, '[data-online-line]');
      if (line && text(within(picker, '[data-search-term]').value).length >= MINIMUM_LETTERS) { line.hidden = false; }
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', dress);
  } else {
    dress();
  }
  document.addEventListener('htmx:afterSwap', dress);
}());
