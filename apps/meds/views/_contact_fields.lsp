<?--
This file is part of Medication Tracker
apps/meds/views/_contact_fields.lsp
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The fields that a pharmacy and a prescriber share, after the name.
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

<?= render('_field', { name = 'phone', label = 'Phone', value = typed.phone, err = errors.phone,
      input_type = 'tel', maxlength = 40 }) ?>
<? if with_mobile then ?>
  <?= render('_field', { name = 'mobile_phone', label = 'Mobile phone', value = typed.mobile_phone,
        err = errors.mobile_phone, input_type = 'tel', maxlength = 40 }) ?>
<? end ?>
<?= render('_field', { name = 'fax', label = 'Fax', value = typed.fax, err = errors.fax,
      input_type = 'tel', maxlength = 40 }) ?>
<?= render('_field', { name = 'address', label = 'Address', value = typed.address,
      err = errors.address, maxlength = 200 }) ?>
<?= render('_field', { name = 'email', label = 'Email', value = typed.email, err = errors.email,
      input_type = 'email', maxlength = 254 }) ?>
<?= render('_field', { name = 'website', label = 'Website', value = typed.website,
      err = errors.website, input_type = 'url', maxlength = 200,
      help = 'Start with https://, such as https://example.com.' }) ?>
<?= render('_field', { name = 'npi', label = 'National Provider Identifier', value = typed.npi,
      err = errors.npi, inputmode = 'numeric', maxlength = 10,
      help = 'Ten digits. Insurance statements often call it the pharmacy ID or the provider ID.' }) ?>
