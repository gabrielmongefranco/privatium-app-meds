#!/usr/bin/env bash
# This file is part of Prescription Tracker
# tests/smoke.sh
# Author(s): Gabriel Mongefranco
# Created: 2026-09-27
# Last Modified: 2026-09-27
# Summary: Starts a Privatium node on a temporary data directory, loads the sample data,
#          and checks the app's screens over HTTP: normal use, empty and invalid input,
#          boundaries, and requests that must be refused. Uses invented data only.
# Notes: See README file for documentation and full license information.
#
# Copyright © 2026 Gabriel Mongefranco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.
#
# Usage, from the root of the repository:
#   PRIVATIUM=/path/to/privatium tests/smoke.sh
# Exit codes: 0 every check passed, 1 a check failed, 2 the test could not start.

set -u

### Load Configuration ###
PRIVATIUM="${PRIVATIUM:-privatium}"        # The Privatium program to test with
PORT="${MEDS_TEST_PORT:-18490}"            # A port on this computer that nothing else uses
START_TIMEOUT_SECONDS=20                   # How long to wait for the node to answer
REPOSITORY="$(cd "$(dirname "$0")/.." && pwd)"
BASE="http://127.0.0.1:${PORT}"
APP="${BASE}/a/meds"

### Validate Inputs ###
for tool in curl mktemp grep sed; do
  command -v "$tool" >/dev/null 2>&1 || { echo "smoke: $tool is needed and was not found"; exit 2; }
done
command -v "$PRIVATIUM" >/dev/null 2>&1 || {
  echo "smoke: the Privatium program was not found. Set PRIVATIUM to its path."; exit 2; }
[ -f "$REPOSITORY/apps/meds/app.toml" ] || { echo "smoke: apps/meds was not found"; exit 2; }

### Start The Node ###
# The app is copied, not linked, so the test never writes inside the repository.
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/meds-smoke.XXXXXX")" || { echo "smoke: no temporary folder"; exit 2; }
mkdir -p "$ROOT/apps" && cp -R "$REPOSITORY/apps/meds" "$ROOT/apps/meds"
BODY="$ROOT/body.html"
NODE_PID=""

stop_node() {
  if [ -n "$NODE_PID" ]; then
    kill "$NODE_PID" 2>/dev/null
    wait "$NODE_PID" 2>/dev/null
  fi
  # Only the folder this script made is removed.
  case "$ROOT" in
    */meds-smoke.*) rm -rf "$ROOT" ;;
  esac
}
trap stop_node EXIT

"$PRIVATIUM" --data-dir "$ROOT" --port "$PORT" --no-discovery >"$ROOT/node.log" 2>&1 &
NODE_PID=$!

waited=0
until curl -s -o /dev/null -m 2 "$APP/"; do
  waited=$((waited + 1))
  if [ "$waited" -ge "$START_TIMEOUT_SECONDS" ] || ! kill -0 "$NODE_PID" 2>/dev/null; then
    echo "smoke: the node did not start. Its log follows."
    cat "$ROOT/node.log"
    exit 2
  fi
  sleep 1
done

### Helpers ###
passed=0
failed=0

pass() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL  $1"; }

# get <path>: fetches a page of the app into $BODY and prints the status code.
get() { curl -s -m 10 -o "$BODY" -w '%{http_code}' "$APP$1"; }

# token <path>: prints the csrf token of the form on a page of the app.
token() {
  curl -s -m 10 "$APP$1" | grep -o 'name="_csrf" value="[^"]*"' | head -1 | sed 's/.*value="//; s/"$//'
}

# post <form page> <path> [field=value ...]: posts a form with the token of its page.
# Prints the status code and leaves the answer in $BODY.
post() {
  local form_page="$1" path="$2"; shift 2
  local arguments=(--data-urlencode "_csrf=$(token "$form_page")")
  local field
  for field in "$@"; do arguments+=(--data-urlencode "$field"); done
  curl -s -m 10 -o "$BODY" -w '%{http_code}' -X POST "${arguments[@]}" "$APP$path"
}

# expect_status <name> <expected> <actual>
expect_status() { if [ "$3" = "$2" ]; then pass; else fail "$1: expected status $2, got $3"; fi; }

# expect_text <name> <text>: the last answer holds the text.
expect_text() { if grep -qF -- "$2" "$BODY"; then pass; else fail "$1: the page lacks: $2"; fi; }

# expect_no_text <name> <text>: the last answer does not hold the text.
expect_no_text() { if grep -qF -- "$2" "$BODY"; then fail "$1: the page holds: $2"; else pass; fi; }

# count_of <table>: prints how many rows a table holds, read through the data API.
count_of() {
  curl -s -m 10 "$APP/api/q/v_row_count" \
    | grep -o "\"row_count\":[0-9]*,\"table_name\":\"$1\"" | grep -o '[0-9]*' | head -1
}

# id_after <text>: prints the record id in the first link of $BODY that follows a path.
id_in_link() { grep -o "$1/[0-9A-Z]\{26\}" "$BODY" | head -1 | sed 's|.*/||'; }

### Home And Navigation ###
expect_status "home page" 200 "$(get /)"
expect_text "home page invites a household with no name" "Welcome to your prescription tracker."
expect_text "home page has the navigation bar" 'aria-label="Prescription Tracker"'
expect_text "home page marks the current section" 'aria-current="page"'

### Sample Data ###
seed_token="$(curl -s -m 10 "$BASE/settings/apps" \
  | grep -o 'action="/settings/apps/meds/seed"[^>]*>.\{0,300\}' \
  | grep -o 'name="_csrf" value="[^"]*"' | head -1 | sed 's/.*value="//; s/"$//')"
expect_status "sample data loads" 303 "$(curl -s -m 20 -o /dev/null -w '%{http_code}' -X POST \
  --data-urlencode "_csrf=$seed_token" "$BASE/settings/apps/meds/seed")"
expect_status "catalog rows after the sample data" 41 "$(count_of medication)"
expect_status "other names after the sample data" 38 "$(count_of medication_alias)"
expect_status "no person in the sample data" 0 "$(count_of person)"

### Greeting ###
# The greeting follows the local hour, so the expected words come from the local clock.
hour="$(date +%H | sed 's/^0//')"
if [ "$hour" -lt 12 ]; then greeting="Good morning"
elif [ "$hour" -lt 18 ]; then greeting="Good afternoon"
else greeting="Good evening"; fi
expect_status "home page with a name" 200 "$(get /)"
expect_text "greeting follows the local hour" "$greeting, The Example Family."

### Household Name ###
expect_status "empty household name is refused" 200 "$(post /edit /name 'display_name=   ')"
expect_text "empty household name says why" "Enter a name."
expect_status "household name is saved" 303 "$(post /edit /name 'display_name=The Sample Household')"

### Reminder Settings ###
expect_status "reminder settings page" 200 "$(get /setup/reminders)"
expect_text "reminder settings show the default" "Empty means 3."
expect_status "due soon below due is refused" 200 "$(post /setup/reminders /setup/reminders \
  'due_within_days=5' 'due_soon_within_days=2')"
expect_text "due soon below due says why" "Make the days for due soon the same as the days for due, or more."
expect_text "a refused form keeps what was typed" 'value="5"'
expect_status "due soon below the default for due is refused" 200 "$(post /setup/reminders /setup/reminders \
  'due_soon_within_days=2')"
expect_status "a day count above the limit is refused" 200 "$(post /setup/reminders /setup/reminders \
  'due_within_days=366')"
expect_text "a day count above the limit says why" "whole number from 0 to 365"
expect_status "a day count with letters is refused" 200 "$(post /setup/reminders /setup/reminders \
  'due_within_days=ten')"
expect_status "reminder settings are saved" 303 "$(post /setup/reminders /setup/reminders \
  'due_within_days=4' 'due_soon_within_days=8')"
curl -s -m 10 "$APP/api/q/v_reminder_setting" >"$BODY"
expect_text "saved count is in force" '"due_within_days":4'
expect_text "empty count takes its default" '"specialty_due_within_days":5'
expect_status "household name is saved again" 303 "$(post /edit /name 'display_name=The Example Household')"
curl -s -m 10 "$APP/api/q/v_reminder_setting" >"$BODY"
expect_text "saving the name keeps the day counts" '"due_soon_within_days":8'

### People ###
expect_status "people page" 200 "$(get /setup/people)"
expect_text "people page with no one" "No one is in the app yet."
expect_status "person is added" 303 "$(post /setup/people/new /setup/people/new \
  'display_name=Alex Example' 'birth_date=1980-01-31')"
expect_status "people page after adding" 200 "$(get '/setup/people?notice=saved')"
expect_text "people page lists the person" "Alex Example"
expect_text "people page confirms the save" "Saved."
alex="$(id_in_link /setup/people)"

expect_status "empty name is refused" 200 "$(post /setup/people/new /setup/people/new 'display_name=')"
expect_text "empty name says why" "Enter the name."
expect_text "problems are listed at the top" "Check these fields"
expect_status "a date the calendar lacks is refused" 200 "$(post /setup/people/new /setup/people/new \
  'display_name=Sam Example' 'birth_date=2026-02-30')"
expect_text "a date the calendar lacks says why" "year-month-day"
expect_text "a refused form keeps the name" 'value="Sam Example"'
expect_status "a birth date in the future is refused" 200 "$(post /setup/people/new /setup/people/new \
  'display_name=Sam Example' 'birth_date=2999-01-01')"
expect_text "a birth date in the future says why" "not in the future"
expect_status "the same name in other letters is refused" 200 "$(post /setup/people/new /setup/people/new \
  'display_name=  alex   EXAMPLE ')"
expect_text "the same name says why" "already in the app"
expect_status "a name of 121 characters is refused" 200 "$(post /setup/people/new /setup/people/new \
  "display_name=$(printf 'a%.0s' $(seq 1 121))")"
expect_text "a name too long says why" "120 characters or fewer"
expect_status "a name of 120 characters is saved" 303 "$(post /setup/people/new /setup/people/new \
  "display_name=$(printf 'b%.0s' $(seq 1 120))")"

### Requests That Must Be Refused ###
expect_status "a post without the token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -X POST --data-urlencode 'display_name=No Token' "$APP/setup/people/new")"
expect_status "a post with a wrong token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -X POST --data-urlencode '_csrf=0000' --data-urlencode 'display_name=Wrong Token' "$APP/setup/people/new")"
expect_status "markup in a name is saved as text" 303 "$(post /setup/people/new /setup/people/new \
  'display_name=<script>alert(1)</script>')"
expect_status "SQL in a name is saved as text" 303 "$(post /setup/people/new /setup/people/new \
  "display_name=Robert'); DROP TABLE person;--")"
expect_status "people page after hostile names" 200 "$(get /setup/people)"
expect_text "markup in a name is shown escaped" "&lt;script&gt;alert(1)&lt;/script&gt;"
expect_no_text "markup in a name is never sent as markup" "<script>alert(1)</script>"
expect_text "SQL in a name is shown as text" "DROP TABLE person"
expect_status "the person table still holds every person" 4 "$(count_of person)"
expect_status "a notice code that is not known" 200 "$(get '/setup/people?notice=%3Cscript%3Ealert(2)%3C/script%3E')"
expect_no_text "a notice code is never shown" "alert(2)"
expect_status "an id that is not in the app" 303 "$(get /setup/people/01J8MEDS0000000000N0NE0001/edit)"
expect_status "an id that is not an id" 303 "$(get "/setup/people/x'%20OR%201=1/edit")"

### Changing And Removing A Person ###
expect_status "person form shows the stored values" 200 "$(get "/setup/people/$alex/edit")"
expect_text "person form holds the name" 'value="Alex Example"'
expect_text "person form holds the birth date" 'value="1980-01-31"'
expect_status "person is changed" 303 "$(post "/setup/people/$alex/edit" "/setup/people/$alex/edit" \
  'display_name=Alex Example' 'birth_date=')"
curl -s -m 10 "$APP/api/row/person/$alex" >"$BODY"
expect_no_text "an emptied field is cleared" "birth_date"
expect_text "a change keeps the id" "\"id\":\"$alex\""

expect_status "removal asks first" 200 "$(get "/setup/people/$alex/remove")"
expect_text "removal page names the record" "Alex Example"
expect_text "removal page says the log keeps the record" "Privatium keeps the original line in its log"
expect_status "a fill for the person is recorded" 200 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"events\":[{\"op\":\"put\",\"tbl\":\"pharmacy\",\"id\":\"01J8MEDS0000000000TEST0001\",\"d\":{\"name\":\"Example Pharmacy\",\"phone\":\"(555) 555-0100\"}},{\"op\":\"put\",\"tbl\":\"fill\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"01J8MEDS0000000000MED00001\",\"pharmacy_id\":\"01J8MEDS0000000000TEST0001\",\"filled_on\":\"2026-09-01\",\"days_supply\":30}}]}" \
  "$APP/api/events")"
expect_status "removal page for a person with a fill" 200 "$(get "/setup/people/$alex/remove")"
expect_text "a person with a fill cannot be removed" "cannot be removed yet"
expect_text "the page says what uses the person" "1 fill"
# The removal page of a record in use has no form, so the token comes from another form.
# The token is valid for the whole app, which is what a hand-built request would use.
expect_status "removing a person with a fill is refused" 303 "$(post /setup/people/new "/setup/people/$alex/remove")"
expect_status "the person is still there" 4 "$(count_of person)"

get /setup/people >/dev/null
other="$(grep -o '/setup/people/[0-9A-Z]\{26\}/remove' "$BODY" | sed 's|/remove||; s|.*/||' | grep -v "$alex" | head -1)"
expect_status "a person with no records is removed" 303 "$(post "/setup/people/$other/remove" "/setup/people/$other/remove")"
expect_status "one person fewer" 3 "$(count_of person)"

### Contacts ###
expect_status "contacts page" 200 "$(get /contacts)"
expect_text "contacts page lists the pharmacy" "Example Pharmacy"
expect_text "a phone number is a link a phone can dial" 'href="tel:5555550100"'
expect_text "a pharmacy that fills use cannot be removed" "Remove"
expect_status "a script address as a website is refused" 200 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=Sample Pharmacy' 'website=javascript:alert(3)')"
expect_text "a script address says why" "Start the website with https://"
expect_status "a short identifier is refused" 200 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=Sample Pharmacy' 'npi=12345')"
expect_text "a short identifier says why" "10 digits"
expect_status "an email address with no @ is refused" 200 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=Sample Pharmacy' 'email=sample.example.com')"
expect_status "pharmacy is added" 303 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=Sample Pharmacy' 'phone=+1 555 555 0142 x9' 'website=https://pharmacy.example.com' \
  'npi=1234567893' 'email=sample@example.com' 'address=1 Example Street, Anytown')"
expect_status "prescriber is added" 303 "$(post /contacts/prescribers/new /contacts/prescribers/new \
  'name=Dr. Sample' 'clinic=Example Clinic' 'mobile_phone=555-555-0177')"
expect_status "contacts page after adding" 200 "$(get /contacts)"
expect_text "contacts page lists the new pharmacy" "Sample Pharmacy"
expect_text "an extension is left out of the link" 'href="tel:+15555550142"'
expect_text "a website with https is a link" 'href="https://pharmacy.example.com"'
expect_text "contacts page lists the prescriber" "Dr. Sample"
expect_text "contacts page shows the clinic" "Example Clinic"
expect_status "removal page for a pharmacy with a fill" 200 "$(get /contacts/pharmacies/01J8MEDS0000000000TEST0001/remove)"
expect_text "a pharmacy with a fill cannot be removed" "cannot be removed yet"
expect_status "the same pharmacy name is refused" 200 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=sample pharmacy')"
expect_text "the same pharmacy name says why" "already in the app"

### Medication Catalog ###
expect_status "catalog page" 200 "$(get /setup/catalog)"
expect_text "catalog page counts the medications" "41 medications"
expect_status "catalog filtered by another name" 200 "$(get '/setup/catalog?q=apap')"
expect_text "two medications answer to the other name" "2 medications"
expect_status "catalog filtered by a percent sign" 200 "$(get '/setup/catalog?q=%25')"
expect_text "a percent sign alone finds nothing" "No medication answers"
expect_status "catalog filtered by an underscore" 200 "$(get '/setup/catalog?q=_')"
expect_text "an underscore alone finds nothing" "No medication answers"
expect_status "catalog filtered by SQL" 200 "$(get "/setup/catalog?q=%27%20OR%201%3D1%20--")"
expect_text "SQL in the filter matches nothing" "No medication answers"
expect_status "catalog filtered by markup" 200 "$(get '/setup/catalog?q=%3Cimg%20src%3Dx%3E')"
expect_no_text "markup in the filter is never sent as markup" "<img src=x>"

expect_status "a medication with no name is refused" 200 "$(post /setup/catalog/new /setup/catalog/new 'strength=10 mg')"
expect_text "a medication with no name says why" "Enter a brand name or a generic name."
expect_status "medication is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'brand_name=Examplol' 'generic_name=Exampline' 'strength=10 mg' 'route_new=oral' \
  'dose_form=Tablet' 'is_specialty=yes')"
expect_status "catalog filtered by the new medication" 200 "$(get '/setup/catalog?q=examplol')"
expect_text "the short name is built from the parts" "Examplol (Exampline) 10 mg"
expect_text "the full name is built from the parts" "Exampline (Examplol) 10 mg Oral Tablet"
expect_text "a specialty medication says so in words" "Specialty"
examplol="$(id_in_link /setup/catalog)"
expect_status "medication page" 200 "$(get "/setup/catalog/$examplol")"
expect_text "a typed choice takes the spelling of the list" "<dd>Oral</dd>"
expect_status "the same short name is refused" 200 "$(post /setup/catalog/new /setup/catalog/new \
  'brand_name=examplol' 'generic_name=exampline' 'strength=10 MG')"
expect_text "the same short name says why" "already in the catalog"
expect_status "medication is changed" 303 "$(post "/setup/catalog/$examplol/edit" "/setup/catalog/$examplol/edit" \
  'brand_name=Examplol' 'generic_name=Exampline' 'strength=20 mg' 'route=Oral' 'dose_form=Tablet' \
  'short_name=Examplol (Exampline) 10 mg')"
expect_status "medication page after the change" 200 "$(get "/setup/catalog/$examplol")"
expect_text "a built short name follows the strength" "Examplol (Exampline) 20 mg"
expect_no_text "a cleared check box is saved as cleared" "takes longer to arrive"
expect_status "a typed short name is kept" 303 "$(post "/setup/catalog/$examplol/edit" "/setup/catalog/$examplol/edit" \
  'brand_name=Examplol' 'generic_name=Exampline' 'strength=20 mg' 'short_name=exm')"
expect_status "medication page after the typed name" 200 "$(get "/setup/catalog/$examplol")"
expect_text "the typed short name is the heading" "<h1>exm</h1>"
expect_status "a medication with no records is removed" 303 "$(post "/setup/catalog/$examplol/remove" "/setup/catalog/$examplol/remove")"
expect_status "the catalog is back to the sample data" 41 "$(count_of medication)"

expect_status "medication page of the sample data" 200 "$(get /setup/catalog/01J8MEDS0000000000MED00003)"
expect_text "a medication shows its other names" "Z-Pak"
expect_status "removal page for a medication with a fill" 200 "$(get /setup/catalog/01J8MEDS0000000000MED00001/remove)"
expect_text "a medication with a fill cannot be removed" "cannot be removed yet"
expect_status "a medication goes with its other names" 303 "$(post /setup/catalog/01J8MEDS0000000000MED00003/remove \
  /setup/catalog/01J8MEDS0000000000MED00003/remove)"
expect_status "one medication fewer" 40 "$(count_of medication)"
expect_status "one other name fewer" 37 "$(count_of medication_alias)"

### Medication Search, Other Names And Merge ###
expect_status "search by a misspelled name" 200 "$(get '/setup/catalog?q=Lipitro')"
expect_text "a close name is offered as a question" "Did you mean one of these?"
expect_text "the close medication is named" "Lipitor (Atorvastatin) 20 mg"
expect_text "a close name says to check it" "names that look alike"
expect_status "search by the start of a generic name" 200 "$(get '/setup/catalog?q=atorva')"
expect_text "the start of a name finds the medication" "1 medication"
expect_no_text "a contained name is not a question" "Did you mean one of these?"
expect_text "an unknown name can be taught" "Teach the app this name"
expect_status "search by an exact other name" 200 "$(get '/setup/catalog?q=PEG%203350')"
expect_no_text "a known name is not taught again" "Teach the app this name"

lipitor=01J8MEDS0000000000MED00015
expect_status "a name is taught" 303 "$(post /setup/catalog/new "/setup/catalog/$lipitor/names" 'alias=atorva 20')"
expect_status "search by the taught name" 200 "$(get '/setup/catalog?q=ATORVA-20')"
expect_text "the taught name finds the medication" "Lipitor (Atorvastatin) 20 mg"
expect_no_text "the taught name is now known" "Teach the app this name"
expect_status "a name the medication has is refused" 200 "$(post /setup/catalog/new "/setup/catalog/$lipitor/names" 'alias=LIPITOR')"
expect_text "a name the medication has says why" "already answers to that one"
expect_status "an empty other name is refused" 200 "$(post /setup/catalog/new "/setup/catalog/$lipitor/names" 'alias= ')"
expect_status "markup as another name is saved as text" 303 "$(post /setup/catalog/new "/setup/catalog/$lipitor/names" 'alias=<b>bold</b>')"
expect_status "medication page with other names" 200 "$(get "/setup/catalog/$lipitor")"
expect_text "markup in another name is shown escaped" "&lt;b&gt;bold&lt;/b&gt;"
name_id="$(grep -o "/names/[0-9A-Z]\{26\}/remove" "$BODY" | head -1 | sed 's|/names/||; s|/remove||')"
expect_status "removing another name asks first" 200 "$(get "/setup/catalog/$lipitor/names/$name_id/remove")"
expect_status "another name of a different medication is not removed" 303 "$(post /setup/catalog/new \
  "/setup/catalog/01J8MEDS0000000000MED00016/names/$name_id/remove")"
names_before="$(count_of medication_alias)"
expect_status "another name is removed" 303 "$(post "/setup/catalog/$lipitor/names/$name_id/remove" \
  "/setup/catalog/$lipitor/names/$name_id/remove")"
expect_status "one other name fewer after the removal" "$((names_before - 1))" "$(count_of medication_alias)"

# Two entries for one product, as two sources would name it. The second has a fill, a
# list entry and a prior authorization; the person also has the first on their list.
expect_status "the same product under a second name is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'generic_name=Atorvastatin calcium' 'strength=20 mg' 'route=Oral' 'dose_form=Tablet')"
get '/setup/catalog?q=atorvastatin%20calcium%2020' >/dev/null
duplicate="$(grep -o '/setup/catalog/[0-9A-Z]\{26\}"' "$BODY" | sed 's|.*/||; s|"||' | grep -v "$lipitor" | head -1)"
expect_status "records for both entries are recorded" 200 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"events\":[{\"op\":\"put\",\"tbl\":\"fill\",\"id\":\"01J8MEDS0000000000TEST0002\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"$duplicate\",\"pharmacy_id\":\"01J8MEDS0000000000TEST0001\",\"filled_on\":\"2026-09-02\",\"days_supply\":30,\"quantity\":\"30\",\"amount_paid\":\"4.50\"}},{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0003\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"$duplicate\",\"status\":\"taking_regularly\",\"refills_left\":2}},{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0004\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"$lipitor\",\"status\":\"not_taking\",\"refills_left\":0}},{\"op\":\"put\",\"tbl\":\"prior_authorization\",\"id\":\"01J8MEDS0000000000TEST0005\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"$duplicate\",\"valid_from\":\"2026-01-01\",\"valid_to\":\"2026-12-31\"}}]}" \
  "$APP/api/events")"
expect_status "merge page offers the other entry" 200 "$(get "/setup/catalog/$duplicate/merge")"
expect_text "merge page names the entry that stays" "Lipitor (Atorvastatin) 20 mg"
expect_status "merge asks first" 200 "$(get "/setup/catalog/$duplicate/merge/$lipitor")"
expect_text "merge says how many fills move" "1 fill will move."
expect_text "merge says which list entry is kept" "The entry in use is kept."
expect_text "merge says it cannot be undone" "cannot be undone in the app"
expect_status "a medication is not merged into itself" 303 "$(get "/setup/catalog/$lipitor/merge/$lipitor")"
fills_before="$(count_of fill)"; entries_before="$(count_of person_medication)"
expect_status "merge without the token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST "$APP/setup/catalog/$duplicate/merge/$lipitor")"
expect_status "merge is done" 303 "$(post "/setup/catalog/$duplicate/merge/$lipitor" "/setup/catalog/$duplicate/merge/$lipitor")"
expect_status "no fill is lost in a merge" "$fills_before" "$(count_of fill)"
expect_status "the list entry not in use is dropped" "$((entries_before - 1))" "$(count_of person_medication)"
curl -s -m 10 "$APP/api/row/fill/01J8MEDS0000000000TEST0002" >"$BODY"
expect_text "the fill points to the entry that stays" "\"medication_id\":\"$lipitor\""
expect_text "the fill keeps its amount" '"amount_paid":"4.50"'
expect_text "the fill keeps its quantity" '"quantity":"30.000"'
curl -s -m 10 "$APP/api/row/person_medication/01J8MEDS0000000000TEST0003" >"$BODY"
expect_text "the list entry in use points to the entry that stays" "\"medication_id\":\"$lipitor\""
expect_text "the list entry keeps its refills" '"refills_left":"2"'
expect_status "the dropped list entry is gone" 404 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$APP/api/row/person_medication/01J8MEDS0000000000TEST0004")"
curl -s -m 10 "$APP/api/row/prior_authorization/01J8MEDS0000000000TEST0005" >"$BODY"
expect_text "the prior authorization points to the entry that stays" "\"medication_id\":\"$lipitor\""
expect_status "the merged entry is gone" 303 "$(get "/setup/catalog/$duplicate")"
expect_status "medication page after the merge" 200 "$(get "/setup/catalog/$lipitor?notice=merged")"
expect_text "the page confirms the merge" "Merged."
expect_status "search by the name of the merged entry" 200 "$(get '/setup/catalog?q=atorvastatin%20calcium%2020%20mg')"
expect_text "the old name finds the entry that stays" "Lipitor (Atorvastatin) 20 mg"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
expect_text "the view shows the medication under the name that stays" '"medication_name":"Lipitor (Atorvastatin) 20 mg"'
expect_text "the view counts the fill of the merged entry" '"last_filled_on":"2026-09-02"'

### Setup ###
expect_status "setup page" 200 "$(get /setup)"
expect_text "setup page counts the people" "3 in the app"
expect_text "setup page counts the medications" "40 in the app"
expect_text "setup page shows the household name" "The Example Household"

### Report ###
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
