<?--
This file is part of Prescription Tracker
apps/meds/views/_contact.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-04
Summary: One pharmacy or prescriber on its page under Setup, with every detail that is filled in.
         A phone number is a link a phone can dial. A website is a link only with an http or
         https address, which the form has already checked.
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

<li class="pv-card">
  <h2><?= contact.name ?></h2>
  <dl>
    <? if contact.clinic then ?><dt>Clinic</dt><dd><?= contact.clinic ?></dd><? end ?>
    <? if contact.phone then ?>
      <dt>Phone</dt>
      <dd><? if contact.phone_href then ?><a href="tel:<?= contact.phone_href ?>"><?= contact.phone ?></a><? else ?><?= contact.phone ?><? end ?></dd>
    <? end ?>
    <? if contact.mobile_phone then ?>
      <dt>Mobile phone</dt>
      <dd><? if contact.mobile_href then ?><a href="tel:<?= contact.mobile_href ?>"><?= contact.mobile_phone ?></a><? else ?><?= contact.mobile_phone ?><? end ?></dd>
    <? end ?>
    <? if contact.fax then ?><dt>Fax</dt><dd><?= contact.fax ?></dd><? end ?>
    <? if contact.address then ?><dt>Address</dt><dd><?= contact.address ?></dd><? end ?>
    <? if contact.email then ?><dt>Email</dt><dd><a href="mailto:<?= contact.email ?>"><?= contact.email ?></a></dd><? end ?>
    <? if contact.website then ?>
      <dt>Website</dt>
      <dd><? if contact.website:lower():match('^https?://') then ?><a href="<?= contact.website ?>" rel="noopener noreferrer"><?= contact.website ?></a><? else ?><?= contact.website ?><? end ?></dd>
    <? end ?>
    <? if contact.npi then ?><dt>National Provider Identifier</dt><dd><?= contact.npi ?></dd><? end ?>
  </dl>
  <p class="pv-actions">
    <a class="pv-btn" href="<?= url(path .. '/' .. contact.id .. '/edit') ?>"><?= icon('pencil') ?> Change<span class="pv-visually-hidden"> <?= contact.name ?></span></a>
    <a class="pv-btn" href="<?= url(path .. '/' .. contact.id .. '/remove') ?>"><?= icon('trash') ?> Remove<span class="pv-visually-hidden"> <?= contact.name ?></span></a>
  </p>
</li>
