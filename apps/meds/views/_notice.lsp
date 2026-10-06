<?--
This file is part of Medication Tracker
apps/meds/views/_notice.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The sentence a page shows after a save or a removal. A status region, so a screen
         reader announces it without moving the focus.
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

<? if notice then ?>
  <p class="pv-notice pv-notice-info" role="status"><?= icon('info-circle') ?> <?= notice ?></p>
<? end ?>
