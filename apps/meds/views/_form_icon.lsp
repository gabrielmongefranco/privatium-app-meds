<?--
This file is part of Medication Tracker
apps/meds/views/_form_icon.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-03
Last Modified: 2026-10-03
Summary: The icon of a dose form before a medication name. Every icon comes from the
         vendored Bootstrap Icons set except the syringe, which the set lacks and this
         partial draws itself, at the same size and in the current text color.
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

<? if icon_name == 'syringe' then ?><svg class="pv-icon meds-form-icon" width="1em" height="1em" viewBox="0 0 16 16" fill="currentColor" role="img" focusable="false" aria-label="<?= label ?>"><title><?= label ?></title><path d="M15.7 1.3a1 1 0 0 0-1.4 0l-1.1 1.1-.7-.7a.5.5 0 1 0-.7.7l.7.7-7.4 7.4-1.5-.1a.5.5 0 0 0-.4.1L.6 13.1a.5.5 0 0 0 0 .7l1.6 1.6a.5.5 0 0 0 .7 0l2.6-2.6a.5.5 0 0 0 .1-.4l-.1-1.5 7.4-7.4.7.7a.5.5 0 1 0 .7-.7l-.7-.7 1.1-1.1a1 1 0 0 0 0-1.4zM4.8 10.3l1.4-1.4 1.1 1.1a.5.5 0 1 0 .7-.7L6.9 8.2l1.4-1.4 1.1 1.1a.5.5 0 1 0 .7-.7L9 6.1l1.4-1.4 1.9 1.9-6 6-1.5-1.5z"/></svg><? else ?><?= icon(icon_name, label) ?><? end ?>
