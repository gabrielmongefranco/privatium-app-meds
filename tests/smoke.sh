#!/usr/bin/env bash
# This file is part of Medication Tracker
# tests/smoke.sh
# Author(s): Gabriel Mongefranco
# Created: 2026-09-27
# Last Modified: 2026-10-05
# Summary: Starts a Privatium node on a temporary data directory, opens the catalog so the app loads its starter catalog,
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

# Calendar dates keep status fixtures stable throughout the year.
day() { date -d "$1" +%F; }
passed=0
failed=0

pass() { passed=$((passed + 1)); }
# With MEDS_SMOKE_KEEP set to a folder, the page of each failed check is kept there.
fail() {
  failed=$((failed + 1)); echo "FAIL  $1"
  if [ -n "${MEDS_SMOKE_KEEP:-}" ] && [ -d "$MEDS_SMOKE_KEEP" ]; then
    cp "$BODY" "$MEDS_SMOKE_KEEP/$(printf '%s' "$1" | tr -c 'a-zA-Z0-9' '_').html" 2>/dev/null
  fi
}

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

# expect_flat_text <name> <text>, expect_no_flat_text <name> <text>: the same, for a
# text that the page breaks over several lines. Every run of spaces and line breaks of
# the page counts as one space.
flat_body() { tr -s ' \n\r\t' ' ' <"$BODY"; }
expect_flat_text() { if flat_body | grep -qF -- "$2"; then pass; else fail "$1: the page lacks: $2"; fi; }
expect_no_flat_text() { if flat_body | grep -qF -- "$2"; then fail "$1: the page holds: $2"; else pass; fi; }

# count_of <table>: prints how many rows a table holds, read through the data API.
count_of() {
  curl -s -m 10 "$APP/api/q/v_row_count" \
    | grep -o "\"row_count\":[0-9]*,\"table_name\":\"$1\"" | grep -o '[0-9]*' | head -1
}

# id_after <text>: prints the record id in the first link of $BODY that follows a path.
id_in_link() { grep -o "$1/[0-9A-Z]\{26\}" "$BODY" | head -1 | sed 's|.*/||'; }

### Home And Navigation ###
expect_status "home page" 200 "$(get /)"
expect_text "home page invites a household with no name" "Welcome to your medication tracker."
expect_text "home page has the navigation bar" 'aria-label="Medication Tracker"'
expect_text "home page marks the current section" 'aria-current="page"'
# The icon helper inlines the vendored shapes, so the checks look for the start of the
# path of capsule and of bag-plus-fill rather than for a name.
if grep -o 'Medications</a>' "$BODY" >/dev/null && grep -o '<li><a href="[^"]*/medications"[^<]*<svg[^>]*><path d="M1.828 8.9' "$BODY" >/dev/null; then pass; else fail "the Medications link carries the capsule icon"; fi
if grep -o '<li><a href="[^"]*/refills"[^<]*<svg[^>]*><path fill-rule="evenodd" d="M10.5 3.5a2.5' "$BODY" >/dev/null; then pass; else fail "the Refills link carries the bag icon"; fi
if [ "$(grep -n 'Medications</a>' "$BODY" | head -1 | cut -d: -f1)" -lt "$(grep -n 'Refills</a>' "$BODY" | head -1 | cut -d: -f1)" ]; then pass; else fail "Medications comes before Refills in the bar"; fi

### Starter Catalog ###
# The app loads its starter catalog the first time a page needs the catalog and finds
# it empty. The expected counts are read from the module, so a rebuilt catalog needs no
# change here.
SEED="$REPOSITORY/apps/meds/lib/starter_catalog.lua"
seed_medications="$(grep -c '^{t="medication",' "$SEED")"
seed_names="$(grep -c '^{t="medication_alias",' "$SEED")"
expect_status "the catalog starts empty" 0 "$(count_of medication)"
expect_status "the catalog page loads the starter catalog" 200 "$(get /setup/catalog)"
expect_status "catalog rows after the first visit" "$seed_medications" "$(count_of medication)"
expect_status "other names after the first visit" "$seed_names" "$(count_of medication_alias)"
expect_status "a second visit loads nothing more" 200 "$(get /setup/catalog)"
expect_status "catalog rows after the second visit" "$seed_medications" "$(count_of medication)"
expect_status "no person in the starter catalog" 0 "$(count_of person)"
curl -s -m 20 "$APP/api/q/v_medication?limit=10000" >"$BODY"
expect_text "a product that comes by the carton has an entry for each carton" '"short_name":"Otrexup (Methotrexate) 10 mg/0.4 mL Auto-Injector 1 Pack"'
expect_text "the larger carton is an entry of its own" '"short_name":"Otrexup (Methotrexate) 10 mg/0.4 mL Auto-Injector 4 Pack"'
expect_text "a device shows the strength of its label" '"short_name":"Auvi-Q (Epinephrine) 0.3 mg/0.3 mL Auto-Injector 2 Pack"'
expect_text "a brand filed under a salt is in the catalog" '"short_name":"Januvia (Sitagliptin) 100 mg"'
expect_text "starter catalog includes controlled products" '"is_controlled":true'
expect_text "a syringe with its needle is in the catalog" '"short_name":"Syringe with Needle, Insulin, 0.5 mL, 31G x 5/16\""'
expect_text "a needle for a pen is in the catalog" '"short_name":"Needle, Pen Tip, 32G x 4 mm"'
expect_text "an entry of a carton holds its size" '"package_size":"4"'
expect_text "an entry of a carton holds its type" '"package_type":"Pack"'

### Greeting ###
# The greeting follows the local hour, so the expected words come from the local clock.
hour="$(date +%H | sed 's/^0//')"
if [ "$hour" -lt 12 ]; then greeting="Good morning"
elif [ "$hour" -lt 18 ]; then greeting="Good afternoon"
else greeting="Good evening"; fi
expect_status "home page after the starter catalog" 200 "$(get /)"
expect_text "the home page still welcomes while nobody is added" "Welcome to your medication tracker."
expect_text "greeting follows the local hour" "$greeting."
expect_status "no page asks for a household name" 404 "$(get /edit)"

### Reminder Settings ###
expect_status "reminder settings page" 200 "$(get /setup/reminders)"
expect_text "the due box shows its default" 'name="due_within_days" type="text" value="3"'
expect_text "the backup percent box shows its default" 'name="backup_percent" type="text" value="15"'
expect_text "the specialty backup box shows its default" 'name="specialty_backup_min_days" type="text" value="10"'
expect_no_text "no box says what empty means" "Empty means"
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
expect_text "a cleared box saves its default" '"specialty_due_within_days":5'
expect_text "the backup percent is in force" '"backup_percent":15'
expect_status "the saved settings" 200 "$(get /setup/reminders)"
expect_text "a saved count shows in its box" 'name="due_within_days" type="text" value="4"'
curl -s -m 10 "$APP/api/events?tbl=profile" | tail -1 >"$BODY"
expect_text "a cleared box is saved as its default" '"backup_min_days":"7"'
expect_status "reminder settings are saved a second time" 303 "$(post /setup/reminders /setup/reminders \
  'due_within_days=4' 'due_soon_within_days=8' 'authorization_notice_days=30')"
expect_status "the settings stay one record" 1 "$(count_of profile)"

expect_status "a percent above 100 is refused" 200 "$(post /setup/reminders /setup/reminders 'early_fill_percent=101')"
expect_text "a percent above 100 says why" "whole number from 0 to 100"
expect_status "early refill settings" 200 "$(get /setup/reminders)"
expect_text "the percent box shows the number in use" 'name="early_fill_percent" type="text" value="25"'
expect_status "a backup percent above 100 is refused" 200 "$(post /setup/reminders /setup/reminders 'backup_percent=101')"
expect_text "a backup percent above 100 says why" "whole number from 0 to 100"

### Insurance Plans ###
expect_status "empty plan list" 200 "$(get /setup/plans)"
expect_text "empty plan list says so" "No plan is recorded."
expect_status "a plan without its name is refused" 200 "$(post /setup/plans/new /setup/plans/new 'early_fill_percent=25')"
expect_status "a plan above the percent limit is refused" 200 "$(post /setup/plans/new /setup/plans/new 'name=Invalid Example' 'early_fill_percent=101')"
expect_status "a plan above the frame limit is refused" 200 "$(post /setup/plans/new /setup/plans/new 'name=Invalid Example' 'supply_frame_days=3651')"
expect_status "invalid plans add nothing" 0 "$(count_of plan)"
expect_status "plan without CSRF is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST --data-urlencode 'name=Example' "$APP/setup/plans/new")"
expect_status "plan markup is stored as text" 303 "$(post /setup/plans/new /setup/plans/new 'name=<script>example</script>')"
get /setup/plans >/dev/null
expect_text "plan name is escaped" "&lt;script&gt;example&lt;/script&gt;"
expect_no_text "plan name cannot execute markup" "<script>example</script>"
unused_plan="$(id_in_link /setup/plans)"
expect_status "unused plan is removed" 303 "$(post "/setup/plans/$unused_plan/remove" "/setup/plans/$unused_plan/remove")"
expect_status "plan A is added" 303 "$(post /setup/plans/new /setup/plans/new 'name=Example Plan A')"
get /setup/plans >/dev/null
plan_a="$(id_in_link /setup/plans)"
expect_status "plan name duplication is refused" 200 "$(post /setup/plans/new /setup/plans/new 'name=example plan a')"
expect_status "plan B is added" 303 "$(post /setup/plans/new /setup/plans/new 'name=Example Plan B')"
get /setup/plans >/dev/null
plan_b="$(grep -o '/setup/plans/[0-9A-Z]\{26\}' "$BODY" | sed 's|.*/||' | grep -v "$plan_a" | head -1)"

### People ###
expect_status "people page" 200 "$(get /setup/people)"
expect_text "people page with no one" "No one is in the family yet."
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
expect_no_text "removal page does not mention the log" "Privatium keeps the original line in its log"
expect_status "a fill for the person is recorded" 200 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"events\":[{\"op\":\"put\",\"tbl\":\"pharmacy\",\"id\":\"01J8MEDS0000000000TEST0001\",\"d\":{\"name\":\"Example Pharmacy\",\"phone\":\"(555) 555-0100\"}},{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0010\",\"d\":{\"person_id\":\"$alex\",\"display_name\":\"Amoxicillin suspension\",\"status\":\"not_taking\",\"refills_left\":0}},{\"op\":\"put\",\"tbl\":\"person_medication_product\",\"id\":\"01J8MEDS0000000000TEST0011\",\"d\":{\"person_medication_id\":\"01J8MEDS0000000000TEST0010\",\"medication_id\":\"01J8MEDS0000000000MED00001\"}},{\"op\":\"put\",\"tbl\":\"fill\",\"d\":{\"person_medication_id\":\"01J8MEDS0000000000TEST0010\",\"medication_id\":\"01J8MEDS0000000000MED00001\",\"pharmacy_id\":\"01J8MEDS0000000000TEST0001\",\"filled_on\":\"2026-09-01\",\"days_supply\":30}}]}" \
  "$APP/api/events")"
expect_status "removal page for a person with a fill" 200 "$(get "/setup/people/$alex/remove")"
expect_text "a person with a fill cannot be removed" "cannot be removed yet"
expect_text "the page says what uses the person" "1 fill"
expect_text "the page counts the tracked medications of the person" "1 medication on their list"
# The removal page of a record in use has no form, so the token comes from another form.
# The token is valid for the whole app, which is what a hand-built request would use.
expect_status "removing a person with a fill is refused" 303 "$(post /setup/people/new "/setup/people/$alex/remove")"
expect_status "the person is still there" 4 "$(count_of person)"

get /setup/people >/dev/null
other="$(grep -o '/setup/people/[0-9A-Z]\{26\}/remove' "$BODY" | sed 's|/remove||; s|.*/||' | grep -v "$alex" | head -1)"
expect_status "a person with no records is removed" 303 "$(post "/setup/people/$other/remove" "/setup/people/$other/remove")"
expect_status "one person fewer" 3 "$(count_of person)"

### Prescribers and Pharmacies ###
expect_status "pharmacies page" 200 "$(get /setup/pharmacies)"
expect_text "pharmacies page lists the pharmacy" "Example Pharmacy"
expect_text "pharmacies page links back to Setup" "Back to Setup"
expect_text "a phone number is a link a phone can dial" 'href="tel:5555550100"'
expect_text "a pharmacy that fills use cannot be removed" "Remove"
expect_status "prescribers page" 200 "$(get /setup/prescribers)"
expect_text "prescribers page has its heading" "<h1>Prescribers</h1>"
expect_status "setup page" 200 "$(get /setup)"
expect_text "setup links to the prescribers" '/setup/prescribers'
expect_text "setup links to the pharmacies" '/setup/pharmacies'
expect_no_text "the navigation bar has no Contacts tab" "> Contacts</a>"
expect_status "a script address as a website is refused" 200 "$(post /setup/pharmacies/new /setup/pharmacies/new \
  'name=Sample Pharmacy' 'website=javascript:alert(3)')"
expect_text "a script address says why" "Start the website with https://"
expect_status "a short identifier is refused" 200 "$(post /setup/pharmacies/new /setup/pharmacies/new \
  'name=Sample Pharmacy' 'npi=12345')"
expect_text "a short identifier says why" "10 digits"
expect_status "an email address with no @ is refused" 200 "$(post /setup/pharmacies/new /setup/pharmacies/new \
  'name=Sample Pharmacy' 'email=sample.example.com')"
expect_status "pharmacy is added" 303 "$(post /setup/pharmacies/new /setup/pharmacies/new \
  'name=Sample Pharmacy' 'phone=+1 555 555 0142 x9' 'website=https://pharmacy.example.com' \
  'npi=1234567893' 'email=sample@example.com' 'address=1 Example Street, Anytown')"
expect_status "prescriber is added" 303 "$(post /setup/prescribers/new /setup/prescribers/new \
  'name=Dr. Sample' 'clinic=Example Clinic' 'mobile_phone=555-555-0177')"
expect_status "pharmacies page after adding" 200 "$(get /setup/pharmacies)"
expect_text "pharmacies page lists the new pharmacy" "Sample Pharmacy"
expect_text "an extension is left out of the link" 'href="tel:+15555550142"'
expect_text "a website with https is a link" 'href="https://pharmacy.example.com"'
expect_status "prescribers page after adding" 200 "$(get /setup/prescribers)"
expect_text "prescribers page lists the prescriber" "Dr. Sample"
expect_text "prescribers page shows the clinic" "Example Clinic"
expect_status "removal page for a pharmacy with a fill" 200 "$(get /setup/pharmacies/01J8MEDS0000000000TEST0001/remove)"
expect_text "a pharmacy with a fill cannot be removed" "cannot be removed yet"
expect_status "the same pharmacy name is refused" 200 "$(post /setup/pharmacies/new /setup/pharmacies/new \
  'name=sample pharmacy')"
expect_text "the same pharmacy name says why" "already in the app"

### Medication Catalog ###
expect_status "catalog page" 200 "$(get /setup/catalog)"
expect_text "catalog page counts the medications" "The catalog holds $seed_medications medications."
expect_text "a long catalog shows its first page" "This page shows the first 100"
expect_status "catalog filtered by another name" 200 "$(get '/setup/catalog?q=apap')"
expect_text "two medications answer to the other name" "2 medications"
expect_status "catalog filtered by a percent sign" 200 "$(get '/setup/catalog?q=%25')"
expect_text "a percent sign alone finds nothing" "No medications found."
expect_status "catalog filtered by an underscore" 200 "$(get '/setup/catalog?q=_')"
expect_text "an underscore alone finds nothing" "No medications found."
expect_status "catalog filtered by SQL" 200 "$(get "/setup/catalog?q=%27%20OR%201%3D1%20--")"
expect_no_text "SQL in the filter is compared as text and lists no catalog" "The catalog holds"
expect_status "catalog filtered by markup" 200 "$(get '/setup/catalog?q=%3Cimg%20src%3Dx%3E')"
expect_no_text "markup in the filter is never sent as markup" "<img src=x>"

expect_status "the catalog form" 200 "$(get /setup/catalog/new)"
expect_text "the catalog form has the controlled checkbox" 'name="is_controlled" type="checkbox"'
expect_text "the catalog form has the specialty checkbox" 'name="is_specialty" type="checkbox"'
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
expect_status "the catalog is back to the starter catalog" "$seed_medications" "$(count_of medication)"

expect_status "medication page of the starter catalog" 200 "$(get /setup/catalog/01J8MEDS0000000000MED00003)"
expect_text "a medication shows its other names" "Z-Pak"
expect_status "removal page for a medication with a fill" 200 "$(get /setup/catalog/01J8MEDS0000000000MED00001/remove)"
expect_text "a medication with a fill cannot be removed" "cannot be removed yet"
expect_status "a medication goes with its other names" 303 "$(post /setup/catalog/01J8MEDS0000000000MED00003/remove \
  /setup/catalog/01J8MEDS0000000000MED00003/remove)"
expect_status "one medication fewer" "$((seed_medications - 1))" "$(count_of medication)"
names_of_removed="$(grep -c 'medication_id="01J8MEDS0000000000MED00003"' "$SEED")"
expect_status "its other names are gone with it" "$((seed_names - names_of_removed))" "$(count_of medication_alias)"

### Medication Search, Other Names And Merge ###
expect_status "search by a misspelled name" 200 "$(get '/setup/catalog?q=Lipitro')"
expect_text "a close name is offered as a question" "Did you mean one of these?"
expect_text "the close medication is named" "Lipitor (Atorvastatin) 20 mg"
expect_text "a close name says to check it" "names that look alike"
expect_status "search by the start of a generic name" 200 "$(get '/setup/catalog?q=atorva')"
expect_text "the start of a name finds the medication" "Lipitor (Atorvastatin) 40 mg"
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
expect_text "a name the medication has says why" "already has that name"
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

# Two entries for one product, as two sources would name it. The second is tracked by
# the person, with a fill; the person also tracks the first, as one no longer taken.
expect_status "the same product under a second name is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'generic_name=Atorvastatin calcium' 'strength=20 mg' 'route=Oral' 'dose_form=Tablet')"
get '/setup/catalog?q=atorvastatin%20calcium%2020' >/dev/null
duplicate="$(grep -o '/setup/catalog/[0-9A-Z]\{26\}"' "$BODY" | sed 's|.*/||; s|"||' | grep -v "$lipitor" | head -1)"
expect_status "records for both entries are recorded" 200 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"events\":[{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0003\",\"d\":{\"person_id\":\"$alex\",\"display_name\":\"Atorvastatin 20 mg\",\"status\":\"taking_regularly\",\"refills_left\":2}},{\"op\":\"put\",\"tbl\":\"person_medication_product\",\"id\":\"01J8MEDS0000000000TEST0013\",\"d\":{\"person_medication_id\":\"01J8MEDS0000000000TEST0003\",\"medication_id\":\"$duplicate\"}},{\"op\":\"put\",\"tbl\":\"fill\",\"id\":\"01J8MEDS0000000000TEST0002\",\"d\":{\"person_medication_id\":\"01J8MEDS0000000000TEST0003\",\"medication_id\":\"$duplicate\",\"pharmacy_id\":\"01J8MEDS0000000000TEST0001\",\"filled_on\":\"$(day '-100 days')\",\"days_supply\":365,\"quantity\":\"30\",\"amount_paid\":\"4.50\"}},{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0004\",\"d\":{\"person_id\":\"$alex\",\"display_name\":\"Old statin\",\"status\":\"not_taking\",\"refills_left\":0}},{\"op\":\"put\",\"tbl\":\"person_medication_product\",\"id\":\"01J8MEDS0000000000TEST0014\",\"d\":{\"person_medication_id\":\"01J8MEDS0000000000TEST0004\",\"medication_id\":\"$lipitor\"}},{\"op\":\"put\",\"tbl\":\"prior_authorization\",\"id\":\"01J8MEDS0000000000TEST0005\",\"d\":{\"person_medication_id\":\"01J8MEDS0000000000TEST0003\",\"valid_from\":\"2026-01-01\",\"valid_to\":\"2026-12-31\"}}]}" \
  "$APP/api/events")"
expect_status "merge page offers the other entry" 200 "$(get "/setup/catalog/$duplicate/merge")"
expect_text "merge page names the entry that stays" "Lipitor (Atorvastatin) 20 mg"
expect_status "merge asks first" 200 "$(get "/setup/catalog/$duplicate/merge/$lipitor")"
expect_text "merge says how many fills move" "1 fill will name the medication that stays."
expect_text "merge says which medication changes" "1 medication on a list will point to the one that stays"
expect_text "merge warns of a person who ends up with the product twice" "1 person will have the product that stays on two medications"
expect_text "merge says it cannot be undone" "A merge cannot be undone."
expect_status "a medication is not merged into itself" 303 "$(get "/setup/catalog/$lipitor/merge/$lipitor")"
fills_before="$(count_of fill)"; entries_before="$(count_of person_medication)"; links_before="$(count_of person_medication_product)"
expect_status "merge without the token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST "$APP/setup/catalog/$duplicate/merge/$lipitor")"
expect_status "merge is done" 303 "$(post "/setup/catalog/$duplicate/merge/$lipitor" "/setup/catalog/$duplicate/merge/$lipitor")"
expect_status "no fill is lost in a merge" "$fills_before" "$(count_of fill)"
expect_status "no tracked medication is lost in a merge" "$entries_before" "$(count_of person_medication)"
expect_status "no product link is lost in a merge" "$links_before" "$(count_of person_medication_product)"
curl -s -m 10 "$APP/api/row/fill/01J8MEDS0000000000TEST0002" >"$BODY"
expect_text "the fill names the entry that stays" "\"medication_id\":\"$lipitor\""
expect_text "the fill keeps its amount" '"amount_paid":"4.50"'
expect_text "the fill keeps its quantity" '"quantity":"30.000"'
curl -s -m 10 "$APP/api/row/person_medication_product/01J8MEDS0000000000TEST0013" >"$BODY"
expect_text "the product link points to the entry that stays" "\"medication_id\":\"$lipitor\""
curl -s -m 10 "$APP/api/row/person_medication/01J8MEDS0000000000TEST0003" >"$BODY"
expect_text "the tracked medication keeps its refills" '"refills_left":"2"'
expect_text "the tracked medication keeps its name" '"display_name":"Atorvastatin 20 mg"'
expect_status "the merged entry is gone" 303 "$(get "/setup/catalog/$duplicate")"
expect_status "medication page after the merge" 200 "$(get "/setup/catalog/$lipitor?notice=merged")"
expect_text "the page confirms the merge" "Merged."
expect_status "search by the name of the merged entry" 200 "$(get '/setup/catalog?q=atorvastatin%20calcium%2020%20mg')"
expect_text "the old name finds the entry that stays" "Lipitor (Atorvastatin) 20 mg"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
expect_text "the view shows the tracked medication under its preferred name" '"medication_name":"Atorvastatin 20 mg"'
expect_text "the view counts the fill of the merged entry" "\"last_filled_on\":\"$(day '-100 days')\""
# The person now holds the product on two tracked medications, which the forms never
# allow. The one no longer taken goes, and its product link goes with it.
expect_status "the second tracked medication is removed" 303 "$(post /medications/01J8MEDS0000000000TEST0004/remove /medications/01J8MEDS0000000000TEST0004/remove)"
expect_status "its product link went with it" "$((links_before - 1))" "$(count_of person_medication_product)"
expect_status "a tracked medication with a fill cannot be removed" 200 "$(get /medications/01J8MEDS0000000000TEST0003/remove)"
expect_text "the removal page says what uses it" "1 fill"
expect_text "the removal page counts the prior authorization" "1 prior authorization"
expect_status "removing it by hand is refused" 303 "$(post /setup/people/new /medications/01J8MEDS0000000000TEST0003/remove)"
expect_status "the tracked medication is still there" 200 "$(get /medications/01J8MEDS0000000000TEST0003)"
expect_text "the entry page lists its product" "Lipitor (Atorvastatin) 20 mg"
expect_text "the entry page shows the icon of the form" '<title>Tablet</title>'

### Medication Lists ###
# Dates are worked out from today, so the refill statuses stay the same on any day.
entry_of() {   # entry_of <part of a preferred name>: prints the id of its tracked medication
  curl -s -m 10 "$APP/api/q/v_active_medication" \
    | grep -o "\"medication_name\":\"[^\"]*$1[^}]*\"person_medication_id\":\"[0-9A-Z]*\"" \
    | head -1 | sed 's/.*"person_medication_id":"//; s/"$//'
}
product_of() {   # product_of <short name>: prints the id of a catalog entry
  curl -s -m 20 "$APP/api/q/v_medication?limit=10000" | grep -o "{[^}]*\"short_name\":\"$1\"[^}]*}" \
    | grep -o '"medication_id":"[0-9A-Z]*"' | head -1 | sed 's/.*:"//; s/"//'
}
pharmacy=01J8MEDS0000000000TEST0001
prinivil=01J8MEDS0000000000MED00016
glucophage=01J8MEDS0000000000MED00017

expect_status "medications page" 200 "$(get "/medications?person=$alex")"
expect_text "medications page lists an entry" "Atorvastatin 20 mg"
expect_text "medications page has the button to track a medication" "Track a new medication"
expect_text "medications page has a search box" 'name="q" type="search"'
expect_text "medications page loads the filter script" '/static/filter.js'
expect_status "the home page is the Medications page once a person exists" 200 "$(get /)"
expect_text "the home page shows the Medications heading" "<h1>Medications</h1>"
expect_status "medications page again" 200 "$(get /medications)"
expect_text "medications page loads the person script" '/static/person_tab.js'
expect_text "the Everyone link names an empty person" 'medications?person="'
expect_status "the filter script is served" 200 "$(get /static/filter.js)"
expect_status "the person script is served" 200 "$(get /static/person_tab.js)"
expect_status "the form that tracks a medication" 200 "$(get "/medications/new?person=$alex")"
expect_text "the form has its heading" "Track new medication"
expect_text "the form suggests names while a person types" 'list="medication-names"'
expect_text "the suggestions hold the short names" 'value="Prinivil (Lisinopril) 10 mg"'
expect_text "the suggestions hold the other names" 'value="Albuterol inhaler"'
expect_text "the form can add a medication to the catalog" "Not in the list? Add a medication to the catalog"
expect_text "the package type is a drop-down" '<select id="f-product_package_type-list" name="product_package_type">'
expect_text "the form has a search box with a Find button" 'name="step" value="find_product"'
expect_text "the form has a notes box" '<textarea id="f-notes" name="notes"'
expect_text "the form loads the product search script" '/static/product_search.js'
expect_text "the form has the controlled checkbox" 'name="product_controlled" type="checkbox"'
expect_text "the form has the specialty checkbox" 'name="product_specialty" type="checkbox"'
expect_text "the form asks for a preferred name" 'name="display_name"'
expect_text "the form can add a new prescriber" "Name of the new prescriber"
expect_text "a drop-down offers to add a new record" '<option value="new">-- Add new --</option>'
expect_text "the fields of a new record wait for that choice" 'data-show-when="prescriber_id=new"'
expect_text "the page loads the script that shows them" '/static/forms.js'
expect_status "the script is served" 200 "$(get /static/forms.js)"
expect_status "the product search script is served" 200 "$(get /static/product_search.js)"
expect_status "the drug references script is served" 200 "$(get /static/drug_references.js)"
expect_status "a search that fits two medications lists both" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_q=albuterol' 'step=find_product' 'status=taking_regularly' 'refills_left=1')"
expect_text "the results say how many were found" 'results for "albuterol". Check the ones to add.'
expect_text "the results offer the first" "Ventolin HFA (Albuterol) 90 mcg/actuation"
expect_text "the results offer the second" "Albuterol 2.5 mg/3 mL (0.083%)"
expect_text "each result has a check box" 'type="checkbox" name="pick_'
expect_text "the form keeps the typed search" 'value="albuterol"'
expect_text "the form has the link to the online databases" 'data-search-online'
expect_status "the search answers JSON for the script" 200 "$(get "/medications/search?q=albuterol")"
expect_text "the JSON names the results" '"short_name":"Ventolin HFA (Albuterol) 90 mcg/actuation"'
expect_text "the JSON tells a close match from a plain one" '"close":false'
expect_status "an empty search answers an empty list" 200 "$(get "/medications/search?q=")"
expect_text "an empty search has no results" '"results":[]'
expect_status "a misspelled search finds the close medication" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_q=Prinivl' 'step=find_product' 'status=taking_regularly' 'refills_left=1')"
expect_text "a misspelled search offers the close medication" "Prinivil (Lisinopril) 10 mg"
expect_text "a close medication is marked as such" "Close match"
expect_status "a name nobody knows finds nothing" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_q=zzzqqq' 'step=find_product' 'status=taking_regularly' 'refills_left=1')"
expect_text "a name nobody knows says what to do" "No medication found with this name."
expect_text "a name nobody knows opens the fields of a new medication" '<details data-new-product open>'
expect_status "markup as a search is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_q=<script>alert(7)</script>' 'step=find_product' 'status=taking_regularly' 'refills_left=1')"
expect_no_text "markup as a search is never sent as markup" "<script>alert(7)</script>"
expect_status "the choice to add with nothing checked is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'step=add_product' 'status=taking_regularly' 'refills_left=1')"
expect_text "the choice to add with nothing checked says why" "Check a product in the results, or type a name to search for."
expect_status "a checked result is added to the form" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "pick_$prinivil=yes" 'step=add_product' 'status=taking_regularly' 'refills_left=1')"
expect_text "the product is carried by its id" "name=\"product_1_id\" value=\"$prinivil\""
expect_text "the product is listed with its full name" "Lisinopril (Prinivil) 10 mg Oral Tablet"
expect_text "the preferred name starts as the full name" 'name="display_name" type="text" value="Lisinopril (Prinivil) 10 mg Oral Tablet"'
expect_text "the product can be removed again" 'value="remove_product_1"'
expect_text "the box to add another product folds away" '<details class="meds-another">'
expect_text "the folded box explains itself" "(e.g. different pack size of the same medication)"
expect_status "two checked results are added together" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "pick_$prinivil=yes" "pick_$glucophage=yes" 'step=add_product' 'status=taking_regularly' 'refills_left=1')"
expect_text "the first checked product is carried" "name=\"product_1_id\" value=\"$prinivil\""
expect_text "the second checked product is carried" "name=\"product_2_id\" value=\"$glucophage\""
expect_status "a checked result that names nothing is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'pick_01J8MEDS0000000000N0NE0001=yes' 'step=add_product' 'status=taking_regularly' 'refills_left=1')"
expect_text "a checked result that names nothing says why" "Choose a medication from the list."
expect_status "a search typed into the box runs when the form is saved" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_q=Prinivil (Lisinopril) 10 mg' 'step=save' 'status=taking_regularly' 'refills_left=1')"
expect_text "the saved form came back with the results" "name=\"pick_$prinivil\""
expect_no_text "nothing was added by the search" 'name="product_1_id"'
expect_status "a product is removed from the form" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$prinivil" 'step=remove_product_1' 'status=taking_regularly' 'refills_left=1')"
expect_no_text "the removed product is gone from the form" "name=\"product_1_id\""
expect_no_text "a form with no product hides the Products box" 'id="f-products"'
expect_status "an entry with no product is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'display_name=Nothing' 'status=taking_regularly' 'refills_left=1')"
expect_text "an entry with no product says why" "Add at least one product."
expect_status "a product id that names nothing is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_1_id=01J8MEDS0000000000N0NE0001' 'display_name=Nothing' 'status=taking_regularly' 'refills_left=1')"
expect_text "a product id that names nothing says why" "Choose a medication from the list."
expect_status "an entry with no preferred name is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$prinivil" 'display_name= ' 'status=taking_regularly' 'refills_left=1')"
expect_text "an entry with no preferred name says why" "Enter the preferred name."
expect_status "an entry with no status is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$prinivil" 'display_name=Prinivil' 'status=' 'refills_left=1')"
expect_text "an entry with no status says why" "Choose a status."
expect_status "an entry with a status that does not exist is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$prinivil" 'display_name=Prinivil' 'status=cured' 'refills_left=1')"
expect_status "an entry for a person who does not exist is refused" 200 "$(post /setup/people/new /medications/new \
  'person_id=01J8MEDS0000000000N0NE0001' "product_1_id=$prinivil" 'display_name=Prinivil' 'status=taking_regularly' 'refills_left=1')"
expect_status "an entry with 100 refills is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$prinivil" 'display_name=Prinivil' 'status=taking_regularly' 'refills_left=100')"
expect_status "an entry is added" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$prinivil" 'display_name=Prinivil' 'status=taking_regularly' 'refills_left=1' \
  'instructions=Take one tablet by mouth every day' 'when_to_take_new=with breakfast' \
  'prescribed_for=<i>blood pressure</i>' 'notes=Take with food. Reorder early.' "pharmacy_id=$pharmacy")"
expect_status "the same product twice for one person is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$prinivil" 'display_name=Lisinopril' 'status=taking_regularly' 'refills_left=1')"
expect_text "the same product twice says which entry has it" "is already on the list for this person, under Prinivil"
expect_status "the same preferred name twice for one person is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$glucophage" 'display_name= PRINIVIL ' 'status=taking_regularly' 'refills_left=1')"
expect_text "the same preferred name twice says why" "already has a medication with this name"
entry="$(entry_of Prinivil)"
expect_status "page of a tracked medication" 200 "$(get "/medications/$entry")"
expect_text "the page shows the instructions" "Take one tablet by mouth every day"
expect_text "the page shows a typed choice" "with breakfast"
expect_text "the page shows the notes" "Take with food. Reorder early."
expect_text "markup in a field is shown escaped" "&lt;i&gt;blood pressure&lt;/i&gt;"
expect_text "a medication with no fill says so" "No fill recorded"
expect_text "the page lists the product" "Lisinopril (Prinivil) 10 mg Oral Tablet"
expect_no_text "the only product has no Remove button" "the product Prinivil"
expect_status "the change form holds the product" 200 "$(get "/medications/$entry/edit")"
expect_text "the change form carries the product" "name=\"product_1_id\" value=\"$prinivil\""
expect_text "the change form holds the preferred name" 'value="Prinivil"'
expect_text "the change form names the person" "Alex Example"
expect_status "saving with no product left is refused" 200 "$(post /setup/people/new "/medications/$entry/edit" \
  'display_name=Prinivil' 'status=taking_regularly' 'refills_left=1')"
expect_text "saving with no product left says why" "Add at least one product."
expect_status "a second product is added to the entry" 303 "$(post /setup/people/new "/medications/$entry/edit" \
  "product_1_id=$prinivil" "product_2_id=01J8MEDS0000000000MED00010" 'display_name=Prinivil' 'status=taking_regularly' 'refills_left=1' \
  'instructions=Take one tablet by mouth every day' "pharmacy_id=$pharmacy")"
expect_status "page with two products" 200 "$(get "/medications/$entry")"
expect_text "the second product is listed" "Adderall"
expect_text "a product among several has a Remove button" "the product Adderall"
expect_text "the marks of the products reach the entry" "<dt>Controlled</dt><dd>Yes.</dd>"
link_of() {   # link_of <tracked medication id> <product id>: prints the id of their link
  curl -s -m 10 "$APP/api/q/v_tracked_product" \
    | grep -o "{[^}]*\"person_medication_id\":\"$1\"[^}]*}" | grep "\"medication_id\":\"$2\"" \
    | grep -o '"link_id":"[0-9A-Z]*"' | head -1 | sed 's/.*:"//; s/"//'
}
link="$(link_of "$entry" "$prinivil")"
second_link="$(link_of "$entry" 01J8MEDS0000000000MED00010)"
expect_status "medications page with two products on one entry" 200 "$(get "/medications?person=$alex")"
expect_flat_text "the list names both products" "Adderall (Amphetamine"
expect_status "taking a product off asks first" 200 "$(get "/medications/$entry/products/$second_link/remove")"
expect_status "a product is taken off" 303 "$(post "/medications/$entry/products/$second_link/remove" "/medications/$entry/products/$second_link/remove")"
expect_status "taking off the last product is refused" 303 "$(post /setup/people/new "/medications/$entry/products/$link/remove")"
expect_status "taking off the last product says why" 200 "$(get "/medications/$entry/products/$link/remove")"
expect_text "the last product cannot go" "needs at least one product"
expect_status "a product of another entry is not taken off" 303 "$(get "/medications/01J8MEDS0000000000TEST0003/products/$link/remove")"
# One form adds the medication, the person, the prescriber and the pharmacy it names.
before="$(count_of medication) $(count_of person) $(count_of prescriber) $(count_of pharmacy) $(count_of person_medication) $(count_of person_medication_product)"
expect_status "a new medication is added to the form" 200 "$(post /setup/people/new /medications/new \
  'person_id_new=Robin Example' 'product_brand=Quickadd' 'product_generic=Quickaddine' \
  'product_strength=15 mg' 'step=add_product' 'status=taking_regularly' 'refills_left=2')"
expect_text "a new medication is carried by its fields" 'name="product_1_generic" value="Quickaddine"'
expect_text "a new medication is marked as new" "New</span>"
expect_text "the preferred name follows the new medication" 'value="Quickaddine (Quickadd) 15 mg"'
expect_status "nothing is written while the form is open" "$before" \
  "$(count_of medication) $(count_of person) $(count_of prescriber) $(count_of pharmacy) $(count_of person_medication) $(count_of person_medication_product)"
expect_status "an entry with everything new is added" 303 "$(post /setup/people/new /medications/new \
  'person_id_new=Robin Example' 'product_1_brand=Quickadd' 'product_1_generic=Quickaddine' \
  'product_1_strength=15 mg' 'display_name=Quickadd' 'status=taking_regularly' 'refills_left=2' \
  'prescriber_id_new=Dr. Quick' 'pharmacy_id_new=Quick Pharmacy')"
after="$(count_of medication) $(count_of person) $(count_of prescriber) $(count_of pharmacy) $(count_of person_medication) $(count_of person_medication_product)"
expect_status "everything new is added once" "$(echo "$before" | awk '{print $1+1, $2+1, $3+1, $4+1, $5+1, $6+1}')" "$after"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
expect_text "the new entry has its preferred name" '"medication_name":"Quickadd"'
expect_text "the new entry names the new prescriber" '"prescriber_name":"Dr. Quick"'
get /setup/people >/dev/null
robin="$(grep -o '/setup/people/[0-9A-Z]\{26\}/edit' "$BODY" | sed 's|/edit||; s|.*/||' | while read -r id; do if curl -s -m 10 "$APP/api/row/person/$id" | grep -q '"display_name":"Robin Example"'; then echo "$id"; fi; done | head -1)"
expect_status "a person may use a preferred name that another person has" 303 "$(post /setup/people/new /medications/new \
  "person_id=$robin" "product_1_id=$glucophage" 'display_name=Prinivil' 'status=on_hold' 'refills_left=0')"
# A typed name that a record already has picks that record.
expect_status "typed names that exist pick the records they name" 200 "$(post /setup/people/new /medications/new \
  'person_id_new=robin  EXAMPLE' 'product_1_generic=Quickaddine' 'product_1_brand=quickadd' \
  'product_1_strength=15 MG' 'display_name=Other' 'status=on_hold' 'refills_left=2' 'pharmacy_id_new=quick pharmacy')"
expect_text "the same person and product are found" "is already on the list for this person, under Quickadd"
expect_status "typed names that exist add nothing" "$(echo "$after" | awk '{print $1, $2, $3, $4, $5+1, $6+1}')" \
  "$(count_of medication) $(count_of person) $(count_of prescriber) $(count_of pharmacy) $(count_of person_medication) $(count_of person_medication_product)"
# The lookup in the browser fills in fields of the form. They are checked like any other.
expect_text "the form holds the line to the online databases, hidden until a script shows it" 'class="meds-online" hidden'
expect_text "the page loads the product search script" '/static/product_search.js'
expect_text "the page loads the drug references script" '/static/drug_references.js'
expect_status "a medication from a drug reference is added" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_1_brand=Lookupol' 'product_1_generic=Lookupine' \
  'product_1_strength=5 mg' 'product_1_rxcui=99999901' 'product_1_source=rxterms' \
  'product_1_route_ref=Oral Pill' 'product_1_dose_form_ref=Extended Release Oral Tablet' 'product_1_controlled=yes' \
  'display_name=Lookupol' 'status=on_hold' 'refills_left=0')"
get '/setup/catalog?q=lookupol' >/dev/null
lookupol="$(id_in_link /setup/catalog)"
expect_status "page of the medication from a drug reference" 200 "$(get "/setup/catalog/$lookupol")"
expect_text "the identifier of the reference is kept" "<dd>99999901</dd>"
expect_text "the reference is named" "RxTerms"
expect_text "the route takes the word of the catalog" "<dd>Oral</dd>"
expect_text "the form takes the word of the catalog" "<dd>Tablet</dd>"
expect_text "the controlled mark of the form is kept" "Controlled"
medications_before="$(count_of medication)"
expect_status "the same identifier picks the medication that has it" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_1_generic=Another Name' \
  'product_1_rxcui=99999901' 'product_1_source=rxterms' 'display_name=Another' 'status=on_hold' 'refills_left=0')"
expect_text "the medication that has the identifier is on the list already" "is already on the list for this person, under Lookupol"
# One product in two cartons is two entries with one identifier.
expect_status "a carton of a product that the catalog holds is added" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_1_brand=Lookupol' 'product_1_generic=Lookupine' \
  'product_1_strength=5 mg' 'product_1_package_size=6' 'product_1_package_type=Pack' \
  'product_1_rxcui=99999901' 'product_1_source=rxterms' 'display_name=Lookupol 6 pack' 'status=on_hold' 'refills_left=0')"
curl -s -m 20 "$APP/api/q/v_medication?limit=10000" >"$BODY"
expect_text "the package is part of the short name" '"short_name":"Lookupol (Lookupine) 5 mg 6 Pack"'
expect_status "the carton is a medication of its own" "$((medications_before + 1))" "$(count_of medication)"
expect_status "the same carton again picks the entry that has it" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_1_generic=Another Name' \
  'product_1_package_size=6' 'product_1_package_type=Pack' \
  'product_1_rxcui=99999901' 'product_1_source=rxterms' 'display_name=Another' 'status=on_hold' 'refills_left=0')"
expect_text "the carton is on the list already" "is already on the list for this person, under Lookupol 6 pack"
expect_status "the same carton again adds nothing" "$((medications_before + 1))" "$(count_of medication)"
medications_before="$(count_of medication)"
expect_status "an identifier with letters is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_1_generic=Badcode' 'product_1_rxcui=12<x>' \
  'display_name=Badcode' 'status=on_hold' 'refills_left=0')"
expect_text "an identifier with letters says why" "digits only"
expect_status "a reference that is not known is left out" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_1_generic=Nosourcine' 'product_1_source=<b>evil</b>' \
  'product_1_route_ref=<script>' 'product_1_dose_form_ref=<script>' 'display_name=Nosourcine' 'status=on_hold' 'refills_left=0')"
get '/setup/catalog?q=nosourcine' >/dev/null
expect_status "page of the medication with no reference" 200 "$(get "/setup/catalog/$(id_in_link /setup/catalog)")"
expect_no_text "a reference that is not known is never shown" "evil"
expect_no_text "a route that is not known is never stored" "&lt;script&gt;"
expect_status "only the one medication was added" "$((medications_before + 1))" "$(count_of medication)"
expect_status "a new medication with no name is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'product_strength=15 mg' 'step=add_product' 'status=taking_regularly' 'refills_left=1')"
expect_text "a new medication with no name says why" "Enter a brand name or a generic name."
expect_status "a new person with a name that is too long is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id_new=$(printf 'a%.0s' $(seq 1 121))" "product_1_id=$glucophage" 'display_name=Glucophage' 'status=taking_regularly' 'refills_left=1')"
expect_text "a name that is too long says why" "120 characters or fewer"
expect_status "an entry for a second medication, taken as needed" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "product_1_id=$glucophage" 'display_name=Glucophage' 'status=taking_as_needed' 'refills_left=0')"

# The search of the Medications page looks through every name, the prescriber and the person.
expect_status "search by part of a preferred name" 200 "$(get "/medications?person=$alex&q=prini")"
expect_text "the search finds the entry" "1 medication matches"
expect_text "the search keeps what was typed" 'value="prini"'
expect_text "every row carries its search text" 'data-search="'
expect_status "search by an other name of a product" 200 "$(get "/medications?person=$alex&q=ATORVA-20")"
expect_text "the search finds the entry by the other name of its product" ">Atorvastatin 20 mg</a>"
expect_status "search by a prescriber" 200 "$(get '/medications?q=quick')"
expect_text "the search finds the entry by its prescriber" "Dr. Quick"
expect_status "search by a person" 200 "$(get '/medications?q=robin')"
expect_text "the search names the person" "Robin Example"
expect_status "search with no match" 200 "$(get '/medications?q=zzzqqq')"
expect_text "a search with no match says so" "0 medications match"
expect_status "search by SQL" 200 "$(get "/medications?q=%27%20OR%201%3D1%20--")"
expect_text "SQL in the search is compared as text" "match"
expect_status "search by markup" 200 "$(get '/medications?q=%3Cimg%20src%3Dx%3E')"
expect_no_text "markup in the search is never sent as markup" "<img src=x>"

### Fills ###
expect_status "the fill form opens from a tracked medication" 200 "$(get "/fills/new?entry=$entry")"
expect_text "the fill form names the medication" "<dd>Prinivil</dd>"
expect_text "the fill form starts with today" "value=\"$(day today)\""
expect_text "the fill form offers one refill fewer" 'name="refills_left" type="text" value="0"'
expect_text "the fill form sets the one product without asking" "name=\"product_id\" value=\"$prinivil\""
expect_status "a fill in the future is refused" 200 "$(post /setup/people/new "/fills/new?entry=$entry" \
  "pharmacy_id=$pharmacy" "filled_on=$(day tomorrow)" 'refills_left=0')"
expect_text "a fill in the future says why" "not in the future"
expect_status "an amount with three decimal places is refused" 200 "$(post /setup/people/new "/fills/new?entry=$entry" \
  "pharmacy_id=$pharmacy" "filled_on=$(day today)" 'amount_paid=12.505' 'refills_left=0')"
expect_text "an amount with three decimal places says why" "up to 2 decimal places"
expect_status "a days supply of 1000 is refused" 200 "$(post /setup/people/new "/fills/new?entry=$entry" \
  "pharmacy_id=$pharmacy" "filled_on=$(day today)" 'days_supply=1000' 'refills_left=0')"
expect_status "a product of another medication is refused" 200 "$(post /setup/people/new "/fills/new?entry=$entry" \
  "pharmacy_id=$pharmacy" "filled_on=$(day today)" "product_id=$glucophage" 'refills_left=0')"
expect_text "a product of another medication says why" "Choose a product of this medication from the list."
expect_status "the fill form with no medication chosen" 200 "$(get "/fills/new?person=$alex")"
expect_text "the fill form has the search box" 'name="medication_q" type="search"'
expect_text "the fill form has the Find button" 'name="step" value="find_medication"'
expect_status "a search in the fill form comes back with results" 200 "$(post /setup/people/new /fills/new \
  'entry_id=new' "person_id=$alex" 'medication_q=albuterol' 'step=find_medication' "pharmacy_id=$pharmacy" "filled_on=$(day today)")"
expect_text "the fill form lists the results as radio buttons" 'type="radio" name="medication_choice"'
expect_text "the fill form offers the first result" "Ventolin HFA (Albuterol) 90 mcg/actuation"
expect_status "a typed search never saves a fill" 200 "$(post /setup/people/new /fills/new \
  'entry_id=new' "person_id=$alex" 'medication_q=albuterol' "pharmacy_id=$pharmacy" "filled_on=$(day today)")"
expect_text "the fill form came back with the results" 'name="medication_choice"'
expect_text "the fill form lists the tracked medications" 'name="entry_id"'
expect_text "the fill form labels them by person" "Alex Example: Prinivil"
expect_text "the fill form holds the medication box" 'name="medication_q"'
expect_text "the fill form can add a pharmacy" "Name of the new pharmacy"
expect_status "a fill with no medication is refused" 200 "$(post /setup/people/new /fills/new \
  "pharmacy_id=$pharmacy" "filled_on=$(day today)" 'refills_left=0')"
expect_text "a fill with no medication says why" "Choose a person, or type the name of a new one."
expect_status "a fill for a medication that names nothing is refused" 200 "$(post /setup/people/new /fills/new \
  'entry_id=01J8MEDS0000000000N0NE0001' "pharmacy_id=$pharmacy" "filled_on=$(day today)" 'refills_left=0')"
expect_text "a fill for a medication that names nothing says why" "Choose a medication from the list."
expect_status "a fill with no pharmacy is refused" 200 "$(post /setup/people/new /fills/new \
  "entry_id=$entry" "filled_on=$(day today)" 'refills_left=0')"
expect_text "a fill with no pharmacy says why" "Choose a pharmacy, or type the name of a new one."
fills_before="$(count_of fill)"
expect_status "a fill is recorded" 303 "$(post /setup/people/new /fills/new \
  "entry_id=$entry" "pharmacy_id=$pharmacy" "filled_on=$(day '-21 days')" \
  'days_supply=30' 'quantity=30' 'amount_paid=$1,012.50' 'refills_left=0' 'rx_number=700001' 'notes=Paid in cash')"
expect_status "one fill more" "$((fills_before + 1))" "$(count_of fill)"
curl -s -m 10 "$APP/api/row/person_medication/$entry" >"$BODY"
expect_text "the fill sets the refills left" '"refills_left":"0"'
expect_text "the fill keeps the rest of the tracked medication" 'Take one tablet by mouth every day'
expect_status "a fill for a medication taken as needed, long ago" 303 "$(post /setup/people/new /fills/new \
  "entry_id=$(entry_of Glucophage)" "pharmacy_id=$pharmacy" "filled_on=$(day '-200 days')" \
  'days_supply=30' 'refills_left=0')"
entries_before="$(count_of person_medication)"
expect_status "a fill for a product that is on no list" 303 "$(post /setup/people/new /fills/new \
  'entry_id=new' "person_id=$alex" "medication_id=01J8MEDS0000000000MED00018" "pharmacy_id=$pharmacy" \
  "filled_on=$(day '-18 days')" 'days_supply=30' 'refills_left=3')"
expect_status "the fill adds the tracked medication" "$((entries_before + 1))" "$(count_of person_medication)"
norvasc="$(entry_of Norvasc)"
curl -s -m 10 "$APP/api/row/person_medication/$norvasc" >"$BODY"
expect_text "the fill adds the medication to the list" '"status":"taking_regularly"'
expect_text "the added medication is named after its product" '"display_name":"Amlodipine (Norvasc)'
curl -s -m 10 "$APP/api/q/v_last_fill" >"$BODY"
expect_text "the fill names its product" "\"medication_id\":\"01J8MEDS0000000000MED00018\""
pharmacies_before="$(count_of pharmacy)"; fills_before="$(count_of fill)"; entries_before="$(count_of person_medication)"
expect_status "a fill by a typed name, at a new pharmacy" 303 "$(post /setup/people/new /fills/new \
  'entry_id=new' "person_id=$alex" "medication_choice=$(product_of 'Quickadd (Quickaddine) 15 mg')" 'pharmacy_id_new=Corner Pharmacy' \
  "filled_on=$(day '-10 days')" 'days_supply=30' 'plan_id=new' 'plan_id_new=Example Plan')"
expect_status "the fill is added" "$((fills_before + 1))" "$(count_of fill)"
expect_status "the pharmacy is added with it" "$((pharmacies_before + 1))" "$(count_of pharmacy)"
expect_status "a product that another person tracks gets its own entry" "$((entries_before + 1))" "$(count_of person_medication)"
expect_status "a fill for a product the person tracks already finds its entry" 303 "$(post /setup/people/new /fills/new \
  'entry_id=new' "person_id=$alex" "medication_id=$prinivil" "pharmacy_id=$pharmacy" \
  "filled_on=$(day '-60 days')" 'days_supply=30' 'refills_left=0')"
expect_status "no second entry is added for it" "$((entries_before + 1))" "$(count_of person_medication)"
expect_status "a refused fill adds no pharmacy" 200 "$(post /setup/people/new /fills/new \
  'entry_id=new' "person_id=$alex" "medication_choice=$(product_of 'Quickadd (Quickaddine) 15 mg')" 'pharmacy_id_new=Never Pharmacy' \
  "filled_on=$(day tomorrow)")"
expect_status "no pharmacy from a refused fill" "$((pharmacies_before + 1))" "$(count_of pharmacy)"
expect_text "a refused fill keeps the typed pharmacy" 'value="Never Pharmacy"'
get "/fills/new?person=$alex" >/dev/null
expect_text "a plan that a fill names is suggested" '>Example Plan</option>'

# A tracked medication with two products asks which one was dispensed.
two="$(entry_of Lookupol)"
six_product="$(product_of 'Lookupol (Lookupine) 5 mg 6 Pack')"
expect_status "a product on another entry of the person is refused" 200 "$(post /setup/people/new "/medications/$two/edit" \
  "product_1_id=$lookupol" "product_2_id=$six_product" 'display_name=Lookupol' 'status=on_hold' 'refills_left=0')"
expect_text "a product on another entry says which entry has it" "is already on the list for this person, under Lookupol 6 pack"
six="$(entry_of 'Lookupol 6 pack')"
expect_status "the other entry is removed first" 303 "$(post "/medications/$six/remove" "/medications/$six/remove")"
expect_status "the second carton joins the tracked medication" 303 "$(post /setup/people/new "/medications/$two/edit" \
  "product_1_id=$lookupol" "product_2_id=$six_product" 'display_name=Lookupol' 'status=on_hold' 'refills_left=0')"
expect_status "the fill form of a two-product medication" 200 "$(get "/fills/new?entry=$two")"
expect_text "the fill form asks which product" 'name="product_id"'
expect_text "the fill form offers the second carton" ">Lookupol (Lookupine) 5 mg 6 Pack</option>"
expect_status "a fill of the second carton" 303 "$(post /setup/people/new "/fills/new?entry=$two" \
  "product_id=$six_product" "pharmacy_id=$pharmacy" "filled_on=$(day '-5 days')" 'days_supply=30' 'refills_left=0')"
expect_status "the fill form starts with the product of the last fill" 200 "$(get "/fills/new?entry=$two")"
expect_flat_text "the last product is selected" "value=\"$six_product\" selected"
expect_status "page of the two-product medication" 200 "$(get "/medications/$two")"
expect_text "the fill history shows the product" '<th scope="col" role="columnheader">Product</th>'
expect_text "one fill is counted as one fill" "1 fill. Total paid"
expect_status "a product with a fill cannot be taken off" 200 "$(post /setup/people/new "/medications/$two/edit" \
  "product_1_id=$lookupol" 'display_name=Lookupol' 'status=on_hold' 'refills_left=0')"
expect_text "a product with a fill says why" "1 fill names Lookupine (Lookupol) 5 mg 6 Pack. Change those fills before you remove it."

### Refills ###
expect_status "refills page" 200 "$(get "/refills?person=$alex")"
expect_text "refills page has its heading" "<h1>Refills</h1>"
expect_no_text "refills page has no morning greeting" "Good morning"
expect_no_text "refills page has no afternoon greeting" "Good afternoon"
expect_no_text "refills page has no evening greeting" "Good evening"
expect_text "refills page names the portal button" "Copy refill history from patient portal"
expect_text "a refill 2 days away is due" "Due in 2 days"
expect_text "a refill 5 days away is due soon" "Due in 5 days"
expect_text "the summary counts the group Due" "Due: 1"
expect_text "the summary counts the group Due soon" "Due soon: "
expect_text "no refills left asks for a new prescription" "for a new prescription"
expect_text "a medication taken as needed has its own group" '<h2 id="as_needed">As needed</h2>'
expect_no_text "a medication taken as needed is never overdue" "Overdue by 1"
expect_text "no refills left and a fill that is near asks for a new prescription" '<h2 id="asking">New prescriptions to ask for</h2>'
expect_text "the summary counts the new prescriptions" "New prescriptions to ask for: 2"
expect_text "a medication taken as needed is asked for too" "Supply lasts until"
expect_text "the rows carry the icon of the form" '<title>Tablet</title>'
expect_status "a fill shows its confirmation" 200 "$(get '/refills?filled=01J8MEDS0000000000TEST0002')"
expect_text "the confirmation names the medication" "Saved the fill for Atorvastatin 20 mg."
expect_status "a fill id that is not in the app shows nothing" 200 "$(get '/refills?filled=%3Cscript%3E')"
expect_no_text "a fill id is never shown" "<script>"

expect_status "a specialty medication is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'brand_name=Specimab' 'generic_name=Specizumab' 'strength=150 mg' 'is_specialty=yes')"
get '/setup/catalog?q=specimab' >/dev/null
specimab="$(id_in_link /setup/catalog)"
expect_status "a fill for the specialty medication" 303 "$(post /setup/people/new /fills/new \
  'entry_id=new' "person_id=$alex" "medication_id=$specimab" "pharmacy_id=$pharmacy" "filled_on=$(day '-16 days')" \
  'days_supply=28' 'refills_left=5')"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
if grep -o '"medication_name":"[^"]*Specimab[^}]*' "$BODY" | grep -q '"refill_status":"due"'; then pass; else fail "a specialty refill 5 days away is due"; fi
if grep -o '"medication_name":"[^"]*Norvasc[^}]*' "$BODY" | grep -q '"refill_status":"due_soon"'; then pass; else fail "an ordinary refill 5 days away is due soon"; fi
if grep -o '{[^}]*"medication_name":"Prinivil[^}]*}' "$BODY" | grep -q '"days_until_next_fill":2'; then pass; else fail "the view counts the days to the next fill"; fi

### Supply And Payer Rules ###
expect_status "controlled medication is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'brand_name=Controlex' 'generic_name=Controline' 'strength=10 mg' 'is_controlled=yes')"
get '/setup/catalog?q=controlex' >/dev/null
controlex="$(id_in_link /setup/catalog)"
expect_text "catalog shows the controlled mark" "Controlled"
expect_status "frame medication is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'brand_name=Framelex' 'generic_name=Frameine' 'strength=10 mg')"
get '/setup/catalog?q=framelex' >/dev/null
framelex="$(id_in_link /setup/catalog)"
record_fill() {   # record_fill <product id> <days ago> <days supply> <plan id>
  expect_status "supply fixture is recorded" 303 "$(post /fills/new /fills/new \
    'entry_id=new' "person_id=$alex" "medication_id=$1" "pharmacy_id=$pharmacy" "filled_on=$(day "-$2 days")" \
    "days_supply=$3" "plan_id=$4" 'refills_left=3')"
}
row_of() { grep -o "{[^}]*\"medication_name\":\"[^\"]*$1[^}]*}" "$BODY"; }
record_fill "$controlex" 28 30 "$plan_a"
record_fill 01J8MEDS0000000000MED00019 40 30 "$plan_a"
record_fill 01J8MEDS0000000000MED00019 17 30 "$plan_a"
record_fill 01J8MEDS0000000000MED00011 73 30 "$plan_a"
record_fill 01J8MEDS0000000000MED00011 33 30 "$plan_a"
record_fill 01J8MEDS0000000000MED00011 10 30 "$plan_a"
record_fill 01J8MEDS0000000000MED00012 37 30 "$plan_a"
record_fill 01J8MEDS0000000000MED00012 14 30 "$plan_b"
record_fill 01J8MEDS0000000000MED00014 26 30 "$plan_a"
record_fill 01J8MEDS0000000000MED00031 33 30 "$plan_a"
record_fill "$framelex" 200 90 "$plan_a"
record_fill "$framelex" 132 90 "$plan_a"
record_fill "$framelex" 42 90 "$plan_a"
# The largest backup supply never waits, so the next fill date is the payer's date.
expect_status "the largest backup supply is saved" 303 "$(post /setup/reminders /setup/reminders \
  'due_within_days=4' 'due_soon_within_days=8' 'backup_min_days=365' 'specialty_backup_min_days=365')"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
for check in 'Controlex|2' 'Eliquis|13' 'Lexapro|20' 'Singulair|9' 'Synthroid|-3' 'Zyrtec|-10' 'Framelex|26'; do
  name="${check%|*}"; expected="${check#*|}"
  if row_of "$name" | grep -q "\"days_until_next_fill\":$expected[,}]"; then pass; else fail "eligibility for $name"; fi
done
for check in 'Controlex|2' 'Eliquis|20' 'Lexapro|27' 'Singulair|23' 'Synthroid|4' 'Zyrtec|-3' 'Framelex|70'; do
  name="${check%|*}"; expected="${check#*|}"
  if row_of "$name" | grep -q "\"days_until_runs_out\":$expected[,}]"; then pass; else fail "physical supply for $name"; fi
done
if row_of Controlex | grep -q '"is_controlled":1'; then pass; else fail "the controlled mark reaches the tracked medication"; fi
expect_status "all-history frame is saved" 303 "$(post "/setup/plans/$plan_a/edit" "/setup/plans/$plan_a/edit" \
  'name=Example Plan A' 'supply_frame_days=3650')"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
if row_of Framelex | grep -q '"days_until_next_fill":48'; then pass; else fail "all-history frame counts every fill"; fi
expect_status "the default backup supply is back" 303 "$(post /setup/reminders /setup/reminders \
  'due_within_days=4' 'due_soon_within_days=8')"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
# Supply runs out in 70 days; 15 percent of 90 keeps 13 days, later than the payer's 48.
if row_of Framelex | grep -q '"days_until_next_fill":57'; then pass; else fail "the backup supply sets the next fill date"; fi
# Runs out in 23 days; the 7-day minimum is later than the payer's 9.
if row_of Singulair | grep -q '"days_until_next_fill":16'; then pass; else fail "the smallest backup supply sets the next fill date"; fi
# Controlled: the payer's 2 days wins over any backup.
if row_of Controlex | grep -q '"days_until_next_fill":2'; then pass; else fail "a controlled medication keeps the payer's date"; fi
expect_status "plan frame is cleared" 303 "$(post "/setup/plans/$plan_a/edit" "/setup/plans/$plan_a/edit" 'name=Example Plan A')"
expect_status "controlled early days are saved" 303 "$(post /setup/reminders /setup/reminders \
  'due_within_days=4' 'due_soon_within_days=8' 'controlled_early_days=2')"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
if row_of Controlex | grep -q '"days_until_next_fill":0'; then pass; else fail "controlled allowance"; fi
expect_status "controlled allowance is cleared" 303 "$(post /setup/reminders /setup/reminders \
  'due_within_days=4' 'due_soon_within_days=8')"
expect_status "refills with stacked supply" 200 "$(get "/refills?person=$alex")"
expect_text "one exhausted supply" "Overdue: 1"
expect_text "four fills due" "Due: 4"
expect_text "one fill due soon" "Due soon: 1"
expect_text "eligibility with supply left" "Fill now. Runs out in 4 days"
expect_text "overdue uses supply" "Overdue by 3 days"
expect_text "physical supply date is labeled" "Lasts until"
expect_no_text "obsolete recommended date is gone" "Recommended"
expect_status "plan in use cannot be removed" 303 "$(post /setup/plans/new "/setup/plans/$plan_a/remove")"
expect_status "plan in use still exists" 200 "$(get "/setup/plans/$plan_a/edit")"
expect_status "person default plan is saved" 303 "$(post "/setup/people/$alex/edit" "/setup/people/$alex/edit" \
  'display_name=Alex Example' 'birth_date=1980-01-31' "plan_id=$plan_b")"
expect_status "new fill starts with the person's plan" 200 "$(get "/fills/new?entry=$entry")"
expect_flat_text "person plan overrides last fill plan" "value=\"$plan_b\" selected"
expect_status "a forged payer is refused" 200 "$(post /fills/new "/fills/new?entry=$entry" \
  "pharmacy_id=$pharmacy" "filled_on=$(day today)" 'plan_id=<script>')"
expect_text "forged payer says why" "Choose a plan from the list."

expect_status "a status is changed from the page" 303 "$(post /setup/people/new "/medications/$norvasc/status" 'status=on_hold')"
expect_status "a status that does not exist is ignored" 303 "$(post /setup/people/new "/medications/$norvasc/status" 'status=cured')"
curl -s -m 10 "$APP/api/row/person_medication/$norvasc" >"$BODY"
expect_text "the status is saved" '"status":"on_hold"'
expect_text "a change of status keeps the refills left" '"refills_left":"3"'
expect_status "refills page after the change" 200 "$(get "/refills?person=$alex")"
expect_text "a medication on hold is in the group Paused" '<h2 id="paused">Paused</h2>'

# A medication no longer taken can be restarted from the list.
expect_status "a medication is stopped" 303 "$(post /setup/people/new "/medications/$norvasc/status" 'status=not_taking')"
expect_status "medications page with a stopped medication" 200 "$(get "/medications?person=$alex")"
expect_text "the stopped medication is in its closed section" "No longer taking (2)"
expect_no_text "the stopped section starts closed" "<details data-filter-group open>"
expect_text "the stopped medication has a Restart button" "Restart<span class=\"pv-visually-hidden\"> taking Amlodipine (Norvasc)"
expect_status "a search that matches a stopped medication" 200 "$(get "/medications?person=$alex&q=norvasc")"
expect_text "the stopped section opens for a match" "<details data-filter-group open>"
expect_status "the medication is restarted" 303 "$(post /setup/people/new "/medications/$norvasc/status" 'status=taking_regularly' 'back=list')"
curl -s -m 10 "$APP/api/row/person_medication/$norvasc" >"$BODY"
expect_text "the restarted medication is taken regularly" '"status":"taking_regularly"'
expect_status "medications page after the restart" 200 "$(get "/medications?person=$alex&notice=saved")"
expect_text "one medication stays stopped" "No longer taking (1)"

# A fill brings a stopped medication back, but only while its supply lasts.
expect_status "the medication is stopped again" 303 "$(post /setup/people/new "/medications/$norvasc/status" 'status=not_taking')"
expect_status "an old fill of a stopped medication is saved" 303 "$(post /fills/new /fills/new \
  "entry_id=$norvasc" "pharmacy_id=$pharmacy" "filled_on=$(day '-200 days')" 'days_supply=30' "plan_id=$plan_a")"
curl -s -m 10 "$APP/api/row/person_medication/$norvasc" >"$BODY"
expect_text "an old fill leaves the medication stopped" '"status":"not_taking"'
expect_status "a fill that still lasts is saved" 303 "$(post /fills/new /fills/new \
  "entry_id=$norvasc" "pharmacy_id=$pharmacy" "filled_on=$(day '-5 days')" 'days_supply=30' "plan_id=$plan_a")"
curl -s -m 10 "$APP/api/row/person_medication/$norvasc" >"$BODY"
expect_text "a fill that still lasts brings the medication back" '"status":"taking_regularly"'
expect_status "the new fill form" 200 "$(get /fills/new)"
expect_text "the fill form explains the status rule" "moves to"

### Prior Authorizations ###
expect_status "authorizations page" 200 "$(get /authorizations)"
expect_status "the authorization form" 200 "$(get "/authorizations/new?entry=$entry")"
expect_text "the form lists the tracked medications" 'id="f-entry_id-list"'
expect_text "the form starts with the tracked medication" "value=\"$entry\" selected"
expect_text "the first day starts with the first of this month" "name=\"valid_from\" type=\"date\" value=\"$(date +%Y-%m-01)\""
expect_text "the expiration date starts one year later" "name=\"valid_to\" type=\"date\" value=\"$(($(date +%Y) + 1))-$(date +%m)-01\""
if [ "$(grep -n 'name="valid_from"' "$BODY" | head -1 | cut -d: -f1)" -lt "$(grep -n 'name="valid_to"' "$BODY" | head -1 | cut -d: -f1)" ]; then pass; else fail "the first day comes before the expiration date"; fi
expect_text "the form can find a product for a person" 'id="f-person_id-list"'
expect_text "the form holds the medication box" 'id="f-medication-q"'
expect_status "an authorization that ends before it starts is refused" 200 "$(post /setup/people/new /authorizations/new \
  "entry_id=$entry" "valid_from=$(day today)" "valid_to=$(day yesterday)")"
expect_text "an authorization that ends before it starts says why" "the expiration date or earlier"
expect_status "an authorization for no medication is refused" 200 "$(post /setup/people/new /authorizations/new \
  'entry_id=new' "person_id=$alex" "valid_from=$(day today)" "valid_to=$(day tomorrow)")"
expect_text "an authorization for no medication says why" "Choose a medication: type its name, or add a new one."
expect_status "an authorization for nobody is refused" 200 "$(post /setup/people/new /authorizations/new \
  'entry_id=new' "medication_id=$prinivil" "valid_to=$(day tomorrow)")"
expect_text "an authorization for nobody says why" "Choose a person, or type the name of a new one."
expect_status "an authorization for a medication that names nothing is refused" 200 "$(post /setup/people/new /authorizations/new \
  'entry_id=01J8MEDS0000000000N0NE0001' "valid_to=$(day tomorrow)")"
expect_text "an authorization for a medication that names nothing says why" "Choose a medication from the list."
expect_status "an authorization with no last day is refused" 200 "$(post /setup/people/new /authorizations/new \
  "entry_id=$entry" "valid_from=$(day today)")"
expect_text "an authorization with no last day says why" "Enter the expiration date."
expect_status "an authorization is added with no first day" 303 "$(post /setup/people/new /authorizations/new \
  "entry_id=$entry" "valid_to=$(day '+10 days')")"
expect_status "authorizations page with no first day" 200 "$(get /authorizations)"
expect_text "a first day that is not known says so" "Not known"
expect_text "the authorization names the tracked medication" "Prinivil"
entries_before="$(count_of person_medication)"
expect_status "an authorization for a product that is on no list" 303 "$(post /setup/people/new /authorizations/new \
  'entry_id=new' 'person_id_new=Jamie Example' "medication_choice=$(product_of 'Ventolin HFA (Albuterol) 90 mcg/actuation')" \
  "valid_from=$(day '-300 days')" "valid_to=$(day '+200 days')")"
expect_status "the medication is added to the list" "$((entries_before + 1))" "$(count_of person_medication)"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
if grep -o '"medication_name":"[^"]*Ventolin[^}]*' "$BODY" | grep -q '"status":"not_started"'; then pass; else fail "the medication starts as not started"; fi
expect_status "authorizations page after adding" 200 "$(get /authorizations)"
expect_text "an authorization that expires in 10 days is due" "Due: expires in 10 days"
expect_status "refills page with an authorization ending" 200 "$(get /refills)"
expect_text "the refills page warns of the authorization" "Expires in 10 days"
expect_text "only one authorization is due" "Authorizations due: 1"
expect_no_text "no authorization is due soon yet" "Authorizations due soon"
expect_status "an authorization that expires in 20 days" 303 "$(post /setup/people/new /authorizations/new \
  "entry_id=$(entry_of Glucophage)" "valid_to=$(day '+20 days')")"
expect_status "an authorization that expired" 303 "$(post /setup/people/new /authorizations/new \
  "entry_id=$norvasc" "valid_from=$(day '-400 days')" "valid_to=$(day '-3 days')")"
expect_status "an authorization that expires in 40 days" 303 "$(post /setup/people/new /authorizations/new \
  'entry_id=new' "person_id=$alex" "medication_id=$specimab" "valid_to=$(day '+40 days')")"
expect_status "an authorization for a product the person tracks finds its entry" "$((entries_before + 1))" "$(count_of person_medication)"
expect_status "refills page with authorizations of every level" 200 "$(get "/refills?person=$alex")"
expect_text "20 days away is due soon" "Authorizations due soon: 1"
expect_text "an expired authorization is counted" "Authorizations expired: 1"
expect_text "an expired authorization says since when" "Expired 3 days ago"
expect_no_text "40 days away raises nothing" "Expires in 40 days"
authorization="$(grep -o '/authorizations/[0-9A-Z]\{26\}/edit' <(curl -s -m 10 "$APP/authorizations") | head -1 | sed 's|/edit||; s|.*/||')"
expect_status "the form of a stored authorization names its medication" 200 "$(get "/authorizations/$authorization/edit")"
expect_text "the stored authorization keeps its tracked medication" "<dt>Medication</dt>"
expect_status "due soon below due is refused for authorizations" 200 "$(post /setup/reminders /setup/reminders \
  'authorization_due_within_days=20' 'authorization_notice_days=10')"
expect_text "due soon below due says why for authorizations" "Make the days for due soon the same as the days for due, or more."
curl -s -m 10 "$APP/api/q/v_reminder_setting" >"$BODY"
expect_text "an authorization is due at 14 days unless changed" '"authorization_due_within_days":14'

### The List Made For Paper, And History ###
expect_status "medication list for paper" 200 "$(get "/people/$alex/medication-list")"
expect_text "the list names the person" "Medication list for Alex Example"
expect_text "the list holds a medication in use" "Prinivil"
expect_text "the list shows the icon of the form" '<title>Tablet</title>'
expect_text "the list marks a medication taken as needed" "(as needed)"
expect_status "the list of a person who does not exist" 303 "$(get /people/01J8MEDS0000000000N0NE0001/medication-list)"
expect_status "history page" 200 "$(get "/fills?person=$alex")"
expect_text "history shows an amount with its thousands" "1,012.50"
expect_text "history shows the note of a fill" "Note: Paid in cash"
expect_text "history has a column for the quantity" '<th scope="col" role="columnheader">Quantity</th>'
expect_text "history has a column for the days supply" '<th scope="col" role="columnheader">Days supply</th>'
expect_text "a whole quantity has no decimals" 'aria-hidden="true">Quantity</span>30</td>'
expect_no_text "no quantity shows zeros that say nothing" "30.000"
expect_status "a fill with a part of a package" 303 "$(post /setup/people/new /fills/new \
  "entry_id=$(entry_of Glucophage)" "pharmacy_id=$pharmacy" "filled_on=$(day '-150 days')" \
  'days_supply=30' 'quantity=2.50')"
expect_status "history after the fill" 200 "$(get "/fills?person=$alex")"
expect_text "a part of a package keeps the decimals that count" 'aria-hidden="true">Quantity</span>2.5</td>'
expect_text "history totals the amounts exactly" "Total paid"
expect_text "history shows money in dollars" '$1,012.50'
expect_text "history names the portal button" "Copy refill history from patient portal"
expect_text "history names the person column Person" '<th scope="col" role="columnheader">Person</th>'
expect_no_text "history has no plan column" '<th scope="col" role="columnheader">Plan</th>'
expect_no_text "history has no For column" '<th scope="col" role="columnheader">For</th>'
expect_text "a note sits on a row of its own" '<td role="cell" colspan="8" class="meds-notes-text">'
expect_text "history has the search box" 'name="q" type="search"'
expect_text "history has the time period drop-down" '<option value="last-90-days">Last 90 days</option>'
expect_no_flat_text "the medication filter can be left on every medication" 'name="medication" required'
expect_no_flat_text "the pharmacy filter can be left on every pharmacy" 'name="pharmacy" required'
expect_text "one person's drop-down names the medication alone" '>Prinivil</option>'
expect_status "history for everyone" 200 "$(get /fills)"
expect_text "everyone's drop-down names the person too" "Alex Example: Prinivil"
expect_status "history with every filter left empty" 200 "$(get '/fills?person=&medication=&pharmacy=&period=&q=')"
expect_text "every filter left empty lists the fills" "Rx 700001"
expect_status "history of another person keeps no medication of Alex" 200 "$(get "/fills?person=$robin&medication=$entry&period=last-90-days")"
expect_no_text "a medication of another person goes back to every medication" "value=\"$entry\" selected"
expect_text "the person tabs keep the other filters" "period=last-90-days"
expect_status "history of one tracked medication" 200 "$(get "/fills?medication=$entry")"
expect_text "history of one tracked medication shows its fills" "Rx 700001"
expect_status "history for a year with no fill" 200 "$(get '/fills?year=1999')"
expect_text "a year with no fill says so" "No fills found."
expect_status "history with a year that is not a year" 200 "$(get "/fills?year=%27%20OR%201=1")"
expect_status "history with a page that is not a number" 200 "$(get '/fills?page=abc')"
for period in this-week this-month last-week last-month last-90-days; do
  expect_status "history for the period $period" 200 "$(get "/fills?period=$period")"
done
expect_status "history for a period that is not one" 200 "$(get '/fills?period=bogus')"
expect_text "a period that is not one counts as any time" "Rx 700001"
expect_status "history searched by Rx number" 200 "$(get '/fills?q=rx%20700001')"
expect_text "a search finds the fill by its Rx number" "Rx 700001"
expect_text "a search keeps its words in the box" 'value="rx 700001"'
expect_status "history searched for nothing that exists" 200 "$(get '/fills?q=zzzqqq')"
expect_text "a search with no match says so" "No fills found."
expect_status "history searched with markup" 200 "$(get '/fills?q=%3Cscript%3Ealert(7)%3C/script%3E')"
expect_no_text "a searched script is never echoed as markup" "<script>alert(7)"
expect_status "reports tab" 200 "$(get "/fills/reports?person=$alex")"
expect_text "reports show what was paid by year" "Paid by year"
expect_text "reports draw the chart as an image with a title" '<title id="meds-chart-title">Total paid each year</title>'
expect_text "reports link the printable report" "Printable report (opens in a new tab)"
expect_text "the tabs mark the reports tab" 'aria-current="page">Reports</a>'
expect_status "reports for a year with no fill" 200 "$(get '/fills/reports?period=1999')"
expect_text "reports with no fill say so" "No fills found."
expect_status "printable report" 200 "$(get "/fills/reports/print?person=$alex")"
expect_text "the printable report names the person" "Fills for Alex Example"
expect_text "the printable report has a Print button" "data-print hidden"
expect_text "the printable report totals each person" "Total for Alex Example"
expect_text "the printable report shows money in dollars" '$1,012.50'

### Pasted Fills ###
us() { date -d "$1" +%m/%d/%Y; }
pasted="SERVICE DATEDRUG NAMEPHARMACYPLAN PAIDYOU PAIDCLAIM STATUS
$(us '-3 days')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

1 EXAMPLE STREET. ANYTOWN, MI 480000000

555-555-0100

PHARMACY ID
1234567893

RX NUMBER
700002

DAYS SUPPLY
30

QUANTITY
30

Plan Paid

\$12.00
Deductible

\$0.00
Patient Responsibility

\$5.00
$(us '-3 days')<script>alert(9)</script> 5 MGEXAMPLE PHARMACY\$ 1.00\$ 1.00PaidLess Infosort Icon
EXAMPLE PHARMACY

RX NUMBER
700003
$(us '-4 days')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidMore Infosort Icon
$(us '-5 days')ATORVASTATIN 20 MG TABLETSAMPLE DRUGS\$ 3.00\$ 2.25ReversedLess Infosort Icon
SAMPLE DRUGS

2 SAMPLE ROAD. ANYTOWN, MI 480000000

555-555-0133

PHARMACY ID
1245319599

RX NUMBER
700004

DAYS SUPPLY
90

QUANTITY
90

Patient Responsibility

\$2.25"
expect_status "paste page" 200 "$(get "/fills/paste?person=$alex")"
expect_text "paste page has its heading" "<h1>Copy refill history from patient portal</h1>"
expect_text "paste page explains itself" "Use this screen to import your refill history from your patient, pharmacy or insurance"
expect_text "paste page asks whose history it is" "This refill history belongs to:"
expect_status "text with no fill in it" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" 'pasted=Hello there')"
expect_text "text with no fill says what to do" "found no fills in that text"
expect_status "a paste for nobody is refused" 200 "$(post /fills/paste /fills/paste/read 'person_id=' "pasted=$pasted")"
expect_text "a paste for nobody says why" "Choose the person"
expect_status "a paste that is too long is refused" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" \
  "pasted=$(printf 'x%.0s' $(seq 1 60001))")"
expect_text "a paste that is too long says why" "Paste fewer fills at a time"
expect_status "the pasted text is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$pasted")"
expect_text "the review counts the fills" "4 fills found. 2 ready to add. 3 names are new to the app."
expect_text "a name with the same drug and strength is matched" "One medication has the same name and the same strength."
expect_text "the matched medication is marked" "value=\"$prinivil\" checked"
expect_text "a second name is matched too" "name=\"medication_4_choice\""
expect_text "a name the catalog lacks starts as a new medication" 'name="medication_2_choice" value="new" checked'
expect_text "the strength of a new medication is read from the name" 'name="medication_2_strength" data-lookup-field="strength" type="text" value="5 mg"'
expect_text "every name can be linked to another medication" 'name="medication_1_name"'
expect_no_text "a fill that cannot be added asks for no choice" 'name="medication_3_choice"'
expect_text "a fill with closed details says so" "Details missing"
expect_text "markup in the pasted text is shown escaped" "&lt;script&gt;alert(9)&lt;/script&gt;"
expect_no_text "markup in the pasted text is never sent as markup" "<script>alert(9)</script>"
expect_text "the amounts that are not stored say so" "not stored"
expect_text "a pharmacy that is known says so" "Known pharmacy"
expect_text "a pharmacy that is not known can be added" "Add SAMPLE DRUGS, with the address and phone number that were pasted"
expect_text "a fill that was not paid starts unmarked" 'name="include_4" type="checkbox" value="yes">'
expect_text "a fill that is ready starts marked" 'name="include_1" type="checkbox" value="yes" checked>'
expect_flat_text "a pasted medication starts as Taking regularly" \
  'name="medication_4_status" aria-describedby="status-help"> <option value="taking_regularly" selected>'
expect_flat_text "a medication taken regularly keeps its status" \
  'name="medication_1_status" aria-describedby="status-help"> <option value="taking_regularly" selected>'

fills_before="$(count_of fill)"; names_before="$(count_of medication_alias)"; pharmacies_before="$(count_of pharmacy)"
medications_before="$(count_of medication)"
expect_status "adding without the token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST \
  --data-urlencode "person_id=$alex" --data-urlencode "pasted=$pasted" --data-urlencode 'include_1=yes' "$APP/fills/paste/add")"
expect_status "a fill whose medication is not chosen is not added" 200 "$(post /fills/paste /fills/paste/add \
  "person_id=$alex" "pasted=$pasted" 'include_1=yes' 'include_4=yes' "medication_4_choice=$lipitor" 'pharmacy_4=new')"
expect_text "an open choice says so" "Nothing was added yet. 1 choice is still open."
expect_text "an open choice keeps the marks" 'name="include_4" type="checkbox" value="yes" checked>'
expect_status "a choice that names nothing is not added" 200 "$(post /fills/paste /fills/paste/add \
  "person_id=$alex" "pasted=$pasted" 'include_1=yes' 'medication_1_choice=01J8MEDS0000000000N0NE0001')"
expect_status "a pharmacy that names nothing is not added" 200 "$(post /fills/paste /fills/paste/add \
  "person_id=$alex" "pasted=$pasted" 'include_4=yes' "medication_4_choice=$lipitor" \
  'pharmacy_4=01J8MEDS0000000000N0NE0001')"
expect_text "a pharmacy that names nothing says why" "Choose a pharmacy from the list."
expect_status "nothing was added by the refused requests" "$fills_before" "$(count_of fill)"
# Fill 3 cannot be added, so marking it changes nothing. Fill 2 is left out, so the
# medication that was filled in for it is not added.
expect_status "the fills are added" 303 "$(post /fills/paste /fills/paste/add "person_id=$alex" "pasted=$pasted" \
  'include_1=yes' "medication_1_choice=$prinivil" \
  'medication_2_choice=new' 'medication_2_generic=Never Added' \
  'include_3=yes' "medication_3_choice=$prinivil" \
  'include_4=yes' "medication_4_choice=$lipitor" 'pharmacy_4=new' \
  'medication_1_status=cured' 'medication_4_status=taking_regularly')"
expect_status "only the fills that can be added are added" "$((fills_before + 2))" "$(count_of fill)"
expect_status "the names of the portal are remembered" "$((names_before + 2))" "$(count_of medication_alias)"
expect_status "the new pharmacy is added once" "$((pharmacies_before + 1))" "$(count_of pharmacy)"
expect_status "a medication no fill uses is not added" "$medications_before" "$(count_of medication)"
expect_status "history after the paste" 200 "$(get "/fills?person=$alex&added=2")"
expect_text "history confirms the paste" "2 fills added."
expect_text "a pasted fill has its prescription number" "Rx 700002"
curl -s -m 10 "$APP/api/q/v_last_fill" >"$BODY"
if grep -o '{[^}]*"rx_number":"700002"[^}]*}' "$BODY" | grep -q "\"plan_id\":\"$plan_b\""; then
  pass
else
  fail "pasted fill keeps the person's current plan"
fi
curl -s -m 10 "$APP/api/row/person_medication/01J8MEDS0000000000TEST0003" >"$BODY"
expect_text "a pasted fill lowers the refills left by one" '"refills_left":"1"'
expect_status "pharmacies after the paste" 200 "$(get /setup/pharmacies)"
expect_text "the new pharmacy has its details" "2 SAMPLE ROAD. ANYTOWN, MI 480000000"
expect_text "the new pharmacy has its identifier" "1245319599"

expect_status "the same text is read again" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$pasted")"
expect_text "a fill that was added is already recorded" "Already recorded"
expect_text "only the fill that was left out is ready the second time" "4 fills found. 1 ready to add. 1 name is new to the app."
fills_before="$(count_of fill)"
expect_status "the same text is added again" 303 "$(post /fills/paste /fills/paste/add "person_id=$alex" "pasted=$pasted" \
  'include_1=yes' 'include_4=yes')"
expect_status "pasting the same page twice adds nothing" "$fills_before" "$(count_of fill)"

# The names of the portal are known now, so a later page needs no choices.
later="$(us '-1 day')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
700009

DAYS SUPPLY
30
$(us '-1 day')ATORVASTATIN 20 MG TABLETSAMPLE DRUGS\$ 3.00\$ 2.25ReversedLess Infosort Icon
SAMPLE DRUGS

PHARMACY ID
1245319599

RX NUMBER
700010
$(us '-2 days')PASTEDOL ER 7.5 MG CAPSULESAMPLE DRUGS\$ 3.00\$ 2.25PaidLess Infosort Icon
SAMPLE DRUGS

PHARMACY ID
1245319599

RX NUMBER
700011

DAYS SUPPLY
30"
expect_status "a medication is stopped before a paste" 303 "$(post /setup/people/new "/medications/$entry/status" 'status=not_taking')"
expect_status "a later page is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$later")"
expect_flat_text "a stopped medication starts as Taking regularly" \
  'name="medication_1_status" aria-describedby="status-help"> <option value="taking_regularly" selected>'
expect_text "a fill with a known name and pharmacy is ready" "3 fills found. 2 ready to add. 1 name is new to the app."
expect_text "a claim that was not paid says so" "Not paid"
expect_text "a claim that was not paid names its status" "Reversed"
expect_text "a name that was chosen once is known" "Known name"
expect_no_text "a known name asks for no choice" 'name="medication_1_choice"'
expect_text "the new name is taken apart" 'name="medication_3_generic" data-lookup-field="generic" type="text" value="Pastedol ER"'

# A medication that the catalog lacks is added from the review page, with its fill.
medications_before="$(count_of medication)"; names_before="$(count_of medication_alias)"
expect_status "a fill with a new medication is added" 303 "$(post /fills/paste /fills/paste/add \
  "person_id=$alex" "pasted=$later" 'include_1=yes' 'include_3=yes' 'medication_3_choice=new' \
  'medication_3_brand=Pastedol ER' 'medication_3_generic=Pastedoline' 'medication_3_strength=7.5 mg' \
  'medication_1_status=taking_regularly' 'medication_3_status=taking_as_needed')"
expect_status "the new medication is in the catalog" "$((medications_before + 1))" "$(count_of medication)"
expect_status "the name of the portal belongs to it" "$((names_before + 1))" "$(count_of medication_alias)"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
expect_text "the new medication is on the list under its full name" '"medication_name":"Pastedoline (Pastedol ER) 7.5 mg"'
curl -s -m 10 "$APP/api/row/person_medication/$(entry_of Pastedoline)" >"$BODY"
expect_text "a new medication gets the status chosen on the review" '"status":"taking_as_needed"'
curl -s -m 10 "$APP/api/row/person_medication/$entry" >"$BODY"
expect_text "the status chosen on the review brings a medication back" '"status":"taking_regularly"'

# A prescription number that an earlier fill has names the medication, however the
# portal writes the number and the name.
# The first two fills are on dates with no fill of the medication, so they stay to be added.
numbered="$(us '-11 days')LISINOPRIL (GENERIC) TABSEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
7000-02

DAYS SUPPLY
30
$(us '-12 days')BLOOD PRESSURE PILLEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
700 002

DAYS SUPPLY
30
$(us '-3 days')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
70-0002

DAYS SUPPLY
30"
expect_status "a page with known prescription numbers is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$numbered")"
expect_text "a number and a name that agree pick the medication" "Same prescription number and name"
expect_flat_text "the medication that both name is marked" "name=\"medication_1_choice\" value=\"$prinivil\" checked"
expect_text "a number alone puts the medication first and leaves the choice open" "Same prescription number</span>"
expect_flat_text "a number alone offers the medication" "name=\"medication_2_choice\" value=\"$prinivil\""
expect_no_flat_text "a number alone marks nothing" "name=\"medication_2_choice\" value=\"$prinivil\" checked"
expect_text "a number written with a hyphen is the same number" "Already recorded"

# A fill with no prescription number is known by its medication and its date. The page
# of the portal gives the fill a number, which must not let it in a second time.
typed_day="$(date -d '-20 days' +%Y-%m-%d)"
expect_status "a fill with no prescription number is recorded" 200 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' \
  -d "{\"events\":[{\"op\":\"put\",\"tbl\":\"fill\",\"id\":\"01J8MEDS0000000000TEST0007\",\"d\":{\"person_medication_id\":\"$entry\",\"medication_id\":\"$prinivil\",\"pharmacy_id\":\"01J8MEDS0000000000TEST0001\",\"filled_on\":\"$typed_day\",\"days_supply\":30,\"quantity\":\"30\"}}],\"since\":0}" \
  "$APP/api/events")"
repeated="SERVICE DATEDRUG NAMEPHARMACYPLAN PAIDYOU PAIDCLAIM STATUS
$(us '-20 days')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
700009

DAYS SUPPLY
30
$(us '-22 days')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
700009

DAYS SUPPLY
30"
expect_status "a page with a fill that was typed by hand is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$repeated")"
expect_text "the same medication on the same date is already recorded" "This person has a fill of this medication on the same date."
expect_text "paste review explains the payer" "Example Plan B"
expect_text "the same medication on another date is ready" "2 fills found. 1 ready to add."
expect_no_flat_text "a fill that is already recorded cannot be marked" 'name="include_1"'
fills_before="$(count_of fill)"
expect_status "the page is added" 303 "$(post /fills/paste /fills/paste/add "person_id=$alex" "pasted=$repeated" \
  'include_1=yes' 'include_2=yes')"
expect_status "only the fill of the other date is added" "$((fills_before + 1))" "$(count_of fill)"

# A long page with many names is read inside the limits of one request.
many="SERVICE DATEDRUG NAMEPHARMACYPLAN PAIDYOU PAIDCLAIM STATUS"
number=0
for drug in LISINOPRIL METFORMIN ATORVASTATIN ACETAMINOPHEN AMOXICILLIN LEVOTHYROXINE ALBUTEROL \
            FLUTICASONE OMEPRAZOLE SERTRALINE LOSARTAN GABAPENTIN AMLODIPINE SIMVASTATIN MONTELUKAST \
            ESCITALOPRAM ROSUVASTATIN BUPROPION FUROSEMIDE PANTOPRAZOLE TRAZODONE FLUOXETINE \
            TAMSULOSIN MELOXICAM PREDNISONE CITALOPRAM CARVEDILOL DULOXETINE CLONAZEPAM ZZQXOL; do
  for strength in '10 MG TABLET' '20 MG CAPSULE'; do
    number=$((number + 1))
    many="$many
$(us "-$number days")$drug $strength""EXAMPLE PHARMACY\$ 1.00\$ 1.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
80$number

DAYS SUPPLY
30"
  done
done
expect_status "a page with 60 names is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$many")"
expect_text "every fill of the long page is found" "60 fills found."

### Time Of Day ###
# A time of day of the starter list shows its icons before the words; a time the
# household typed itself shows the words alone.
expect_status "medications with a starter time and a typed time are recorded" 200 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"events\":[{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0020\",\"d\":{\"person_id\":\"$alex\",\"display_name\":\"Twice a day\",\"status\":\"taking_regularly\",\"when_to_take\":\"Morning and Evening\",\"refills_left\":0}},{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0021\",\"d\":{\"person_id\":\"$alex\",\"display_name\":\"Every other day\",\"status\":\"taking_regularly\",\"when_to_take\":\"Every other day at noon\",\"refills_left\":0}}]}" \
  "$APP/api/events")"
expect_status "the medication page with a time of day" 200 "$(get /medications/01J8MEDS0000000000TEST0020)"
if flat_body | grep -qE '<dt>When</dt><dd><svg [^>]*aria-hidden="true"[^>]*>.*</svg> <svg [^>]*aria-hidden="true"[^>]*>.*</svg> Morning and Evening</dd>'; then
  pass; else fail "the When row shows two hidden icons before the words"; fi
expect_status "the medications page with a time of day" 200 "$(get "/medications?person=$alex")"
if flat_body | grep -qE '<span class="pv-meta meds-line"><svg [^>]*aria-hidden="true"[^>]*>.*</svg> <svg [^>]*>.*</svg> Morning and Evening</span>'; then
  pass; else fail "the list shows the icons before the time of day"; fi
expect_flat_text "a time of the household shows no icon" '<span class="pv-meta meds-line">Every other day at noon</span>'

### Setup ###
expect_status "setup page" 200 "$(get /setup)"
expect_text "setup page calls the people the family" "<span>Family</span>"
expect_text "setup page has a box for the insurance plans" "<span>Insurance plans</span>"
expect_no_text "setup page boxes carry no description" "in the app.</small>"
expect_no_text "setup page has no plain button for the plans" '<p><a class="pv-btn" href="/a/meds/setup/plans">'
expect_status "family page" 200 "$(get /setup/people)"
expect_text "family page has its heading" "<h1>Family</h1>"
expect_no_text "setup page asks for no household name" "Household name"

### Report ###
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
