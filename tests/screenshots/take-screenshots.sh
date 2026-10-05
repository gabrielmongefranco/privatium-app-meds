#!/usr/bin/env bash
# This file is part of Prescription Tracker
# tests/screenshots/take-screenshots.sh
# Author(s): Gabriel Mongefranco
# Created: 2026-10-05
# Last Modified: 2026-10-05
# Summary: Takes the screenshots of the documentation. Starts a Privatium node on a
#          temporary data directory and a headless Firefox, loads the invented household
#          of tests/fixtures/sample-household.json, and saves one PNG per screen.
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
#   PRIVATIUM=/path/to/privatium tests/screenshots/take-screenshots.sh [output folder]
# Exit codes: 0 every screenshot was saved, 1 a page or a load failed, 2 it could not start.

set -u

### Load Configuration ###
PRIVATIUM="${PRIVATIUM:-privatium}"         # The Privatium program, 0.3.2 or later
FIREFOX="${FIREFOX:-firefox}"               # Firefox 128 or later, run headless
NODE="${NODE:-node}"                        # Node.js 20 or later
PORT="${MEDS_SHOT_PORT:-18491}"             # Loopback port of the temporary node
BIDI_PORT="${MEDS_BIDI_PORT:-9222}"         # Loopback port Firefox listens on for WebDriver BiDi
START_TIMEOUT_SECONDS=30
REPOSITORY="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="${1:-$REPOSITORY/docs/images}"

### Validate Inputs ###
for tool in "$PRIVATIUM" "$FIREFOX" "$NODE" curl mktemp; do
  command -v "$tool" >/dev/null 2>&1 || { echo "screenshots: $tool was not found"; exit 2; }
done
[ -f "$REPOSITORY/apps/meds/app.toml" ] || { echo "screenshots: apps/meds was not found"; exit 2; }
mkdir -p "$OUTPUT" || { echo "screenshots: cannot write to $OUTPUT"; exit 2; }

### Start The Node And The Browser ###
# The app is copied, not linked, so nothing is written inside the repository.
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/meds-shots.XXXXXX")" || { echo "screenshots: no temporary folder"; exit 2; }
mkdir -p "$ROOT/apps" "$ROOT/profile" && cp -R "$REPOSITORY/apps/meds" "$ROOT/apps/meds"
NODE_PID=""
FIREFOX_PID=""

stop_all() {
  [ -n "$FIREFOX_PID" ] && kill "$FIREFOX_PID" 2>/dev/null && wait "$FIREFOX_PID" 2>/dev/null
  [ -n "$NODE_PID" ] && kill "$NODE_PID" 2>/dev/null && wait "$NODE_PID" 2>/dev/null
  # Only the folder this script made is removed.
  case "$ROOT" in
    */meds-shots.*) rm -rf "$ROOT" ;;
  esac
}
trap stop_all EXIT

"$PRIVATIUM" --data-dir "$ROOT" --port "$PORT" --no-discovery >"$ROOT/node.log" 2>&1 &
NODE_PID=$!
"$FIREFOX" --headless --no-remote --profile "$ROOT/profile" \
  --remote-debugging-port "$BIDI_PORT" about:blank >"$ROOT/firefox.log" 2>&1 &
FIREFOX_PID=$!

waited=0
until curl -s -o /dev/null -m 2 "http://127.0.0.1:$PORT/a/meds/" \
   && curl -s -o /dev/null -m 2 "http://127.0.0.1:$BIDI_PORT/"; do
  waited=$((waited + 1))
  if [ "$waited" -ge "$START_TIMEOUT_SECONDS" ]; then
    echo "screenshots: the node or Firefox did not start. Their logs follow."
    cat "$ROOT/node.log" "$ROOT/firefox.log"
    exit 2
  fi
  sleep 1
done

### Take The Screenshots ###
# Node 20 needs a flag for the WebSocket client that later versions have built in.
NODE_FLAGS=()
"$NODE" -e 'process.exit(typeof WebSocket === "function" ? 0 : 1)' 2>/dev/null \
  || NODE_FLAGS=(--experimental-websocket)

"$NODE" "${NODE_FLAGS[@]}" "$REPOSITORY/tests/screenshots/take-screenshots.mjs" \
  "http://127.0.0.1:$PORT" "$BIDI_PORT" "$REPOSITORY/tests/fixtures/sample-household.json" "$OUTPUT"
