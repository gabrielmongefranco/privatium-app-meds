-- This file is part of Prescription Tracker
-- apps/meds/schema.sql
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-26
-- Last Modified: 2026-09-26
-- Summary: Tables of the Prescription Tracker app. Derived from the event log on every
--          start; see docs/data-model.md for the grain and meaning of every column.
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

--- profile: the household using this node ---
-- Grain: one row per node, at most one row ever. display_name is what the app calls you.
CREATE TABLE profile (
    id           VARCHAR PRIMARY KEY,   -- ULID, minted by the framework
    display_name VARCHAR NOT NULL       -- A name or nickname; it need not be a real name
);
