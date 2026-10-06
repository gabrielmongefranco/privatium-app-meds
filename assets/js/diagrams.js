/*
This file is part of Medication Tracker
assets/js/diagrams.js
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: Draws the Mermaid diagrams of a documentation website page. Each ```mermaid block
         becomes a picture, and the diagram's source stays on the page in a closed
         "Diagram source" disclosure. A block that cannot be drawn is left as text.
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
  if (!window.mermaid) { return; }

  // Strict mode keeps diagram labels as text, so no markup or script from a label runs.
  window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: 'neutral' });

  // Kramdown writes a fenced block as code.language-mermaid inside a pre, sometimes wrapped
  // in a div of the same class when a highlighter runs.
  var codes = document.querySelectorAll('code.language-mermaid');
  Array.prototype.forEach.call(codes, function (code, index) {
    var block = code.closest('div.language-mermaid') || code.closest('pre') || code;
    window.mermaid.render('diagram-' + index, code.textContent).then(function (result) {
      var figure = document.createElement('figure');
      figure.className = 'diagram';
      // The SVG comes from this site's own Markdown, and Mermaid cleans it with its bundled
      // DOMPurify in strict mode before returning it.
      figure.innerHTML = result.svg;
      // The text beside each diagram carries the same facts, so the picture is named, not read.
      var picture = figure.querySelector('svg');
      if (picture) {
        picture.setAttribute('role', 'img');
        picture.setAttribute('aria-label', 'Diagram. The text after it describes the same facts.');
      }
      var source = document.createElement('details');
      var summary = document.createElement('summary');
      summary.textContent = 'Diagram source';
      source.appendChild(summary);
      block.parentNode.insertBefore(figure, block);
      block.parentNode.insertBefore(source, block);
      source.appendChild(block);
    }).catch(function () {
      // The source stays visible as text, which is how GitHub shows a diagram it cannot draw.
    });
  });
})();
