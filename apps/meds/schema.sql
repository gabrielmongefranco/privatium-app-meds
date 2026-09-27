-- This file is part of Prescription Tracker
-- apps/meds/schema.sql
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-26
-- Last Modified: 2026-09-27
-- Summary: Tables and views of the Prescription Tracker app. Derived from the event log on
--          every start; see docs/data-model.md for the grain and meaning of every column.
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

-- Every id is a ULID. Dates are calendar dates in YYYY-MM-DD form with no time zone.
-- Money and quantities are exact decimal text. No table declares UNIQUE or a default
-- value, because Privatium refuses the first and does not apply the second on write.

--- profile: the reminder settings of this node ---
-- Grain: one row per node, at most one row ever. No row means every default is in force.
-- A day count left empty uses the default written in v_reminder_default.
CREATE TABLE profile (
    id                             VARCHAR PRIMARY KEY,  -- ULID, minted by the framework
    due_within_days                BIGINT,               -- A refill is due when its next fill date is this many days away or fewer
    due_soon_within_days           BIGINT,               -- A refill is due soon when its next fill date is this many days away or fewer
    specialty_due_within_days      BIGINT,               -- The same two counts for a specialty medication, which takes longer to arrive
    specialty_due_soon_within_days BIGINT,
    authorization_notice_days      BIGINT,               -- A prior authorization is due soon when it expires in this many days or fewer
    authorization_due_within_days  BIGINT,               -- A prior authorization is due when it expires in this many days or fewer
    CHECK (due_within_days IS NULL OR due_within_days >= 0),
    CHECK (due_soon_within_days IS NULL OR due_soon_within_days >= 0),
    CHECK (specialty_due_within_days IS NULL OR specialty_due_within_days >= 0),
    CHECK (specialty_due_soon_within_days IS NULL OR specialty_due_soon_within_days >= 0),
    CHECK (authorization_notice_days IS NULL OR authorization_notice_days >= 0),
    CHECK (authorization_due_within_days IS NULL OR authorization_due_within_days >= 0)
);

--- person: a household member ---
-- Grain: one row per person whose medications the household tracks.
CREATE TABLE person (
    id           VARCHAR PRIMARY KEY,
    display_name VARCHAR NOT NULL,   -- Personal information
    birth_date   DATE                -- Personal information; optional
);

--- medication: the catalog of products ---
-- Grain: one row per product: a drug at one strength and form, or one supply item.
-- The same product under another spelling is a medication_alias row, never a second row here.
-- A row is typed by the owner or copied from a drug reference. A copied row keeps the
-- reference's identifier, so copying the same product again finds this row.
CREATE TABLE medication (
    id            VARCHAR PRIMARY KEY,
    short_name    VARCHAR NOT NULL,  -- The name the app shows everywhere: 'Brand (Generic) strength' unless the owner types another
    generic_name  VARCHAR,
    brand_name    VARCHAR,
    strength      VARCHAR,           -- As the label prints it, unit included: '10 mg', '100 units/mL', '100-62.5-25 mcg'
    route         VARCHAR,
    form          VARCHAR,
    package_size  VARCHAR,
    package_type  VARCHAR,
    is_specialty  BOOLEAN NOT NULL,  -- A specialty medication takes longer to arrive, so its refill is due earlier
    rxcui         VARCHAR,           -- RxNorm concept identifier of the product, digits kept as text; NULL when not known
    source        VARCHAR,           -- The drug reference the row was copied from, such as 'rxterms'; NULL when the owner typed it
    retrieved_on  DATE,              -- Local calendar date the row was copied or refreshed; NULL when the owner typed it
    CHECK (generic_name IS NOT NULL OR brand_name IS NOT NULL)
);

--- medication_alias: other names a medication is known by ---
-- Grain: one row per medication per other name, as a label, a statement or a person wrote it.
CREATE TABLE medication_alias (
    id            VARCHAR PRIMARY KEY,
    medication_id VARCHAR NOT NULL,  -- medication.id
    alias         VARCHAR NOT NULL   -- Kept as written; matching ignores case and punctuation
);

--- pharmacy ---
-- Grain: one row per pharmacy or supplier.
CREATE TABLE pharmacy (
    id      VARCHAR PRIMARY KEY,
    name    VARCHAR NOT NULL,
    npi     VARCHAR,                 -- National Provider Identifier, kept as text
    address VARCHAR,
    phone   VARCHAR,
    fax     VARCHAR,
    email   VARCHAR,
    website VARCHAR
);

--- prescriber ---
-- Grain: one row per prescriber.
CREATE TABLE prescriber (
    id           VARCHAR PRIMARY KEY,
    name         VARCHAR NOT NULL,
    clinic       VARCHAR,
    phone        VARCHAR,
    mobile_phone VARCHAR,
    fax          VARCHAR,
    email        VARCHAR,
    address      VARCHAR,
    website      VARCHAR,
    npi          VARCHAR             -- National Provider Identifier, kept as text
);

--- person_medication: what each person takes ---
-- Grain: one row per person per medication they take or took.
CREATE TABLE person_medication (
    id              VARCHAR PRIMARY KEY,
    person_id       VARCHAR NOT NULL,   -- person.id
    medication_id   VARCHAR NOT NULL,   -- medication.id
    medication_type VARCHAR,
    status          VARCHAR NOT NULL,
    pharmacy_id     VARCHAR,            -- pharmacy.id; the pharmacy used now
    prescriber_id   VARCHAR,            -- prescriber.id; NULL means self-prescribed
    prescribed_for  VARCHAR,            -- Health information
    instructions    VARCHAR,            -- Health information
    when_to_take    VARCHAR,
    refills_left    BIGINT NOT NULL,
    CHECK (status IN ('taking_regularly', 'taking_as_needed', 'on_hold', 'not_started', 'not_taking')),
    CHECK (refills_left >= 0)
);

--- fill: each time a medication was picked up or delivered ---
-- Grain: one row per fill of one medication for one person.
CREATE TABLE fill (
    id                     VARCHAR PRIMARY KEY,
    person_id              VARCHAR NOT NULL,   -- person.id
    medication_id          VARCHAR NOT NULL,   -- medication.id
    pharmacy_id            VARCHAR NOT NULL,   -- pharmacy.id
    filled_on              DATE NOT NULL,      -- Calendar date on the label; no time zone
    rx_number              VARCHAR,
    quantity               DECIMAL(18,3),      -- Units dispensed; three places because some fills are a fraction of a package
    days_supply            BIGINT,             -- Days the fill should last; NULL when the label does not say
    amount_paid            DECIMAL(18,2),      -- What the household paid, in the household's own currency
    insurance_plan         VARCHAR,
    insurance_claim_number VARCHAR,
    notes                  VARCHAR,
    CHECK (days_supply IS NULL OR days_supply >= 0),
    CHECK (quantity IS NULL OR decimal_cmp(quantity, '0') >= 0),
    CHECK (amount_paid IS NULL OR decimal_cmp(amount_paid, '0') >= 0)
);

--- prior_authorization: an insurer's approval window ---
-- Grain: one row per approval window for one person and one medication.
CREATE TABLE prior_authorization (
    id            VARCHAR PRIMARY KEY,
    person_id     VARCHAR NOT NULL,   -- person.id; an insurer approves a medication for one member
    medication_id VARCHAR NOT NULL,   -- medication.id
    valid_from    DATE,               -- The first day the approval covers; NULL when the household does not know it
    valid_to      DATE NOT NULL,      -- The expiration date: the last day the approval covers
    CHECK (valid_from IS NULL OR valid_to >= valid_from)
);

CREATE INDEX ix_fill_person_medication ON fill (person_id, medication_id, filled_on);
CREATE INDEX ix_person_medication_person ON person_medication (person_id);
CREATE INDEX ix_prior_authorization_medication ON prior_authorization (medication_id);
CREATE INDEX ix_medication_alias_medication ON medication_alias (medication_id);
CREATE INDEX ix_medication_rxcui ON medication (rxcui);

--- v_reminder_default: the day counts the app uses until the household sets its own ---
-- Grain: exactly one row. Every number is a count of days.
CREATE VIEW v_reminder_default AS
SELECT 3  AS due_within_days,
       7  AS due_soon_within_days,
       5  AS specialty_due_within_days,
       10 AS specialty_due_soon_within_days,
       30 AS authorization_notice_days,
       14 AS authorization_due_within_days;

--- v_reminder_setting: the day counts in force ---
-- Grain: exactly one row, whether or not a profile row exists.
-- A count that the household left empty takes its default.
CREATE VIEW v_reminder_setting AS
SELECT coalesce((SELECT max(p.due_within_days) FROM profile p),
                d.due_within_days)                AS due_within_days,
       coalesce((SELECT max(p.due_soon_within_days) FROM profile p),
                d.due_soon_within_days)           AS due_soon_within_days,
       coalesce((SELECT max(p.specialty_due_within_days) FROM profile p),
                d.specialty_due_within_days)      AS specialty_due_within_days,
       coalesce((SELECT max(p.specialty_due_soon_within_days) FROM profile p),
                d.specialty_due_soon_within_days) AS specialty_due_soon_within_days,
       coalesce((SELECT max(p.authorization_notice_days) FROM profile p),
                d.authorization_notice_days)      AS authorization_notice_days,
       coalesce((SELECT max(p.authorization_due_within_days) FROM profile p),
                d.authorization_due_within_days)  AS authorization_due_within_days
  FROM v_reminder_default d;

--- v_medication: the catalog with its built names ---
-- Grain: one row per medication.
-- full_name joins every part that is filled in: generic name, brand name in brackets,
-- strength, route, form and package.
CREATE VIEW v_medication AS
SELECT m.id AS medication_id,
       m.short_name,
       trim(CASE WHEN m.generic_name IS NOT NULL AND m.brand_name IS NOT NULL
                 THEN m.generic_name || ' (' || m.brand_name || ')'
                 ELSE coalesce(m.generic_name, m.brand_name) END
            || coalesce(' ' || m.strength, '')
            || coalesce(' ' || m.route, '')
            || coalesce(' ' || m.form, '')
            || coalesce(' ' || m.package_size, '')
            || coalesce(' ' || m.package_type, '')) AS full_name,
       m.generic_name,
       m.brand_name,
       m.strength,
       m.route,
       m.form,
       m.package_size,
       m.package_type,
       m.is_specialty,
       m.rxcui,
       m.source,
       m.retrieved_on
  FROM medication m;

--- v_medication_name: every name a medication answers to ---
-- Grain: one row per medication per distinct name. The search reads this view.
CREATE VIEW v_medication_name AS
SELECT m.id AS medication_id, m.short_name AS name, 'short_name' AS name_kind FROM medication m
UNION
SELECT m.id, m.generic_name, 'generic_name' FROM medication m WHERE m.generic_name IS NOT NULL
UNION
SELECT m.id, m.brand_name, 'brand_name' FROM medication m WHERE m.brand_name IS NOT NULL
UNION
SELECT a.medication_id, a.alias, 'alias' FROM medication_alias a;

--- v_last_fill: the latest fill of each medication for each person ---
-- Grain: one row per person per medication that has at least one fill.
-- The latest date wins. Two fills on one day are ordered by id, and the fill entered
-- later has the greater id. The view leaves out the DECIMAL columns, so any SQLite tool
-- can run it and the views built on it; read those columns from fill by fill_id.
CREATE VIEW v_last_fill AS
SELECT r.id AS fill_id,
       r.person_id,
       r.medication_id,
       r.pharmacy_id,
       r.filled_on,
       r.rx_number,
       r.days_supply,
       r.insurance_plan
  FROM (SELECT f.id, f.person_id, f.medication_id, f.pharmacy_id, f.filled_on,
               f.rx_number, f.days_supply, f.insurance_plan,
               row_number() OVER (PARTITION BY f.person_id, f.medication_id
                                  ORDER BY f.filled_on DESC, f.id DESC) AS recency
          FROM fill f) r
 WHERE r.recency = 1;

--- v_supply_window: the fills that count toward the recommended next fill date ---
-- Grain: one row per person per medication that has at least one fill.
-- The window opens at the start of the latest fill's year, or at the start of the month
-- three months before that fill, whichever is earlier. A fill with no days supply counts
-- as 1 day.
CREATE VIEW v_supply_window AS
SELECT w.person_id,
       w.medication_id,
       w.window_start,
       min(f.filled_on)                AS first_filled_on,
       sum(coalesce(f.days_supply, 1)) AS days_supplied
  FROM (SELECT l.person_id,
               l.medication_id,
               min(date(l.filled_on, 'start of year'),
                   date(l.filled_on, '-3 months', 'start of month')) AS window_start
          FROM v_last_fill l) w
  JOIN fill f
    ON f.person_id = w.person_id          -- 1:many; every fill of the pair inside the window
   AND f.medication_id = w.medication_id
   AND f.filled_on >= w.window_start
 GROUP BY w.person_id, w.medication_id, w.window_start;

--- v_supply: refill dates for everything a person takes ---
-- Grain: one row per person_medication row.
-- next_fill_on is the last fill date plus its days supply. recommended_next_fill_on also
-- counts the supply built up by earlier fills in the window, and is never earlier than
-- next_fill_on. A last fill with no days supply counts as 1 day and sets
-- days_supply_missing to 1.
CREATE VIEW v_supply AS
SELECT pm.id          AS person_medication_id,
       pm.person_id,
       pm.medication_id,
       pm.status,
       pm.refills_left,
       l.fill_id      AS last_fill_id,
       l.filled_on    AS last_filled_on,
       l.pharmacy_id  AS last_pharmacy_id,
       l.days_supply  AS last_days_supply,
       CASE WHEN l.fill_id IS NOT NULL AND l.days_supply IS NULL THEN 1 ELSE 0 END AS days_supply_missing,
       date(l.filled_on, '+' || coalesce(l.days_supply, 1) || ' days') AS next_fill_on,
       max(date(l.filled_on, '+' || coalesce(l.days_supply, 1) || ' days'),
           date(w.first_filled_on, '+' || w.days_supplied || ' days')) AS recommended_next_fill_on
  FROM person_medication pm
  LEFT JOIN v_last_fill l                  -- 1:0..1; a medication may have no fill yet
    ON l.person_id = pm.person_id
   AND l.medication_id = pm.medication_id
  LEFT JOIN v_supply_window w              -- 1:0..1; present exactly when v_last_fill is
    ON w.person_id = pm.person_id
   AND w.medication_id = pm.medication_id;

--- v_active_medication: everything about each medication in use, in readable columns ---
-- Grain: one row per person_medication row whose status is not 'not_taking'.
-- refill_status compares next_fill_on with today's date in the time zone of the computer
-- that runs the query. It is 'overdue', 'due', 'due_soon', 'not_due', or 'no_fill'.
-- A specialty medication uses the specialty day counts.
CREATE VIEW v_active_medication AS
SELECT s.person_medication_id,
       p.display_name   AS person_name,
       m.short_name     AS medication_name,
       m.full_name      AS medication_full_name,
       m.is_specialty,
       pm.medication_type,
       s.status,
       CASE WHEN s.next_fill_on IS NULL THEN 'no_fill'
            WHEN s.next_fill_on < date('now', 'localtime') THEN 'overdue'
            WHEN s.next_fill_on <= date('now', 'localtime', '+' ||
                 CASE WHEN m.is_specialty THEN r.specialty_due_within_days
                      ELSE r.due_within_days END || ' days') THEN 'due'
            WHEN s.next_fill_on <= date('now', 'localtime', '+' ||
                 CASE WHEN m.is_specialty THEN r.specialty_due_soon_within_days
                      ELSE r.due_soon_within_days END || ' days') THEN 'due_soon'
            ELSE 'not_due' END AS refill_status,
       CAST(julianday(s.next_fill_on) - julianday(date('now', 'localtime')) AS INTEGER) AS days_until_next_fill,
       s.next_fill_on,
       s.recommended_next_fill_on,
       s.days_supply_missing,
       s.refills_left,
       ph.name          AS pharmacy_name,
       CASE WHEN pr.id IS NULL THEN 'Self-prescribed'
            WHEN pr.clinic IS NULL THEN pr.name
            ELSE pr.name || ' (' || pr.clinic || ')' END AS prescriber_name,
       pm.prescribed_for,
       pm.instructions,
       pm.when_to_take,
       s.last_fill_id,
       s.last_filled_on,
       s.last_days_supply,
       lph.name         AS last_fill_pharmacy_name
  FROM v_supply s
  JOIN person_medication pm ON pm.id = s.person_medication_id   -- 1:1
  JOIN person p             ON p.id = s.person_id               -- many:1
  JOIN v_medication m       ON m.medication_id = s.medication_id -- many:1
  CROSS JOIN v_reminder_setting r                               -- exactly one row
  LEFT JOIN pharmacy ph     ON ph.id = pm.pharmacy_id           -- many:0..1
  LEFT JOIN prescriber pr   ON pr.id = pm.prescriber_id         -- many:0..1
  LEFT JOIN pharmacy lph    ON lph.id = s.last_pharmacy_id      -- many:0..1
 WHERE s.status <> 'not_taking';

--- v_spending_by_year: what each person paid in each year ---
-- Grain: one row per person per calendar year with at least one fill.
CREATE VIEW v_spending_by_year AS
SELECT f.person_id,
       strftime('%Y', f.filled_on) AS year,
       count(*)                    AS fills,
       decimal_sum(f.amount_paid)  AS amount_paid   -- Exact; SUM() would return a float
  FROM fill f
 GROUP BY f.person_id, strftime('%Y', f.filled_on);

--- v_row_count: how many rows each table holds ---
-- Grain: one row per table. Used to check an import against its source.
CREATE VIEW v_row_count AS
SELECT 'person' AS table_name, count(*) AS row_count FROM person
UNION ALL SELECT 'medication', count(*) FROM medication
UNION ALL SELECT 'medication_alias', count(*) FROM medication_alias
UNION ALL SELECT 'pharmacy', count(*) FROM pharmacy
UNION ALL SELECT 'prescriber', count(*) FROM prescriber
UNION ALL SELECT 'person_medication', count(*) FROM person_medication
UNION ALL SELECT 'fill', count(*) FROM fill
UNION ALL SELECT 'prior_authorization', count(*) FROM prior_authorization
UNION ALL SELECT 'profile', count(*) FROM profile;
