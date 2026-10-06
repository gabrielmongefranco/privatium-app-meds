<?--
This file is part of Medication Tracker
apps/meds/views/_when_to_take.lsp
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: The time of day a medication is taken, with its icons before the words.
         The icons are hidden from screen readers, since the words say the same.
         Parameters: when_to_take (the words), icons (names from when_icon.of).
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
--?><? for _, name in ipairs(icons or {}) do ?><?= icon(name) ?> <? end ?><?= when_to_take ?>