// This file is part of Prescription Tracker
// apps/meds/static/forms.js
// Author(s): Gabriel Mongefranco
// Created: 2026-09-27
// Last Modified: 2026-09-27
// Summary: Shows the fields that add a new record only after a person chooses to add one.
//          Every form works without this file; the fields are then always there.
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
  if (window.medsFormsLoaded) { return; }
  window.medsFormsLoaded = true;

  // A part of a form names the control and the value that show it:
  // data-show-when="pharmacy_id=new".
  function ruleOf(part) {
    var rule = part.getAttribute('data-show-when') || '';
    var cut = rule.indexOf('=');
    return { name: rule.slice(0, cut), value: rule.slice(cut + 1) };
  }

  // The value of a control of a form: what a drop-down holds, or the radio button
  // that is marked.
  function valueOf(form, name) {
    var controls = form.querySelectorAll('[name="' + name + '"]');
    for (var index = 0; index < controls.length; index += 1) {
      var control = controls[index];
      if (control.type !== 'radio' || control.checked) { return control.value; }
    }
    return '';
  }

  function typedIn(part) {
    var boxes = part.querySelectorAll('input[type="text"], input[type="search"]');
    for (var index = 0; index < boxes.length; index += 1) {
      if (boxes[index].value !== '') { return true; }
    }
    return false;
  }

  // Shows or hides every part of a form. `changed` is the name of the control a
  // person just changed, or nothing when the page has just arrived.
  function arrange(form, changed) {
    var parts = form.querySelectorAll('[data-show-when]');
    for (var index = 0; index < parts.length; index += 1) {
      var part = parts[index];
      var rule = ruleOf(part);
      var shown = valueOf(form, rule.name) === rule.value;
      var list = form.querySelector('select[name="' + rule.name + '"]');
      if (changed === rule.name && !shown && list) {
        // What was typed for a new record must not be saved once a person has
        // chosen another record in the drop-down. Radio buttons decide by
        // themselves, so what stands beside them can stay.
        var typed = part.querySelectorAll('input[type="text"], input[type="hidden"]');
        for (var place = 0; place < typed.length; place += 1) { typed[place].value = ''; }
      }
      part.hidden = !shown;
      if (changed === rule.name && shown) {
        var first = part.querySelector('input:not([type="hidden"]), select');
        if (first) { first.focus(); }
      }
    }
  }

  function arrangeAll() {
    var forms = document.querySelectorAll('form');
    for (var index = 0; index < forms.length; index += 1) {
      var form = forms[index];
      // A form that came back with something typed for a new record shows it.
      var parts = form.querySelectorAll('[data-show-when]');
      for (var place = 0; place < parts.length; place += 1) {
        var rule = ruleOf(parts[place]);
        var control = form.querySelector('select[name="' + rule.name + '"]');
        if (control && control.value === '' && typedIn(parts[place])) { control.value = rule.value; }
      }
      arrange(form);
    }
  }

  document.addEventListener('change', function (event) {
    var control = event.target;
    if (control && control.form && control.name) { arrange(control.form, control.name); }
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', arrangeAll);
  } else {
    arrangeAll();
  }
  document.addEventListener('htmx:afterSwap', arrangeAll);
}());
