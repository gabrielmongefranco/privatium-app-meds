-- This file is part of Prescription Tracker
-- apps/meds/app.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-26
-- Last Modified: 2026-09-26
-- Summary: Routes for the Prescription Tracker app. This first version stores the
--          household's display name and greets with it; prescription tables come next.
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

local pv = require 'privatium'

-- The one household using this node. At most one row exists.
local function profile()
  return pv.query1('SELECT id, display_name FROM profile LIMIT 1')
end

pv.get('/', function()
  return pv.render('index', { me = profile() })
end)

pv.get('/edit', function()
  return pv.render('edit', { me = profile() })
end)

pv.post('/name', function(req)
  local name = (req.form.display_name or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if name == '' then
    return pv.render('edit', { me = profile(), err = 'Please enter a name.' })
  end

  local me = profile()
  -- Reusing the existing id makes this an amendment, not a second household.
  pv.append('profile', me and me.id or nil, { display_name = name })

  return pv.redirect(url('/'))
end)
