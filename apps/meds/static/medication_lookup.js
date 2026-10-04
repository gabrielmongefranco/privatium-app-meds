// This file is part of Prescription Tracker
// apps/meds/static/medication_lookup.js
// Author(s): Gabriel Mongefranco
// Created: 2026-09-27
// Last Modified: 2026-10-03
// Summary: Looks up a medication that the catalog lacks in a public drug reference, and
//          fills in the fields of a new medication. Every form works without this file.
//          The references themselves are asked through drug_references.js.
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
  if (window.medsLookupLoaded) { return; }
  window.medsLookupLoaded = true;
  // The references are asked through drug_references.js, which the page loads first.
  var refs = window.medsDrugReferences;
  var CATALOG_MAX = 12;             // Medications of the catalog shown before a reference is asked

  /* The page */

  function within(lookup, selector) { return lookup.querySelector(selector); }

  function say(lookup, message) { within(lookup, '[data-lookup-status]').textContent = message; }

  function clearResults(lookup) {
    var list = within(lookup, '[data-lookup-results]');
    while (list.firstChild) { list.removeChild(list.firstChild); }
    return list;
  }

  // The field of the medication box that a lookup belongs to, by the end of its name.
  function field(lookup, ending) {
    var box = lookup.closest('fieldset');
    return box && box.querySelector('[name="' + lookup.getAttribute('data-lookup') + '_' + ending + '"]');
  }

  function setField(lookup, ending, value) {
    var input = field(lookup, ending);
    if (input) { input.value = value || ''; }
  }

  function fill(lookup, fields, reference, label) {
    setField(lookup, 'brand', fields.brand);
    setField(lookup, 'generic', fields.generic);
    setField(lookup, 'strength', fields.strength);
    setField(lookup, 'rxcui', fields.rxcui);
    setField(lookup, 'source', reference.source);
    // The words of the reference travel as hints; the route and form drop-downs,
    // when a person sets them, win over the hints.
    setField(lookup, 'route_ref', fields.route);
    setField(lookup, 'dose_form_ref', fields.doseForm);
    ['controlled', 'specialty'].forEach(function (mark) {
      var input = field(lookup, mark);
      if (input) { input.checked = fields[mark] === true; }
    });
    var choice = lookup.closest('fieldset').querySelector(
      'input[type="radio"][name="' + lookup.getAttribute('data-lookup') + '_choice"][value="new"]');
    if (choice) { choice.checked = true; }
    clearResults(lookup);
    say(lookup, 'Filled in from ' + reference.name + ': ' + label +
      '. Check the fields and medication marks below, then save.' +
      (fields.marksUnavailable ? ' The controlled mark could not be checked. Check it yourself.' : ''));
    var first = field(lookup, 'brand');
    if (first) { first.focus(); }
  }

  function show(lookup, found, term) {
    var list = clearResults(lookup);
    if (found.results.length === 0) {
      say(lookup, 'No drug reference has "' + term + '". Check the spelling, or fill in the fields below yourself.');
      return;
    }
    found.results.forEach(function (result) {
      resultButton(list, result.label, function () {
        say(lookup, 'Getting the details of ' + result.label + '.');
        refs.detailsOf(result).then(refs.marksOf).then(function (fields) { fill(lookup, fields, found.reference, result.label); });
      });
    });
    say(lookup, found.results.length + (found.results.length === 1 ? ' result' : ' results') +
      ' from ' + found.reference.name + '. Choose one.');
  }

  // The names of the catalog that hold every typed word. The page carries them for the
  // suggestions of the name box, so this asks nobody.
  function inCatalog(term) {
    var words = term.toLowerCase().split(' ');
    var options = document.querySelectorAll('#medication-names option');
    var found = [];
    var seen = {};
    for (var index = 0; index < options.length && found.length < CATALOG_MAX; index += 1) {
      var name = options[index].value;
      var shown = options[index].getAttribute('label') || name;
      var searched = (name + ' ' + shown).toLowerCase();
      var holdsAll = words.every(function (word) { return searched.indexOf(word) !== -1; });
      if (holdsAll && !seen[shown]) {
        seen[shown] = true;
        found.push({ name: name, shown: shown });
      }
    }
    return found;
  }

  function resultButton(list, label, action) {
    var item = document.createElement('li');
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'pv-btn';
    button.textContent = label;
    button.addEventListener('click', action);
    item.appendChild(button);
    list.appendChild(item);
  }

  // Picks a medication of the catalog: its name goes into the name box, and the
  // fields of a new medication are emptied, so the form saves the one that was picked.
  function pick(lookup, entry) {
    ['brand', 'generic', 'strength', 'package_size', 'package_type', 'rxcui', 'source', 'route_ref',
      'dose_form_ref'].forEach(function (ending) { setField(lookup, ending, ''); });
    ['controlled', 'specialty'].forEach(function (mark) {
      var input = field(lookup, mark);
      if (input) { input.checked = false; }
    });
    setField(lookup, 'name', entry.name);
    var other = lookup.closest('fieldset').querySelector(
      'input[type="radio"][name="' + lookup.getAttribute('data-lookup') + '_choice"][value="other"]');
    if (other) {
      other.checked = true;
      other.dispatchEvent(new Event('change', { bubbles: true }));
    }
    clearResults(lookup);
    say(lookup, 'Chosen from the catalog: ' + entry.shown + '. Save the form to use it.');
    var box = field(lookup, 'name');
    if (box) { box.focus(); }
  }

  function askReferences(lookup, term) {
    clearResults(lookup);
    say(lookup, 'Searching the drug references.');
    refs.searchFrom(0, term).then(function (found) { show(lookup, found, term); });
  }

  // The catalog comes first. A drug reference is asked only when the catalog holds
  // nothing under the name, or when a person says that none of its medications is
  // the one.
  function search(lookup) {
    var term = refs.text(within(lookup, '[data-lookup-term]').value).slice(0, refs.TERM_MAXIMUM_LENGTH);
    var list = clearResults(lookup);
    if (term.length < refs.TERM_MINIMUM_LENGTH) {
      say(lookup, 'Type ' + refs.TERM_MINIMUM_LENGTH + ' letters or more.');
      return;
    }
    var known = inCatalog(term);
    if (known.length === 0) {
      askReferences(lookup, term);
      return;
    }
    known.forEach(function (entry) {
      resultButton(list, entry.shown, function () { pick(lookup, entry); });
    });
    resultButton(list, 'None of these. Search the drug references.', function () {
      askReferences(lookup, term);
    });
    say(lookup, 'The catalog has ' + known.length + (known.length === 1 ? ' medication' : ' medications') +
      ' under this name. Choose one, or search the drug references.');
  }

  // Events are heard on the document, so a part of a page that arrives later works too.
  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest('[data-lookup-search]');
    if (button) { search(button.closest('[data-lookup]')); }
  });

  document.addEventListener('keydown', function (event) {
    // Enter in the lookup box searches. It must not send the form.
    if (event.key === 'Enter' && event.target.matches && event.target.matches('[data-lookup-term]')) {
      event.preventDefault();
      search(event.target.closest('[data-lookup]'));
    }
  });

  document.addEventListener('input', function (event) {
    // A field that a person changes no longer describes the product that was looked
    // up, so the identifier of that product is let go.
    if (!event.target.matches || !event.target.matches('[data-lookup-field]')) { return; }
    var lookup = event.target.closest('fieldset').querySelector('[data-lookup]');
    if (lookup) {
      ['rxcui', 'source', 'route_ref', 'dose_form_ref'].forEach(function (ending) { setField(lookup, ending, ''); });
    }
  });

  function reveal() {
    var lookups = document.querySelectorAll('[data-lookup][hidden]');
    for (var index = 0; index < lookups.length; index += 1) { lookups[index].hidden = false; }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', reveal);
  } else {
    reveal();
  }
  document.addEventListener('htmx:afterSwap', reveal);
}());
