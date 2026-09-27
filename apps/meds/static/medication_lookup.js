// This file is part of Prescription Tracker
// apps/meds/static/medication_lookup.js
// Author(s): Gabriel Mongefranco
// Created: 2026-09-27
// Last Modified: 2026-09-27
// Summary: Looks up a medication that the catalog lacks in a public drug reference, and
//          fills in the fields of a new medication. Every form works without this file.
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

  /* Configuration */
  var RXTERMS_SEARCH = 'https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search';
  var OPENFDA_NDC = 'https://api.fda.gov/drug/ndc.json';
  var RXNAV = 'https://rxnav.nlm.nih.gov/REST';
  var TIMEOUT_MILLISECONDS = 8000;  // A reference that takes longer counts as not answering
  var TERM_MINIMUM_LENGTH = 3;      // Shorter than any name worth searching for
  var TERM_MAXIMUM_LENGTH = 100;
  var DRUGS_MAX = 10;               // Drugs asked of a reference in one search
  var RESULTS_MAX = 40;             // Results shown; one drug can have many strengths

  // The references, in the order they are asked. The next one is asked only when the
  // one before it finds nothing or does not answer, as when it limits requests.
  // `source` is the value stored in the catalog.
  var REFERENCES = [
    { name: 'RxTerms', source: 'rxterms', search: searchRxTerms },
    { name: 'the openFDA NDC Directory', source: 'openfda_ndc', search: searchOpenFda },
    { name: 'RxNorm', source: 'rxnorm', search: searchRxNorm }
  ];

  /* Requests */

  // Fetches JSON from a reference. Rejects when the reference does not answer in time
  // or answers with an error. openFDA answers a search with no match with status 404.
  function getJson(url, emptyStatus) {
    var controller = new AbortController();
    var timer = window.setTimeout(function () { controller.abort(); }, TIMEOUT_MILLISECONDS);
    return fetch(url, { signal: controller.signal, credentials: 'omit', referrerPolicy: 'no-referrer' })
      .then(function (response) {
        if (emptyStatus && response.status === emptyStatus) { return null; }
        if (!response.ok) { throw new Error('status ' + response.status); }
        return response.json();
      })
      .finally(function () { window.clearTimeout(timer); });
  }

  /* Words */

  function text(value) {
    return typeof value === 'string' ? value.replace(/\s+/g, ' ').trim() : '';
  }

  // 'ATORVASTATIN CALCIUM' and 'atorvastatin calcium' become 'Atorvastatin calcium'.
  function asName(value) {
    var name = text(value).toLowerCase();
    return name.charAt(0).toUpperCase() + name.slice(1);
  }

  // A strength as a label prints it: '100 unt/ml' becomes '100 units/mL', and the
  // '40 mg/1' of openFDA, which means 40 mg in one tablet, becomes '40 mg'.
  function asStrength(value) {
    return text(value)
      .replace(/\/1$/, '')
      .replace(/\bunt\b/gi, 'units')
      .replace(/\bactuat\b/gi, 'actuation')
      .replace(/\bMG\b/g, 'mg').replace(/\bMCG\b/g, 'mcg')
      .replace(/(\d)ml\b/gi, '$1 mL')
      .replace(/ml\b/gi, 'mL');
  }

  // The words of a name before its strength: 'atorvastatin 20 MG Oral Tablet' gives
  // 'atorvastatin'.
  function beforeStrength(value) {
    // A name can open with the size of the package: '3 ML testosterone undecanoate ...'.
    var words = text(value).replace(/^\d[\d.]*\s+\S+\s+/, '').split(' ');
    var kept = [];
    for (var index = 0; index < words.length; index += 1) {
      if (/^\d/.test(words[index])) { break; }
      kept.push(words[index]);
    }
    return kept.join(' ');
  }

  // The strength that opens the text RxTerms prints for a product:
  // '10 mcg/ml Cartridge 1 ml' gives '10 mcg/mL'. Empty when the text opens otherwise.
  var STRENGTH = /^\s*([\d.,]+(?:-[\d.,]+)*\s?(?:%|(?:mg|mcg|g|ml|unt|meq|mmol)\b(?:\/[\d.,]*\s?[a-z]+)?))/i;

  function strengthIn(printed) {
    var found = STRENGTH.exec(text(printed));
    return found ? asStrength(found[1]) : '';
  }

  /* The three references */

  // Each search returns a list of results. A result holds a label to show and either
  // the fields of a medication, or the RxNorm identifier to ask the fields by.

  function searchRxTerms(term) {
    var url = RXTERMS_SEARCH + '?maxList=' + DRUGS_MAX + '&ef=STRENGTHS_AND_FORMS,RXCUIS&terms=' +
      encodeURIComponent(term);
    return getJson(url).then(function (answer) {
      var results = [];
      var names = (answer && answer[1]) || [];
      var extra = (answer && answer[2]) || {};
      names.forEach(function (displayName, position) {
        var strengths = (extra.STRENGTHS_AND_FORMS || [])[position] || [];
        var codes = (extra.RXCUIS || [])[position] || [];
        strengths.forEach(function (strength, place) {
          if (!codes[place]) { return; }
          results.push({
            label: text(displayName) + ', ' + asStrength(strength),
            rxcui: String(codes[place]),
            // Used when the details of the product cannot be asked.
            fields: {
              generic: asName(text(displayName).replace(/ \([^)]*\)$/, '')),
              strength: strengthIn(strength)
            }
          });
        });
      });
      return results;
    });
  }

  function searchOpenFda(term) {
    // Quotation marks end the phrase of a search, so a typed one is left out.
    var phrase = '"' + term.replace(/"/g, ' ') + '"';
    var url = OPENFDA_NDC + '?limit=' + RESULTS_MAX + '&search=' +
      encodeURIComponent('brand_name:' + phrase + ' generic_name:' + phrase);
    return getJson(url, 404).then(function (answer) {
      var results = [];
      var seen = {};
      ((answer && answer.results) || []).forEach(function (product) {
        var ingredients = product.active_ingredients || [];
        var strength = ingredients.map(function (one) { return asStrength(one.strength); }).join(' / ');
        var generic = asName(product.generic_name);
        var brand = text(product.brand_name);
        // A generic product repeats its generic name as its brand name.
        if (brand.toLowerCase() === generic.toLowerCase()) { brand = ''; }
        var label = (brand ? brand + ' (' + generic + ')' : generic) + ', ' + strength + ', ' +
          text(product.dosage_form).toLowerCase();
        if (!generic || seen[label]) { return; }
        seen[label] = true;
        var codes = (product.openfda && product.openfda.rxcui) || [];
        results.push({
          label: label,
          fields: {
            brand: brand, generic: generic, strength: strength,
            // One product of openFDA can list several identifiers, one for each
            // package. None of them is the product, so only a single one is kept.
            rxcui: codes.length === 1 ? String(codes[0]) : '',
            route: text((product.route || [])[0]),
            doseForm: text(product.dosage_form)
          }
        });
      });
      return results;
    });
  }

  function searchRxNorm(term) {
    var url = RXNAV + '/approximateTerm.json?maxEntries=' + DRUGS_MAX + '&term=' + encodeURIComponent(term);
    return getJson(url).then(function (answer) {
      var results = [];
      var seen = {};
      var candidates = (answer && answer.approximateGroup && answer.approximateGroup.candidate) || [];
      candidates.forEach(function (candidate) {
        if (!candidate.name || !candidate.rxcui || seen[candidate.rxcui]) { return; }
        seen[candidate.rxcui] = true;
        results.push({
          label: text(candidate.name),
          rxcui: String(candidate.rxcui),
          fields: {
            generic: asName(beforeStrength(candidate.name)),
            strength: strengthIn(text(candidate.name).replace(/^\D*/, ''))
          }
        });
      });
      return results;
    });
  }

  // The fields of a product, asked by its RxNorm identifier. Resolves to the fields
  // the result came with when the reference knows no more.
  function detailsOf(result) {
    if (!result.rxcui) { return Promise.resolve(result.fields); }
    var fallback = Object.assign({ rxcui: result.rxcui }, result.fields);
    return getJson(RXNAV + '/RxTerms/rxcui/' + encodeURIComponent(result.rxcui) + '/allinfo.json')
      .then(function (answer) {
        var found = answer && answer.rxtermsProperties;
        if (!found) { return fallback; }
        // The full name of a branded product ends with its brand: '... [Lipitor]'.
        var brand = /\[([^\]]+)\]\s*$/.exec(text(found.fullName));
        return {
          brand: brand ? brand[1] : '',
          generic: asName(beforeStrength(found.fullGenericName)) || fallback.generic,
          // The printed strength is the one on the label: RxTerms prints '10 mcg/ml'
          // where its details say '0.01 mg/ml'.
          strength: fallback.strength || asStrength(found.strength),
          rxcui: result.rxcui,
          route: text(found.route),
          doseForm: text(found.rxnormDoseForm)
        };
      })
      .catch(function () { return fallback; });
  }

  // Asks the references in order, from `position` on.
  function searchFrom(position, term) {
    if (position >= REFERENCES.length) { return Promise.resolve({ results: [] }); }
    var reference = REFERENCES[position];
    return reference.search(term)
      .catch(function () { return []; })
      .then(function (results) {
        if (results.length > 0) {
          return { results: results.slice(0, RESULTS_MAX), reference: reference };
        }
        return searchFrom(position + 1, term);
      });
  }

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
    setField(lookup, 'route', fields.route);
    setField(lookup, 'dose_form', fields.doseForm);
    var choice = lookup.closest('fieldset').querySelector(
      'input[type="radio"][name="' + lookup.getAttribute('data-lookup') + '_choice"][value="new"]');
    if (choice) { choice.checked = true; }
    clearResults(lookup);
    say(lookup, 'Filled in from ' + reference.name + ': ' + label +
      '. Check the fields below, then save.');
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
      var item = document.createElement('li');
      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'pv-btn';
      button.textContent = result.label;
      button.addEventListener('click', function () {
        say(lookup, 'Getting the details of ' + result.label + '.');
        detailsOf(result).then(function (fields) { fill(lookup, fields, found.reference, result.label); });
      });
      item.appendChild(button);
      list.appendChild(item);
    });
    say(lookup, found.results.length + (found.results.length === 1 ? ' result' : ' results') +
      ' from ' + found.reference.name + '. Choose one.');
  }

  function search(lookup) {
    var term = text(within(lookup, '[data-lookup-term]').value).slice(0, TERM_MAXIMUM_LENGTH);
    clearResults(lookup);
    if (term.length < TERM_MINIMUM_LENGTH) {
      say(lookup, 'Type ' + TERM_MINIMUM_LENGTH + ' letters or more.');
      return;
    }
    say(lookup, 'Searching.');
    searchFrom(0, term).then(function (found) { show(lookup, found, term); });
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
      ['rxcui', 'source', 'route', 'dose_form'].forEach(function (ending) { setField(lookup, ending, ''); });
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
