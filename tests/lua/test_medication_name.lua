-- This file is part of Prescription Tracker
-- tests/lua/test_medication_name.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-09-27
-- Summary: Unit tests for apps/meds/lib/medication_name.lua.
-- Notes: See README file for documentation and full license information.
--
-- Copyright © 2026 Gabriel Mongefranco
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along
-- with this program. If not, see <https://www.gnu.org/licenses/>.

local medication_name = require 'medication_name'

return function(equal)
  equal('brand, generic and strength', medication_name.short('Examplol', 'Exampline', '10 mg'), 'Examplol (Exampline) 10 mg')
  equal('no brand', medication_name.short(nil, 'Exampline', '10 mg'), 'Exampline 10 mg')
  equal('no generic', medication_name.short('Examplol', nil, '10 mg'), 'Examplol 10 mg')
  equal('no strength', medication_name.short('Examplol', 'Exampline', nil), 'Examplol (Exampline)')
  equal('brand only', medication_name.short('Examplol', nil, nil), 'Examplol')
  equal('neither name', medication_name.short(nil, nil, '10 mg'), nil)
end
