-- This file is part of Medication Tracker
-- apps/meds/lib/routes/medications.lua
-- Author(s): Gabriel Mongefranco
-- Created: 2026-09-27
-- Last Modified: 2026-10-05
-- Summary: The screens for what each person tracks: the lists with their search, the page of
--          one tracked medication with its products, the forms, and the list made for paper.
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

local pv                = require 'privatium'
local catalog_entry     = require 'catalog_entry'
local choices           = require 'choices'
local clock             = require 'clock'
local entries           = require 'entries'
local medication_search = require 'medication_search'
local page              = require 'page'
local people_filter     = require 'people_filter'
local product_pick      = require 'product_pick'
local quick_add         = require 'quick_add'
local store             = require 'store'
local suggestions       = require 'suggestions'
local starter           = require 'starter'
local text              = require 'text'
local validate          = require 'validate'

--- Configuration ---
local LIST         = '/medications'
local CHOICE_MAX   = 60
local NAME_MAX     = 200
local PURPOSE_MAX  = 200
local INSTRUCT_MAX = 300
local NOTES_MAX    = 500
local REFILLS_MAX  = 99
local FIELDS       = { 'person_id', 'products', 'product_id', 'display_name', 'status',
                       'medication_type', 'pharmacy_id', 'prescriber_id', 'prescribed_for',
                       'instructions', 'when_to_take', 'notes', 'refills_left' }
local SEARCH       = LIST .. '/search'   -- Answers the search box of the product picker with JSON
local ADD_HEADING    = 'Track new medication'
local CHANGE_HEADING = 'Change a medication'

--- Reads ---

local function values_of(rows)
  local values = {}
  for _, row in ipairs(rows) do values[#values + 1] = row.value end
  return values
end

-- Everything the entry form offers to choose from.
local function offered()
  return {
    people      = quick_add.options(quick_add.PERSON),
    pharmacies  = quick_add.options(quick_add.PHARMACY),
    prescribers = quick_add.options(quick_add.PRESCRIBER),
    purposes     = suggestions.purposes(),
    instructions = suggestions.instructions(),
    statuses = choices.STATUSES,
    medication_type = choices.merge(choices.MEDICATION_TYPES, values_of(pv.query(
      'SELECT DISTINCT medication_type AS value FROM person_medication WHERE medication_type IS NOT NULL'))),
    when_to_take = choices.merge(choices.TIMES_TO_TAKE, values_of(pv.query(
      'SELECT DISTINCT when_to_take AS value FROM person_medication WHERE when_to_take IS NOT NULL'))),
    catalog_options = catalog_entry.options(),
  }
end

-- Grain: one row per fill of one tracked medication, newest first, with the product
-- that was dispensed.
local function fills_of(person_medication_id)
  local rows = pv.query([[
    SELECT f.id, f.filled_on, f.quantity, f.days_supply, f.amount_paid, f.rx_number, f.notes,
           ph.name AS pharmacy_name,
           m.short_name AS product_name
      FROM fill f
      LEFT JOIN pharmacy ph  ON ph.id = f.pharmacy_id    -- many:0..1
      LEFT JOIN medication m ON m.id = f.medication_id   -- many:0..1
     WHERE f.person_medication_id = ?
     ORDER BY f.filled_on DESC, f.id DESC]], { person_medication_id })
  for _, row in ipairs(rows) do row.quantity = text.plain_number(row.quantity) end
  return rows
end

-- Grain: one row, the number of fills and the exact total paid.
local function paid_for(person_medication_id)
  local paid = pv.query1([[
    SELECT count(*) AS fills, decimal_sum(amount_paid) AS amount_paid
      FROM fill
     WHERE person_medication_id = ?]], { person_medication_id })
  paid.counted = page.counted(paid.fills, 'fill', 'fills')
  return paid
end

-- Grain: one row per prior authorization of one tracked medication, with its state on
-- today's local date.
local function authorizations_of(person_medication_id)
  return pv.query([[
    SELECT id, valid_from, valid_to,
           CASE WHEN valid_to < date('now', 'localtime') THEN 'Expired'
                WHEN valid_from > date('now', 'localtime') THEN 'Not started'
                ELSE 'Active' END AS state
      FROM prior_authorization
     WHERE person_medication_id = ?
     ORDER BY valid_to DESC, id]], { person_medication_id })
end

-- How many records still point to a tracked medication, as phrases for the removal page.
local function uses(person_medication_id)
  local counts = pv.query1([[
    SELECT (SELECT count(*) FROM fill                WHERE person_medication_id = ?1) AS fills,
           (SELECT count(*) FROM prior_authorization WHERE person_medication_id = ?1) AS authorizations]],
    { person_medication_id })
  local list = {}
  if counts.fills > 0 then list[#list + 1] = page.counted(counts.fills, 'fill', 'fills') end
  if counts.authorizations > 0 then
    list[#list + 1] = page.counted(counts.authorizations, 'prior authorization', 'prior authorizations')
  end
  return list
end

--- Validation ---

local function read_choice(form, name, label, list)
  local value, problem = validate.text(form[name .. '_new'], label, CHOICE_MAX)
  if problem then return nil, problem end
  if not value then
    value, problem = validate.text(form[name], label, CHOICE_MAX)
    -- The choice to add, with nothing typed, adds nothing.
    if value == 'new' then value = nil end
    if not value then return nil, problem end
  end
  local key = text.key(value)
  for _, choice in ipairs(list) do
    if text.key(choice) == key then return choice end
  end
  return value
end

-- Reads a tracked medication with the records it may add beside it: a person, the
-- products that are new to the catalog, a pharmacy and a prescriber.
-- @return table, table, table  The row, the problems, and what to add in the batch.
--         `adding.acted` is true when the form asked to add or remove a product; the
--         form then comes back instead of saving.
local function read(form, existing, lists)
  local row, errors, adding = {}, {}, {}
  adding.chosen, adding.pick, errors.products, adding.acted = product_pick.handle(form)
  errors.product_id = adding.pick and adding.pick.problem
  if existing then
    -- The person of a tracked medication never changes. To move it, remove it and add
    -- it again under the other person.
    row.person_id, adding.person_id = existing.person_id, existing.person_id
  else
    adding.person_id, adding.person, errors.person_id =
      quick_add.read(form, 'person_id', quick_add.PERSON, true)
    row.person_id = adding.person_id
  end

  row.display_name, errors.display_name =
    validate.text(form.display_name, 'the preferred name', NAME_MAX, true)
  row.status = text.clean(form.status)
  if not choices.status_label(row.status) then
    row.status, errors.status = nil, 'Choose a status.'
  end
  row.medication_type, errors.medication_type =
    read_choice(form, 'medication_type', 'the type', lists.medication_type)
  row.when_to_take, errors.when_to_take =
    read_choice(form, 'when_to_take', 'when to take it', lists.when_to_take)
  adding.pharmacy_id, adding.pharmacy, errors.pharmacy_id =
    quick_add.read(form, 'pharmacy_id', quick_add.PHARMACY)
  adding.prescriber_id, adding.prescriber, errors.prescriber_id =
    quick_add.read(form, 'prescriber_id', quick_add.PRESCRIBER)
  row.pharmacy_id, row.prescriber_id = adding.pharmacy_id, adding.prescriber_id
  row.prescribed_for, errors.prescribed_for =
    validate.text(form.prescribed_for, 'the reason', PURPOSE_MAX)
  row.instructions, errors.instructions =
    validate.text(form.instructions, 'the instructions', INSTRUCT_MAX)
  row.notes, errors.notes = validate.text(form.notes, 'the notes', NOTES_MAX)
  row.refills_left, errors.refills_left =
    validate.whole_number(form.refills_left, 'the refills left', 0, REFILLS_MAX, true)
  if adding.acted then return row, errors, adding end

  if not errors.products and #adding.chosen == 0 then
    errors.products = 'Add at least one product.'
  end
  -- A preferred name is unique within one person. Two people may use the same name.
  if row.person_id and row.display_name
     and entries.named(row.person_id, row.display_name, existing and existing.id) then
    errors.display_name = 'This person already has a medication with this name. Choose another name.'
  end
  -- One product belongs to one tracked medication of a person, or its fills would
  -- count twice.
  if row.person_id and not errors.products then
    for _, product in ipairs(adding.chosen) do
      local other = product.id and entries.with_product(row.person_id, product.id)
      if other and other.id ~= (existing and existing.id) then
        errors.products = product.full_name .. ' is already on the list for this person, under '
          .. other.display_name .. '. A product can be on one medication per person.'
        break
      end
    end
  end
  -- A product that fills name stays, or those fills would name nothing.
  if existing and not errors.products then
    local kept = {}
    for _, product in ipairs(adding.chosen) do
      if product.id then kept[product.id] = true end
    end
    for _, product in ipairs(entries.products(existing.id)) do
      local fills = not kept[product.medication_id]
        and product_pick.fills_naming(existing.id, product.medication_id) or 0
      if fills > 0 then
        errors.products = page.counted(fills, 'fill names', 'fills name') .. ' ' .. product.full_name
          .. '. Change those fills before you remove it.'
        break
      end
    end
  end
  return row, errors, adding
end

-- Writes a tracked medication, its products and the new records beside it in one batch.
-- @return string|nil, string|nil  The id of the tracked medication, or nil and a message.
local function save(id, row, adding)
  local entry_id
  local saved, refusal = store.together('person_medication', function(tx)
    row.person_id     = quick_add.write(tx, quick_add.PERSON, adding.person_id, adding.person)
    local product_ids = product_pick.write(tx, adding.chosen)
    row.pharmacy_id   = quick_add.write(tx, quick_add.PHARMACY, adding.pharmacy_id, adding.pharmacy)
    row.prescriber_id =
      quick_add.write(tx, quick_add.PRESCRIBER, adding.prescriber_id, adding.prescriber)
    if id then
      tx.append('person_medication', id, row)
      entry_id = id
    else
      entry_id = tx.append('person_medication', row)
    end
    -- The links follow the products of the form: a link is added for a product that
    -- is new to the entry and removed for one that was taken off.
    local linked = {}
    if id then
      for _, product in ipairs(entries.products(id)) do linked[product.medication_id] = product.link_id end
    end
    local wanted = {}
    for _, product_id in ipairs(product_ids) do
      wanted[product_id] = true
      if not linked[product_id] then
        tx.append('person_medication_product', { person_medication_id = entry_id, medication_id = product_id })
      end
    end
    for product_id, link_id in pairs(linked) do
      if not wanted[product_id] then tx.delete('person_medication_product', link_id) end
    end
  end)
  if not saved then return nil, refusal end
  return entry_id
end

-- The form of a tracked medication. `fixed` names the person when the form is about a
-- stored one; `adding` is what `read` returned, when the form came back.
local function form_page(heading, action, typed, errors, fixed, adding)
  local chosen = adding and adding.chosen or product_pick.read(typed) or {}
  -- The preferred name starts as the full name of the first product.
  if not text.clean(typed.display_name) and chosen[1] then
    typed.display_name = chosen[1].full_name
  end
  return pv.render('entry_form', {
    section    = 'medications',
    heading    = heading,
    action     = action,
    typed      = typed,
    errors     = errors,
    problems   = page.problems(errors, FIELDS),
    offered    = offered(),
    fixed      = fixed,
    chosen     = chosen,
    pick       = adding and adding.pick,
    names      = suggestions.medication_names(),
    add_action = product_pick.ADD,
    find_action = product_pick.FIND,
    search_url = url(SEARCH),
  })
end

-- The values of a form that came back. The product box is emptied after a product was
-- added, and kept while it still asks a question.
local function came_back(form, errors, adding)
  if adding.pick or (adding.acted and errors.products) then
    local copy = {}
    for key, value in pairs(form) do copy[key] = value end
    return copy
  end
  return product_pick.cleared(form)
end

--- Routes ---

-- The Medications page is the home page too. A household with no people sees the
-- welcome instead, since there is nobody to track a medication for yet.
local function list_page(req)
  local filter = people_filter.read(req)
  if #filter.people == 0 then
    return pv.render('index', { section = 'medications', greeting = clock.greeting(clock.hour()) })
  end
  local typed = medication_search.typed(req.query.q)
  local rows = entries.filter(entries.list(filter.id), typed)
  local groups = {}
  for _, status in ipairs(choices.STATUSES) do
    groups[#groups + 1] = { status = status.value, title = status.label, rows = {} }
  end
  for _, row in ipairs(rows) do
    for _, group in ipairs(groups) do
      if group.status == row.status then group.rows[#group.rows + 1] = row end
    end
  end
  local stopped = table.remove(groups)   -- 'No longer taking' is the last status
  return pv.render('medications', {
    section      = 'medications',
    notice       = page.notice(req.query.notice),
    filter       = filter,
    filter_text  = typed,
    matched      = typed ~= '' and page.counted(#rows, 'medication matches', 'medications match') or nil,
    groups       = groups,
    stopped      = stopped,
    -- A match among the medications no longer taken is shown, not hidden in a closed
    -- section.
    stopped_open = typed ~= '' and #stopped.rows > 0,
  })
end

pv.get('/', list_page)
pv.get(LIST, list_page)

-- The search box of the product picker asks here while a person types, and gets the
-- same results the form shows without a script. Registered before the routes that
-- take an id, so 'search' and 'new' are never read as one.
pv.get(SEARCH, function(req)
  local typed = medication_search.typed(req.query.q)
  return pv.json({ term = typed, results = product_pick.search(typed) })
end)

pv.get(LIST .. '/new', function(req)
  starter.ensure()
  local typed = { person_id = text.clean(req.query.person), status = 'taking_regularly', refills_left = 0 }
  -- A link from the catalog names the product to start with.
  typed.product_1_id = text.clean(req.query.medication)
  return form_page(ADD_HEADING, url(LIST .. '/new'), typed, {})
end)

pv.post(LIST .. '/new', function(req)
  local row, errors, adding = read(req.form, nil, offered())
  if adding.acted then
    return form_page(ADD_HEADING, url(LIST .. '/new'), came_back(req.form, errors, adding),
      { products = errors.products, product_id = errors.product_id }, nil, adding)
  end
  if not next(errors) then
    local saved, refusal = save(nil, row, adding)
    if saved then return pv.redirect(url(LIST .. '/' .. saved .. '?notice=saved')) end
    errors.status = refusal
  end
  return form_page(ADD_HEADING, url(LIST .. '/new'), came_back(req.form, errors, adding), errors, nil, adding)
end)

pv.get(LIST .. '/:id', function(req)
  local entry = entries.one(req.params.id)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('entry', {
    section        = 'medications',
    notice         = page.notice(req.query.notice),
    entry          = entry,
    statuses       = choices.STATUSES,
    products       = entries.products(entry.id),
    fills          = fills_of(entry.id),
    paid           = paid_for(entry.id),
    authorizations = authorizations_of(entry.id),
  })
end)

-- The form of a stored tracked medication starts with its values and its products.
local function stored_form(stored)
  local typed = {}
  for key, value in pairs(stored) do typed[key] = value end
  for key, value in pairs(product_pick.carried(entries.products(stored.id))) do typed[key] = value end
  return typed
end

pv.get(LIST .. '/:id/edit', function(req)
  local stored = entries.stored(req.params.id)
  local entry = stored and entries.one(stored.id)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  return form_page(CHANGE_HEADING, url(LIST .. '/' .. stored.id .. '/edit'), stored_form(stored), {},
    { person_name = entry.person_name })
end)

pv.post(LIST .. '/:id/edit', function(req)
  local stored = entries.stored(req.params.id)
  local entry = stored and entries.one(stored.id)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  local action = url(LIST .. '/' .. stored.id .. '/edit')
  local row, errors, adding = read(req.form, stored, offered())
  if adding.acted then
    return form_page(CHANGE_HEADING, action, came_back(req.form, errors, adding),
      { products = errors.products, product_id = errors.product_id }, { person_name = entry.person_name }, adding)
  end
  if not next(errors) then
    local saved, refusal = save(stored.id, row, adding)
    if saved then return pv.redirect(url(LIST .. '/' .. saved .. '?notice=saved')) end
    errors.status = refusal
  end
  return form_page(CHANGE_HEADING, action, came_back(req.form, errors, adding), errors,
    { person_name = entry.person_name }, adding)
end)

-- A change of status alone, from the page of the entry or the Restart button of the
-- list. Every other column is carried over, because an amendment replaces the whole row.
pv.post(LIST .. '/:id/status', function(req)
  local stored = entries.stored(req.params.id)
  if not stored then return pv.redirect(url(LIST .. '?notice=missing')) end
  local status = text.clean(req.form.status)
  if not choices.status_label(status) then
    return pv.redirect(url(LIST .. '/' .. stored.id))
  end
  local id = stored.id
  stored.id, stored.status = nil, status
  local saved = store.save('person_medication', id, stored)
  if text.clean(req.form.back) == 'list' then
    return pv.redirect(url(LIST .. '?person=' .. stored.person_id .. (saved and '&notice=saved' or '')))
  end
  return pv.redirect(url(LIST .. '/' .. id .. (saved and '?notice=saved' or '')))
end)

pv.get(LIST .. '/:id/remove', function(req)
  local entry = entries.one(req.params.id)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'medications',
    heading = 'Remove a medication',
    name    = entry.medication_name .. ', on the list of ' .. entry.person_name,
    used_by = uses(entry.id),
    note    = 'To keep it on the list as no longer taking, change its status instead.',
    action  = url(LIST .. '/' .. entry.id .. '/remove'),
    back    = url(LIST .. '/' .. entry.id),
  })
end)

pv.post(LIST .. '/:id/remove', function(req)
  local stored = entries.stored(req.params.id)
  if not stored then return pv.redirect(url(LIST .. '?notice=missing')) end
  -- A tracked medication with fills or prior authorizations stays, or those records
  -- would name nothing.
  if #uses(stored.id) > 0 then return pv.redirect(url(LIST .. '/' .. stored.id .. '/remove')) end
  local products = entries.products(stored.id)
  local removed = store.together('person_medication', function(tx)
    for _, product in ipairs(products) do tx.delete('person_medication_product', product.link_id) end
    tx.delete('person_medication', stored.id)
  end)
  if not removed then return pv.redirect(url(LIST .. '/' .. stored.id .. '/remove')) end
  return pv.redirect(url(LIST .. '?notice=removed'))
end)

--- Products of a tracked medication ---

-- The product link of a tracked medication, or nil when either is missing.
local function link_of(req)
  local entry = entries.one(req.params.id)
  if not entry then return nil end
  for _, product in ipairs(entries.products(entry.id)) do
    if product.link_id == req.params.link_id then return entry, product end
  end
  return nil
end

-- Why a product cannot be taken off a tracked medication, as phrases.
local function product_uses(entry, product)
  local list = {}
  if #entries.products(entry.id) == 1 then
    list[#list + 1] = 'this medication, which needs at least one product'
  end
  local fills = product_pick.fills_naming(entry.id, product.medication_id)
  if fills > 0 then list[#list + 1] = page.counted(fills, 'fill', 'fills') end
  return list
end

pv.get(LIST .. '/:id/products/:link_id/remove', function(req)
  local entry, product = link_of(req)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  return pv.render('remove', {
    section = 'medications',
    heading = 'Remove a product',
    name    = product.full_name,
    used_by = product_uses(entry, product),
    note    = 'The product is taken off ' .. entry.medication_name .. '. It stays in the catalog.',
    action  = url(LIST .. '/' .. entry.id .. '/products/' .. product.link_id .. '/remove'),
    back    = url(LIST .. '/' .. entry.id),
  })
end)

pv.post(LIST .. '/:id/products/:link_id/remove', function(req)
  local entry, product = link_of(req)
  if not entry then return pv.redirect(url(LIST .. '?notice=missing')) end
  if #product_uses(entry, product) > 0 then
    return pv.redirect(url(LIST .. '/' .. entry.id .. '/products/' .. product.link_id .. '/remove'))
  end
  pv.delete('person_medication_product', product.link_id)
  return pv.redirect(url(LIST .. '/' .. entry.id .. '?notice=removed'))
end)

--- The list made for paper ---

pv.get('/people/:id/medication-list', function(req)
  local person = pv.get_row('person', req.params.id)
  if not person then return pv.redirect(url(LIST .. '?notice=missing')) end
  local taking, on_hold = {}, {}
  for _, row in ipairs(entries.list(person.id)) do
    if row.status == 'taking_regularly' or row.status == 'taking_as_needed' then
      taking[#taking + 1] = row
    elseif row.status == 'on_hold' then
      on_hold[#on_hold + 1] = row
    end
  end
  return pv.render('medication_list', {
    section = 'medications',
    person  = person,
    today   = clock.today(),
    taking  = taking,
    on_hold = on_hold,
  })
end)
