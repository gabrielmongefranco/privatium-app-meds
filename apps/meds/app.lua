-- This file is part of Prescription Tracker
-- apps/meds/app.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-26
-- Last Modified: 2026-10-05
-- Summary: Entry point of the Prescription Tracker app. The routes live in lib/routes,
--          one module for each part of the app; loading a module registers its routes.
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

-- A path that matches a pattern is handled by the first route registered for it, so
-- the order below is the order in which paths are tried.
require 'routes.home'       -- The Refills page, Setup and the reminder settings
require 'routes.plans'      -- Insurance plans and their refill rules
require 'routes.people'     -- The people of the household
require 'routes.contacts'   -- Pharmacies and prescribers
require 'routes.catalog'    -- The medication catalog
require 'routes.medications'     -- What each person takes, and the list made for paper
require 'routes.paste'           -- Fills pasted from a portal; before fills, so 'paste' is never read as an id
require 'routes.reports'         -- The Reports tab of the history and the printable report
require 'routes.fills'           -- The history of fills, and the form for one fill
require 'routes.authorizations'  -- Prior authorizations
