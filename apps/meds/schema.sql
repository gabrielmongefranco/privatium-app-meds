-- This file is part of Prescription Tracker
-- apps/meds/schema.sql
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-26
-- Last Modified: 2026-10-01
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
    early_fill_percent             BIGINT,
    supply_frame_days              BIGINT,
    controlled_early_days          BIGINT,
    CHECK (early_fill_percent IS NULL OR early_fill_percent BETWEEN 0 AND 100),
    CHECK (supply_frame_days IS NULL OR supply_frame_days BETWEEN 0 AND 3650),
    CHECK (controlled_early_days IS NULL OR controlled_early_days BETWEEN 0 AND 365),
    CHECK (due_within_days IS NULL OR due_within_days >= 0),
    CHECK (due_soon_within_days IS NULL OR due_soon_within_days >= 0),
    CHECK (specialty_due_within_days IS NULL OR specialty_due_within_days >= 0),
    CHECK (specialty_due_soon_within_days IS NULL OR specialty_due_soon_within_days >= 0),
    CHECK (authorization_notice_days IS NULL OR authorization_notice_days >= 0),
    CHECK (authorization_due_within_days IS NULL OR authorization_due_within_days >= 0)
);

--- plan: refill rules for one payer ---
-- Grain: one row per plan. NULL overrides inherit the household settings.
-- Zero frame days counts the last fill only; 3650 counts the complete history.
CREATE TABLE plan (
    id                 VARCHAR PRIMARY KEY,
    name               VARCHAR NOT NULL,
    early_fill_percent BIGINT,
    supply_frame_days  BIGINT,
    CHECK (early_fill_percent IS NULL OR early_fill_percent BETWEEN 0 AND 100),
    CHECK (supply_frame_days IS NULL OR supply_frame_days BETWEEN 0 AND 3650)
);

--- person: a household member ---
-- Grain: one row per person whose medications the household tracks.
CREATE TABLE person (
    id           VARCHAR PRIMARY KEY,
    display_name VARCHAR NOT NULL,   -- Personal information
    birth_date   DATE,               -- Personal information; optional
    plan_id      VARCHAR             -- plan.id; NULL means no default payer
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
    is_controlled BOOLEAN,           -- NULL means unmarked; controlled supply counts across payers
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

--- person_medication: what each person tracks ---
-- Grain: one row per medication a person takes or took, under the name the person prefers.
-- The catalog products it stands for are the rows of person_medication_product; a
-- medication that comes in two cartons is one row here with two products.
CREATE TABLE person_medication (
    id              VARCHAR PRIMARY KEY,
    person_id       VARCHAR NOT NULL,   -- person.id
    display_name    VARCHAR NOT NULL,   -- The preferred name, shown everywhere; unique within one person
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

--- person_medication_product: the catalog products of a tracked medication ---
-- Grain: one row per tracked medication per catalog product. Every tracked medication
-- has at least one; the forms refuse to remove the last. One product belongs to one
-- tracked medication of a person, so its fills are never counted twice.
CREATE TABLE person_medication_product (
    id                   VARCHAR PRIMARY KEY,
    person_medication_id VARCHAR NOT NULL,   -- person_medication.id
    medication_id        VARCHAR NOT NULL    -- medication.id
);

--- fill: each time a medication was picked up or delivered ---
-- Grain: one row per fill of one tracked medication. The person is the one of the
-- tracked medication. medication_id names the product that was dispensed, one of the
-- products of the tracked medication, so two carton sizes stay apart in the history.
CREATE TABLE fill (
    id                     VARCHAR PRIMARY KEY,
    person_medication_id   VARCHAR NOT NULL,   -- person_medication.id
    medication_id          VARCHAR,            -- medication.id; NULL when the product is not known
    pharmacy_id            VARCHAR NOT NULL,   -- pharmacy.id
    filled_on              DATE NOT NULL,      -- Calendar date on the label; no time zone
    rx_number              VARCHAR,
    quantity               DECIMAL(18,3),      -- Units dispensed; three places because some fills are a fraction of a package
    days_supply            BIGINT,             -- Days the fill should last; NULL when the label does not say
    amount_paid            DECIMAL(18,2),      -- What the household paid, in the household's own currency
    plan_id                VARCHAR,            -- plan.id; NULL means the payer is unknown
    insurance_claim_number VARCHAR,
    notes                  VARCHAR,
    CHECK (days_supply IS NULL OR days_supply >= 0),
    CHECK (quantity IS NULL OR decimal_cmp(quantity, '0') >= 0),
    CHECK (amount_paid IS NULL OR decimal_cmp(amount_paid, '0') >= 0)
);

--- prior_authorization: an insurer's approval window ---
-- Grain: one row per approval window for one tracked medication. An insurer approves
-- the drug for one member, whatever carton it comes in.
CREATE TABLE prior_authorization (
    id                   VARCHAR PRIMARY KEY,
    person_medication_id VARCHAR NOT NULL,   -- person_medication.id
    valid_from           DATE,               -- The first day the approval covers; NULL when the household does not know it
    valid_to             DATE NOT NULL,      -- The expiration date: the last day the approval covers
    CHECK (valid_from IS NULL OR valid_to >= valid_from)
);

CREATE INDEX ix_fill_entry ON fill (person_medication_id, filled_on);
CREATE INDEX ix_person_medication_person ON person_medication (person_id);
CREATE INDEX ix_tracked_product_entry ON person_medication_product (person_medication_id);
CREATE INDEX ix_tracked_product_medication ON person_medication_product (medication_id);
CREATE INDEX ix_prior_authorization_entry ON prior_authorization (person_medication_id);
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
       14 AS authorization_due_within_days,
       25 AS early_fill_percent,
       180 AS supply_frame_days,
       0 AS controlled_early_days;

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
                d.authorization_due_within_days)  AS authorization_due_within_days,
       coalesce((SELECT max(p.early_fill_percent) FROM profile p),
                d.early_fill_percent)              AS early_fill_percent,
       coalesce((SELECT max(p.supply_frame_days) FROM profile p),
                d.supply_frame_days)               AS supply_frame_days,
       coalesce((SELECT max(p.controlled_early_days) FROM profile p),
                d.controlled_early_days)           AS controlled_early_days
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
       m.is_controlled,
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

--- v_tracked_product: the products of each tracked medication, with their names ---
-- Grain: one row per tracked medication per catalog product. position orders the
-- products of one tracked medication by short name; the first one lends its icon.
CREATE VIEW v_tracked_product AS
SELECT tp.id AS link_id,
       tp.person_medication_id,
       pm.person_id,
       m.medication_id,
       m.short_name,
       m.full_name,
       m.generic_name,
       m.brand_name,
       m.strength,
       m.route,
       m.form,
       m.package_type,
       m.is_specialty,
       m.is_controlled,
       row_number() OVER (PARTITION BY tp.person_medication_id
                          ORDER BY m.short_name COLLATE NOCASE, m.medication_id) AS position
  FROM person_medication_product tp
  JOIN person_medication pm ON pm.id = tp.person_medication_id   -- many:1
  JOIN v_medication m       ON m.medication_id = tp.medication_id -- many:1
;

--- v_entry_mark: the marks of a tracked medication, taken from its products ---
-- Grain: one row per tracked medication that has at least one product. A mark is 1
-- when any product carries it, else 0, so SQL and Lua can both test it.
CREATE VIEW v_entry_mark AS
SELECT tp.person_medication_id,
       count(*) AS products,
       max(CASE WHEN tp.is_specialty THEN 1 ELSE 0 END)  AS is_specialty,
       max(CASE WHEN tp.is_controlled THEN 1 ELSE 0 END) AS is_controlled
  FROM v_tracked_product tp
 GROUP BY tp.person_medication_id;

--- v_last_fill: the latest fill of each tracked medication ---
-- Grain: one row per tracked medication that has at least one fill.
-- The latest date wins. Two fills on one day are ordered by id, and the fill entered
-- later has the greater id. The view leaves out the DECIMAL columns, so any SQLite tool
-- can run it and the views built on it; read those columns from fill by fill_id.
CREATE VIEW v_last_fill AS
SELECT r.id AS fill_id,
       r.person_medication_id,
       r.medication_id,
       r.pharmacy_id,
       r.filled_on,
       r.rx_number,
       r.days_supply,
       r.plan_id
  FROM (SELECT f.id, f.person_medication_id, f.medication_id, f.pharmacy_id, f.filled_on,
               f.rx_number, f.days_supply, f.plan_id,
               row_number() OVER (PARTITION BY f.person_medication_id
                                  ORDER BY f.filled_on DESC, f.id DESC) AS recency
          FROM fill f) r
 WHERE r.recency = 1;

--- v_fill_order: supply and payer membership of each fill ---
-- Grain: one row per fill; seq orders the fills of a tracked medication by date and id.
-- Unknown payers count because excluding them could suggest an early refill.
CREATE VIEW v_fill_order AS
SELECT f.id AS fill_id, f.person_medication_id, f.filled_on, f.plan_id,
       coalesce(f.days_supply, 1) AS days,
       row_number() OVER (PARTITION BY f.person_medication_id
                          ORDER BY f.filled_on, f.id) AS seq,
       CASE WHEN coalesce(e.is_controlled, 0) THEN 1
            WHEN f.plan_id IS NULL OR l.plan_id IS NULL OR f.plan_id = l.plan_id THEN 1
            ELSE 0 END AS counts
  FROM fill f
  LEFT JOIN v_entry_mark e ON e.person_medication_id = f.person_medication_id   -- many:0..1
  JOIN v_last_fill l ON l.person_medication_id = f.person_medication_id;        -- many:1

--- v_supply_fill: supply remaining after each possible start ---
-- Grain: one row per fill. NULL days supply counts as one day; zero stays zero.
-- The latest end date discards gaps while preserving every early fill's supply.
CREATE VIEW v_supply_fill AS
SELECT o.fill_id, o.person_medication_id, o.filled_on, o.seq, o.counts,
       date(o.filled_on, '+' || sum(o.days) OVER (
           PARTITION BY o.person_medication_id ORDER BY o.seq
           ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) || ' days') AS ends_on,
       CASE WHEN o.counts THEN date(o.filled_on, '+' || sum(
           CASE WHEN o.counts THEN o.days ELSE 0 END) OVER (
           PARTITION BY o.person_medication_id ORDER BY o.seq
           ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) || ' days') END AS insurer_ends_on
  FROM v_fill_order o;

--- v_supply_frame: earliest refill date under the payer's rolling count ---
-- Grain: one row per tracked medication with a fill. Joins preserve that grain.
-- Each candidate waits for older counted fills to leave; an empty frame permits a fill.
CREATE VIEW v_supply_frame AS
SELECT c.person_medication_id, max(c.allowance) AS allowance,
       min(min(max(date(c.ends_by_here, '-' || c.allowance || ' days'),
                   coalesce(date(c.older_filled_on, '+' || (c.frame_days + 1) || ' days'),
                            '0001-01-01')),
               CASE WHEN c.frame_days BETWEEN 1 AND 3649
                    THEN date(c.last_filled_on, '+' || (c.frame_days + 1) || ' days')
                    ELSE '9999-12-31' END)) AS next_fill_on
  FROM (SELECT sf.person_medication_id,
               max(sf.insurer_ends_on) OVER (
                   PARTITION BY sf.person_medication_id ORDER BY sf.seq DESC
                   ROWS UNBOUNDED PRECEDING) AS ends_by_here,
               lead(sf.filled_on) OVER (
                   PARTITION BY sf.person_medication_id ORDER BY sf.seq DESC) AS older_filled_on,
               a.allowance, a.frame_days, a.last_filled_on
          FROM v_supply_fill sf
          JOIN (SELECT l.person_medication_id, l.fill_id, l.filled_on AS last_filled_on,
                       CASE WHEN coalesce(e.is_controlled, 0) THEN r.controlled_early_days
                            ELSE CAST((coalesce(l.days_supply, 1) *
                                 coalesce(p.early_fill_percent, r.early_fill_percent)) / 100 AS INTEGER)
                            END AS allowance,
                       CASE WHEN coalesce(e.is_controlled, 0) THEN 3650
                            ELSE coalesce(p.supply_frame_days, r.supply_frame_days) END AS frame_days
                  FROM v_last_fill l
                  LEFT JOIN v_entry_mark e ON e.person_medication_id = l.person_medication_id  -- many:0..1
                  LEFT JOIN plan p ON p.id = l.plan_id              -- many:0..1
                  CROSS JOIN v_reminder_setting r) a               -- exactly one setting row
            ON a.person_medication_id = sf.person_medication_id  -- many:1
         WHERE sf.counts AND (a.frame_days <> 0 OR sf.fill_id = a.fill_id)) c
 WHERE c.frame_days <> 3650 OR c.older_filled_on IS NULL
 GROUP BY c.person_medication_id;

--- v_supply: refill eligibility and physical supply for each tracked medication ---
-- Grain: one row per person_medication row. A missing fill leaves both dates NULL.
-- A zero-percent payer waits for physical supply to run out, including other payers.
CREATE VIEW v_supply AS
SELECT pm.id AS person_medication_id, pm.person_id,
       pm.status, pm.refills_left,
       l.fill_id AS last_fill_id, l.filled_on AS last_filled_on,
       l.pharmacy_id AS last_pharmacy_id, l.plan_id AS last_plan_id,
       l.medication_id AS last_medication_id,
       l.days_supply AS last_days_supply,
       CASE WHEN l.fill_id IS NOT NULL AND l.days_supply IS NULL THEN 1 ELSE 0 END AS days_supply_missing,
       physical.lasts_until, frame.allowance,
       CASE WHEN NOT coalesce(e.is_controlled, 0)
                  AND coalesce(p.early_fill_percent, r.early_fill_percent) = 0
            THEN physical.lasts_until ELSE frame.next_fill_on END AS next_fill_on
  FROM person_medication pm
  LEFT JOIN v_last_fill l ON l.person_medication_id = pm.id         -- 1:0..1
  LEFT JOIN (SELECT person_medication_id, max(ends_on) AS lasts_until
               FROM v_supply_fill GROUP BY person_medication_id) physical
    ON physical.person_medication_id = pm.id                         -- 1:0..1
  LEFT JOIN v_supply_frame frame ON frame.person_medication_id = pm.id  -- 1:0..1
  LEFT JOIN v_entry_mark e ON e.person_medication_id = pm.id         -- 1:0..1
  LEFT JOIN plan p ON p.id = l.plan_id                                 -- many:0..1
  CROSS JOIN v_reminder_setting r;

--- v_active_medication: everything about each medication in use, in readable columns ---
-- Grain: one row per person_medication row whose status is not 'not_taking'.
-- Eligibility uses next_fill_on; overdue uses lasts_until, both against local today.
-- The query uses the time zone of the computer that runs it. It is 'overdue', 'due', 'due_soon', 'not_due', or 'no_fill'.
-- A specialty medication uses the specialty day counts. The marks come from the
-- products, as 1 or 0.
CREATE VIEW v_active_medication AS
SELECT s.person_medication_id,
       p.display_name   AS person_name,
       pm.display_name  AS medication_name,
       coalesce(e.is_specialty, 0)  AS is_specialty,
       coalesce(e.is_controlled, 0) AS is_controlled,
       coalesce(e.products, 0)      AS products,
       pm.medication_type,
       s.status,
       CASE WHEN s.lasts_until IS NULL THEN 'no_fill'
            WHEN s.lasts_until < date('now', 'localtime') THEN 'overdue'
            WHEN s.next_fill_on <= date('now', 'localtime', '+' ||
                 CASE WHEN coalesce(e.is_specialty, 0) THEN r.specialty_due_within_days
                      ELSE r.due_within_days END || ' days') THEN 'due'
            WHEN s.next_fill_on <= date('now', 'localtime', '+' ||
                 CASE WHEN coalesce(e.is_specialty, 0) THEN r.specialty_due_soon_within_days
                      ELSE r.due_soon_within_days END || ' days') THEN 'due_soon'
            ELSE 'not_due' END AS refill_status,
       CAST(julianday(s.next_fill_on) - julianday(date('now', 'localtime')) AS INTEGER) AS days_until_next_fill,
       s.next_fill_on,
       s.lasts_until,
       s.allowance,
       CAST(julianday(s.lasts_until) - julianday(date('now', 'localtime')) AS INTEGER) AS days_until_runs_out,
       pl.name AS plan_name,
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
  LEFT JOIN v_entry_mark e  ON e.person_medication_id = pm.id   -- 1:0..1
  CROSS JOIN v_reminder_setting r                               -- exactly one row
  LEFT JOIN plan pl         ON pl.id = s.last_plan_id           -- many:0..1
  LEFT JOIN pharmacy ph     ON ph.id = pm.pharmacy_id           -- many:0..1
  LEFT JOIN prescriber pr   ON pr.id = pm.prescriber_id         -- many:0..1
  LEFT JOIN pharmacy lph    ON lph.id = s.last_pharmacy_id      -- many:0..1
 WHERE s.status <> 'not_taking';

--- v_spending_by_year: what each person paid in each year ---
-- Grain: one row per person per calendar year with at least one fill.
CREATE VIEW v_spending_by_year AS
SELECT pm.person_id,
       strftime('%Y', f.filled_on) AS year,
       count(*)                    AS fills,
       decimal_sum(f.amount_paid)  AS amount_paid   -- Exact; SUM() would return a float
  FROM fill f
  JOIN person_medication pm ON pm.id = f.person_medication_id   -- many:1
 GROUP BY pm.person_id, strftime('%Y', f.filled_on);

--- v_row_count: how many rows each table holds ---
-- Grain: one row per table. Used to check an import against its source.
CREATE VIEW v_row_count AS
SELECT 'person' AS table_name, count(*) AS row_count FROM person
UNION ALL SELECT 'medication', count(*) FROM medication
UNION ALL SELECT 'medication_alias', count(*) FROM medication_alias
UNION ALL SELECT 'pharmacy', count(*) FROM pharmacy
UNION ALL SELECT 'prescriber', count(*) FROM prescriber
UNION ALL SELECT 'person_medication', count(*) FROM person_medication
UNION ALL SELECT 'person_medication_product', count(*) FROM person_medication_product
UNION ALL SELECT 'fill', count(*) FROM fill
UNION ALL SELECT 'prior_authorization', count(*) FROM prior_authorization
UNION ALL SELECT 'profile', count(*) FROM profile
UNION ALL SELECT 'plan', count(*) FROM plan;
