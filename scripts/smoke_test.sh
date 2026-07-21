#!/bin/sh
# TrenchNote smoke test -- the regression gate.
#
# Boots a FRESH PocketBase from the repo's migrations, runs the full
# scripts/seed_demo.sh, and then asserts -- through the public REST API,
# exactly as a phone in a dirt lot would -- that the invariants this
# product is built on still hold:
#
#   * every migration applies, every collection exists;
#   * auth is required EVERYWHERE (ADR 0004 / migration 1783468806);
#   * the movements ledger is append-only (update/delete superuser-only);
#   * the movement shape rules hold server-side (asset move vs bulk move);
#   * an asset move updates the current_location cache;
#   * bulk stock derives correctly, in-minus-out, per location;
#   * a negative balance is REPRESENTABLE (a data error to be surfaced,
#     never a write the server silently swallows -- ADR 0002/0005);
#   * reservations cannot be born closed, and can be closed by a human;
#   * an inspection cannot borrow another asset's requirement (ADR 0014).
#
# WHY THIS EXISTS: the invariants above are enforced in three different
# places -- collection API rules, the write-then-cache sequence in the
# frontend, and derivation code that never stores what it computes. A
# migration written months later can loosen a createRule without anyone
# noticing, because the UI still looks right. This gate notices.
#
# It writes ONLY through the public REST API (via seed_demo.sh and curl)
# plus the admin bootstrap an operator would run -- no pb_data/ surgery.
# The throwaway database lives in a gitignored pb_data_smoke/ and is
# deleted on exit; the operator's real pb_data/ is never touched.
#
# Usage:   ./scripts/smoke_test.sh
#          TN_TEST_PORT=8500 ./scripts/smoke_test.sh
# Exit:    0 = all assertions passed;  1 = a regression;  2 = setup failure.
#
# Needs: the pocketbase binary in the repo root (scripts/setup.sh), curl,
# awk, and GNU date (seed_demo.sh's requirement).

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT="${TN_TEST_PORT:-8399}"
BASE="http://127.0.0.1:$PORT"
DATA_DIR="$ROOT/pb_data_smoke"   # gitignored; relative so the native binary reads it on every OS
ADMIN_EMAIL="smoke-admin@example.com"
ADMIN_PASS="smokeadmin-123456"
DEMO_EMAIL="smoke-demo@example.com"
DEMO_PASS="smokedemo-123456"

# pocketbase binary: .exe on Windows/Git Bash, bare elsewhere.
PB="./pocketbase"
[ -f ./pocketbase.exe ] && PB="./pocketbase.exe"
if [ ! -f "$PB" ]; then
  echo "FATAL: pocketbase binary not found in repo root. Run scripts/setup.sh first." >&2
  exit 2
fi

SERVER_PID=""
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    # Block until the process is actually reaped -- on Windows the DB files
    # stay locked until it fully exits, so rm-ing before this races and fails.
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  # Belt-and-suspenders: the OS can hold the file handles a moment longer.
  n=0
  while [ -d "$DATA_DIR" ] && [ "$n" -lt 10 ]; do
    rm -rf "$DATA_DIR" 2>/dev/null && break
    n=$((n + 1)); sleep 1
  done
}
trap cleanup EXIT INT TERM

# ---- tiny assertion harness -------------------------------------------------
PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$1"; }
# nonzero LABEL ACTUAL  -- pass when ACTUAL is an integer > 0. A seed block
# that silently skipped drops its collection to 0; that is the failure.
nonzero() {
  case "$2" in
    ''|*[!0-9]*) bad "$1: expected a positive count, got '$2'" ;;
    0)           bad "$1: expected > 0, got 0 (seed block skipped?)" ;;
    *)           ok "$1 ($2)" ;;
  esac
}
# zero LABEL ACTUAL  -- pass when ACTUAL is exactly 0. The auth check: a
# guest must see NOTHING. PocketBase answers an unsatisfied listRule with
# 200 + an empty list, not 401 (see CLAUDE.md, "Security posture"), so
# "denied" is proved by an empty count, not by a status code.
zero() {
  case "$2" in
    0)           ok "$1 (guest sees 0)" ;;
    ''|*[!0-9]*) bad "$1: expected 0, got '$2'" ;;
    *)           bad "$1: guest saw $2 records (data LEAKED to anon)" ;;
  esac
}
# equals LABEL EXPECTED ACTUAL
equals() {
  if [ "$2" = "$3" ]; then ok "$1 (= $3)"; else bad "$1: expected $2, got $3"; fi
}
# rejected LABEL CODE  -- pass when CODE is NOT 2xx (the write was refused).
rejected() { case "$2" in 2*) bad "$1 (got $2 -- write was ALLOWED)";; *) ok "$1 (HTTP $2)";; esac; }
# accepted LABEL CODE  -- pass when CODE is 2xx.
accepted() { case "$2" in 2*) ok "$1 (HTTP $2)";; *) bad "$1 (HTTP $2)";; esac; }

# ---- API helpers ------------------------------------------------------------
# Every read here carries $TOKEN (the ordinary demo user). It is empty until
# step 4; the calls before then are deliberately anonymous.
#
# Filters go through curl's --data-urlencode: PocketBase filter syntax is full
# of quotes, parens and spaces, and hand-encoding them is how these scripts rot.

# total COLLECTION [filter]  -> totalItems
total() {
  curl -s -G "$BASE/api/collections/$1/records" \
    --data 'perPage=1' ${2:+--data-urlencode "filter=$2"} \
    -H "Authorization: ${TOKEN:-}" \
    | sed -n 's/.*"totalItems":\([0-9]*\).*/\1/p'
}
# anon_total COLLECTION  -> totalItems for an UNAUTHENTICATED read.
anon_total() {
  curl -s -G "$BASE/api/collections/$1/records" --data 'perPage=1' \
    | sed -n 's/.*"totalItems":\([0-9]*\).*/\1/p'
}
# first_id COLLECTION [filter]  -> first matching 15-char record id
first_id() {
  curl -s -G "$BASE/api/collections/$1/records" \
    --data 'perPage=1' ${2:+--data-urlencode "filter=$2"} \
    -H "Authorization: ${TOKEN:-}" \
    | sed -n 's/.*"id":"\([a-z0-9]\{15\}\)".*/\1/p' | head -1
}
# post COLLECTION JSON  -> creates a record, echoes its id. Aborts the run on
# failure: these are the fixtures the later assertions stand on.
post() {
  _body=$(curl -s -X POST "$BASE/api/collections/$1/records" \
    -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d "$2")
  _id=$(printf '%s' "$_body" | sed -n 's/.*"id":"\([a-z0-9]\{15\}\)".*/\1/p' | head -1)
  if [ -z "$_id" ]; then
    echo "FATAL: fixture create in '$1' failed: $_body" >&2
    exit 2
  fi
  printf '%s' "$_id"
}
# post_status COLLECTION JSON  -> HTTP code of an authenticated create
post_status() {
  curl -s -o /dev/null -w '%{http_code}' -X POST \
    "$BASE/api/collections/$1/records" \
    -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d "$2"
}
# anon_post_status COLLECTION JSON  -> HTTP code of an UNAUTHENTICATED create
anon_post_status() {
  curl -s -o /dev/null -w '%{http_code}' -X POST \
    "$BASE/api/collections/$1/records" \
    -H "Content-Type: application/json" -d "$2"
}
# patch_status COLLECTION ID JSON  -> HTTP code of an authenticated PATCH
patch_status() {
  curl -s -o /dev/null -w '%{http_code}' -X PATCH \
    "$BASE/api/collections/$1/records/$2" \
    -H "Content-Type: application/json" -H "Authorization: $TOKEN" -d "$3"
}
# delete_status COLLECTION ID  -> HTTP code of an authenticated DELETE
delete_status() {
  curl -s -o /dev/null -w '%{http_code}' -X DELETE \
    "$BASE/api/collections/$1/records/$2" -H "Authorization: $TOKEN"
}
# field COLLECTION ID KEY  -> value of a string field on one record
field() {
  curl -s "$BASE/api/collections/$1/records/$2" -H "Authorization: $TOKEN" \
    | sed -n "s/.*\"$3\":\"\([^\"]*\)\".*/\1/p"
}
# sum_qty FILTER  -> sum of movements.quantity over the matching movements.
# This is the derivation the dashboard and material.html do in JS. Doing it
# here in the test, from the raw ledger, is the point: stock is DERIVED
# in-minus-out and never stored (ADR 0002), so the test derives it too.
sum_qty() {
  curl -s -G "$BASE/api/collections/movements/records" \
    --data 'perPage=500' --data-urlencode "filter=$1" \
    -H "Authorization: $TOKEN" \
    | grep -o '"quantity":[0-9]*' | cut -d: -f2 \
    | awk '{ s += $1 } END { print s + 0 }'
}
# balance ITEM LOCATION  -> derived stock of ITEM at LOCATION (in minus out)
balance() {
  _in=$(sum_qty "item='$1' && to_location='$2'")
  _out=$(sum_qty "item='$1' && from_location='$2'")
  echo $((_in - _out))
}
# http_status METHOD URL  -> HTTP code, no body, no token
http_status() { curl -s -o /dev/null -w '%{http_code}' -X "$1" "$2"; }

TOKEN=""

# ---- 0. clean slate + guard the port ----------------------------------------
rm -rf "$DATA_DIR"
mkdir -p "$DATA_DIR"
if curl -s -o /dev/null "$BASE/api/health" 2>/dev/null; then
  echo "FATAL: something is already listening on port $PORT." >&2
  echo "       Set TN_TEST_PORT to a free port and retry." >&2
  exit 2
fi

# ---- 1. bootstrap admin + boot the server -----------------------------------
echo "==> booting a fresh PocketBase on port $PORT (throwaway DB)"
"$PB" superuser upsert "$ADMIN_EMAIL" "$ADMIN_PASS" \
  --dir="$DATA_DIR" --migrationsDir="$ROOT/pb_migrations" \
  --hooksDir="$ROOT/pb_hooks" --publicDir="$ROOT/pb_public" >"$DATA_DIR/setup.log" 2>&1 \
  || { echo "FATAL: superuser bootstrap failed:" >&2; cat "$DATA_DIR/setup.log" >&2; exit 2; }

"$PB" serve --http="127.0.0.1:$PORT" \
  --dir="$DATA_DIR" --migrationsDir="$ROOT/pb_migrations" \
  --hooksDir="$ROOT/pb_hooks" --publicDir="$ROOT/pb_public" >"$DATA_DIR/serve.log" 2>&1 &
SERVER_PID=$!

i=0
until curl -s -o /dev/null "$BASE/api/health" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 30 ]; then
    echo "FATAL: server did not come up in 30s. serve.log:" >&2
    cat "$DATA_DIR/serve.log" >&2
    exit 2
  fi
  sleep 1
done
echo "  up (migrations applied with no fatal error)"

# ---- 2. auth is required everywhere (ADR 0004) ------------------------------
# Done BEFORE signing in, while the run is genuinely anonymous. Two halves:
# a guest lists nothing, and a guest writes nothing. The database is empty at
# this point, so an empty list would be vacuously true -- which is why the
# write half matters, and why step 6 re-runs the read half against a database
# that is full.
echo "==> auth required everywhere, anonymous (ADR 0004)"
rejected "anon create item"     "$(anon_post_status items '{"name":"Anon Item","tracking_mode":"bulk"}')"
rejected "anon create location" "$(anon_post_status locations '{"name":"Anon Yard","type":"yard"}')"
rejected "anon create movement" "$(anon_post_status movements '{"quantity":1}')"
# No public self-signup: an accountless visitor cannot mint themselves a user.
rejected "anon self-signup refused" \
  "$(anon_post_status users '{"email":"intruder@example.com","password":"intruder-123456","passwordConfirm":"intruder-123456"}')"

# ---- 3. every expected collection exists ------------------------------------
# 14 collections (CLAUDE.md, "Data model"). A migration that throws on load
# leaves its collection missing while the server still boots -- this catches
# that. 404 = missing; 200/403 = present.
echo "==> all migrations applied (collection set)"
for c in items locations assets movements readings reservations \
         inspection_requirements inspections condition_reports \
         condition_resolutions manifests manifest_lines \
         container_events kit_audits; do
  code=$(http_status GET "$BASE/api/collections/$c/records?perPage=1")
  if [ "$code" = "404" ]; then bad "collection $c MISSING (HTTP 404)"; else ok "collection $c"; fi
done
# The holding location the manifest receipt writes shortfalls to (ADR 0020)
# is created by migration, not by the seed -- a fresh self-hoster must have it.
# Read as superuser-free anon count is 0 by design, so this is checked in step 6.

# ---- 4. create the demo user + run the real seed ----------------------------
echo "==> creating demo user + running scripts/seed_demo.sh"
SU=$(curl -s -X POST "$BASE/api/collections/_superusers/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$SU" ] || { echo "FATAL: could not authenticate as the smoke superuser." >&2; exit 2; }
# Accounts are made by an admin, never by self-signup (step 2 proved that),
# so the demo user is created with the superuser token -- as an operator would.
ucode=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/api/collections/users/records" \
  -H "Content-Type: application/json" -H "Authorization: $SU" \
  -d "{\"email\":\"$DEMO_EMAIL\",\"password\":\"$DEMO_PASS\",\"passwordConfirm\":\"$DEMO_PASS\"}")
case "$ucode" in 2*) ;; *) echo "FATAL: could not create demo user (HTTP $ucode)." >&2; exit 2;; esac

TN_URL="$BASE" TN_EMAIL="$DEMO_EMAIL" TN_PASSWORD="$DEMO_PASS" \
  sh "$ROOT/scripts/seed_demo.sh" >"$DATA_DIR/seed.log" 2>&1 \
  || { echo "FATAL: seed_demo.sh aborted -- the API rejected something:" >&2; cat "$DATA_DIR/seed.log" >&2; exit 2; }
echo "  seed ran to completion"

TOKEN=$(curl -s -X POST "$BASE/api/collections/users/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"$DEMO_EMAIL\",\"password\":\"$DEMO_PASS\"}" \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$TOKEN" ] || { echo "FATAL: could not authenticate as the demo user." >&2; exit 2; }

# ---- 5. the seed populated what it claims to --------------------------------
# Non-empty, not exact: exact counts would break every time the demo story is
# tweaked, while a block that silently skipped drops straight to 0.
echo "==> demo seed populated each collection it writes (> 0)"
for c in items locations assets movements readings reservations \
         inspection_requirements inspections condition_reports \
         condition_resolutions manifests manifest_lines; do
  nonzero "$c" "$(total "$c")"
done
# Migration-created, not seeded: the shortfall holding location (ADR 0020).
nonzero "'Missing in transfer' location seeded by migration" \
  "$(total locations "name='Missing in transfer'")"

# ---- 6. auth lockdown against a FULL database -------------------------------
# Step 2 proved a guest cannot write. Now that the database has data in it,
# prove a guest cannot READ it either -- for every collection. This is the
# assertion that would catch a listRule accidentally reverted to public.
echo "==> auth lockdown: a guest reads nothing (full database)"
for c in items locations assets movements readings reservations \
         inspection_requirements inspections condition_reports \
         condition_resolutions manifests manifest_lines; do
  zero "anon list $c" "$(anon_total "$c")"
done
# viewRule too: a guest fetching a known record id by hand is refused.
rejected "anon view of a known asset refused" \
  "$(http_status GET "$BASE/api/collections/assets/records/$(first_id assets)")"

# ---- 7. the ledgers are append-only -----------------------------------------
# update/delete are superuser-only on every ledger (CLAUDE.md, "Security
# posture"). Corrections are new records, never edits -- these numbers end up
# on invoices and in vendor disputes.
# The two Gang Box ledgers are not part of the demo story, so they have no
# records to tamper with yet; step 14 builds its own fixtures and asserts
# them there. Skipping them silently here is the exact failure this gate
# exists to catch, so they are named there rather than looped over here.
echo "==> append-only ledgers reject update + delete"
for c in movements readings inspections condition_reports condition_resolutions; do
  _id=$(first_id "$c")
  [ -n "$_id" ] || { bad "$c: no record to test immutability against"; continue; }
  rejected "$c rejects PATCH"  "$(patch_status "$c" "$_id" '{"note":"tampered"}')"
  rejected "$c rejects DELETE" "$(delete_status "$c" "$_id")"
done

# ---- 8. movement shape rules hold server-side -------------------------------
# One collection holds both kinds of move, told apart by which fields are set
# (CLAUDE.md, "movements"). The UI only ever builds valid shapes; these rules
# are what stops a bad sidecar, a replayed offline queue, or a curl typo from
# writing a movement that means nothing.
echo "==> movement shape rules (migrations 1783468805-1783468807)"
SITE=$(post locations '{"name":"Smoke Test Site","type":"jobsite"}')
YARD=$(post locations '{"name":"Smoke Test Yard","type":"yard"}')
BULK=$(post items '{"name":"Smoke Test Pipe Supports","tracking_mode":"bulk","category":"Pipe Supports"}')
UNIQ=$(post items '{"name":"Smoke Test Total Station","tracking_mode":"unique","category":"Survey"}')
AST=$(post assets "{\"item\":\"$UNIQ\",\"tag_code\":\"SMK1\",\"ownership\":\"owned\",\"current_location\":\"$YARD\"}")

rejected "asset move without to_location refused" \
  "$(post_status movements "{\"asset\":\"$AST\",\"from_location\":\"$YARD\",\"moved_by\":\"smoke\"}")"
rejected "bulk move with quantity 0 refused" \
  "$(post_status movements "{\"item\":\"$BULK\",\"quantity\":0,\"to_location\":\"$YARD\"}")"
rejected "bulk move with no location at all refused" \
  "$(post_status movements "{\"item\":\"$BULK\",\"quantity\":5}")"
rejected "hybrid asset+item movement refused" \
  "$(post_status movements "{\"asset\":\"$AST\",\"item\":\"$BULK\",\"quantity\":5,\"to_location\":\"$SITE\"}")"

# ---- 9. an asset move updates the location cache ----------------------------
# The write-movement-THEN-update-cache sequence (CLAUDE.md, "Model
# principles"): the ledger is the truth, assets.current_location is a
# convenience cache. Both halves are asserted, in that order.
echo "==> asset move: ledger first, then the current_location cache"
accepted "asset move accepted" \
  "$(post_status movements "{\"asset\":\"$AST\",\"from_location\":\"$YARD\",\"to_location\":\"$SITE\",\"moved_by\":\"smoke test\"}")"
equals "movement recorded in the ledger" 1 "$(total movements "asset='$AST'")"
accepted "current_location cache updated" \
  "$(patch_status assets "$AST" "{\"current_location\":\"$SITE\"}")"
equals "asset now reads as on-site" "$SITE" "$(field assets "$AST" current_location)"

# ---- 10. bulk stock derives correctly ---------------------------------------
# Receive 100 at the yard, consume 30 there, transfer 20 to the site.
# Nothing about stock is stored -- it is summed out of the ledger, per
# location, in minus out (ADR 0002/0005).
echo "==> bulk stock derives in-minus-out (ADR 0002/0005)"
accepted "receive 100 at the yard (delivery: to-only)" \
  "$(post_status movements "{\"item\":\"$BULK\",\"quantity\":100,\"to_location\":\"$YARD\",\"note\":\"smoke delivery\"}")"
accepted "consume 30 at the yard (consumption: from-only)" \
  "$(post_status movements "{\"item\":\"$BULK\",\"quantity\":30,\"from_location\":\"$YARD\",\"note\":\"smoke install\"}")"
accepted "transfer 20 yard -> site" \
  "$(post_status movements "{\"item\":\"$BULK\",\"quantity\":20,\"from_location\":\"$YARD\",\"to_location\":\"$SITE\"}")"
equals "yard balance = 100 - 30 - 20" 50 "$(balance "$BULK" "$YARD")"
equals "site balance = 20"            20 "$(balance "$BULK" "$SITE")"
# The dashboard total: deliveries (to-only) minus consumptions (from-only).
# A transfer nets to zero across the division, which is the whole point of
# counting it this way rather than summing per-location balances.
_recv=$(sum_qty "item='$BULK' && from_location='' && to_location!=''")
_cons=$(sum_qty "item='$BULK' && to_location='' && from_location!=''")
equals "division total = deliveries - consumptions" 70 "$((_recv - _cons))"

# ---- 11. a negative balance is REPRESENTABLE --------------------------------
# Deliberate: the ledger records what a human says happened. If someone
# consumes 40 from a site that only shows 20, the server must ACCEPT the
# write -- refusing it would just push crews to log nothing at all -- and the
# negative balance is then flagged in the UI as a data error to chase down.
# It is never hidden and never silently clamped to zero (ADR 0005).
echo "==> a negative balance is representable, not blocked (ADR 0005)"
accepted "over-consumption accepted by the server" \
  "$(post_status movements "{\"item\":\"$BULK\",\"quantity\":40,\"from_location\":\"$SITE\",\"note\":\"smoke over-consumption\"}")"
_neg=$(balance "$BULK" "$SITE")
if [ "$_neg" -lt 0 ]; then
  ok "site balance derives negative ($_neg) -- surfaceable as a data error"
else
  bad "site balance should be negative after over-consumption, got $_neg"
fi

# ---- 12. reservation lifecycle (ADR 0007) -----------------------------------
# A claim cannot be born closed, and "open" includes the empty status of
# pre-status rows -- which is why the UI filters "not closed", never
# "= open". Humans close claims; nothing closes them automatically.
echo "==> reservations: cannot be born closed, can be closed by a human (ADR 0007)"
rejected "reservation created as fulfilled refused" \
  "$(post_status reservations "{\"asset\":\"$AST\",\"requested_by\":\"smoke\",\"status\":\"fulfilled\"}")"
rejected "reservation created as cancelled refused" \
  "$(post_status reservations "{\"asset\":\"$AST\",\"requested_by\":\"smoke\",\"status\":\"cancelled\"}")"
RES=$(post reservations "{\"asset\":\"$AST\",\"requested_by\":\"smoke\",\"status\":\"open\"}")
RES2=$(post reservations "{\"asset\":\"$AST\",\"requested_by\":\"smoke pre-status\"}")
equals "empty status is an OPEN claim, not a closed one" 2 \
  "$(total reservations "asset='$AST' && status!='fulfilled' && status!='cancelled'")"
accepted "a human can fulfil a claim" "$(patch_status reservations "$RES" '{"status":"fulfilled"}')"
accepted "a human can cancel a claim" "$(patch_status reservations "$RES2" '{"status":"cancelled"}')"

# ---- 13. inspections cannot borrow another asset's requirement (ADR 0014) ---
# The requirement/asset pairing is enforced server-side: a "monthly visual"
# pass logged against the wrong asset would make a DO-NOT-USE badge go green
# on a machine nobody looked at.
echo "==> inspections: requirement must belong to the same asset (ADR 0014)"
AST2=$(post assets "{\"item\":\"$UNIQ\",\"tag_code\":\"SMK2\",\"ownership\":\"owned\",\"current_location\":\"$YARD\"}")
REQ=$(post inspection_requirements "{\"asset\":\"$AST\",\"name\":\"Smoke monthly visual\",\"interval_days\":30}")
TODAY=$(date -u +%Y-%m-%d)
rejected "inspection borrowing another asset's requirement refused" \
  "$(post_status inspections "{\"asset\":\"$AST2\",\"requirement\":\"$REQ\",\"result\":\"pass\",\"inspected_at\":\"$TODAY\"}")"
accepted "inspection against its own requirement accepted" \
  "$(post_status inspections "{\"asset\":\"$AST\",\"requirement\":\"$REQ\",\"result\":\"pass\",\"inspected_at\":\"$TODAY\",\"inspected_by\":\"smoke\"}")"
accepted "ad-hoc inspection (no requirement) accepted" \
  "$(post_status inspections "{\"asset\":\"$AST2\",\"result\":\"removed_from_service\",\"inspected_at\":\"$TODAY\",\"note\":\"smoke ad-hoc\"}")"

# ---- 14. Gang Box containment is one level deep, and its ledgers append-only -
# A box holds loose assets; a box never holds another box, and an asset can
# only be dropped into a box that is standing in the same place it is. Both
# are server-enforced, because contained assets derive their location from
# the box -- a nested or teleported membership would corrupt that derivation.
echo "==> Gang Box: one-level containment, server-enforced"
BOX=$(post assets "{\"item\":\"$UNIQ\",\"tag_code\":\"SMKB\",\"ownership\":\"owned\",\"current_location\":\"$YARD\",\"is_container\":true}")
BOX2=$(post assets "{\"item\":\"$UNIQ\",\"tag_code\":\"SMKC\",\"ownership\":\"owned\",\"current_location\":\"$YARD\",\"is_container\":true}")
LOOSE=$(post assets "{\"item\":\"$UNIQ\",\"tag_code\":\"SMK3\",\"ownership\":\"owned\",\"current_location\":\"$YARD\"}")
ELSEWHERE=$(post assets "{\"item\":\"$UNIQ\",\"tag_code\":\"SMK4\",\"ownership\":\"owned\",\"current_location\":\"$SITE\"}")

rejected "a box cannot be put inside another box (no nesting)" \
  "$(post_status container_events "{\"asset_id\":\"$BOX2\",\"container_id\":\"$BOX\",\"action\":\"added\",\"location\":\"$YARD\"}")"
rejected "an asset elsewhere cannot be added to the box" \
  "$(post_status container_events "{\"asset_id\":\"$ELSEWHERE\",\"container_id\":\"$BOX\",\"action\":\"added\",\"location\":\"$SITE\"}")"
accepted "a loose asset at the box's location is added" \
  "$(post_status container_events "{\"asset_id\":\"$LOOSE\",\"container_id\":\"$BOX\",\"action\":\"added\",\"location\":\"$YARD\",\"by\":\"smoke\"}")"
# `results` is the checklist snapshot itself -- the same array asset.html
# posts. It is a required json field, so an empty array is refused: an audit
# that checked nothing is not an audit.
AUDIT_RESULTS="[{\"asset_id\":\"$LOOSE\",\"result\":\"present\"}]"
rejected "a kit audit against a non-container asset refused" \
  "$(post_status kit_audits "{\"container_id\":\"$LOOSE\",\"performed_at\":\"$TODAY\",\"results\":$AUDIT_RESULTS}")"
accepted "a kit audit against the box accepted" \
  "$(post_status kit_audits "{\"container_id\":\"$BOX\",\"performed_at\":\"$TODAY\",\"performed_by\":\"smoke\",\"results\":$AUDIT_RESULTS}")"

# Now that both Gang Box ledgers have a record, hold them to the same
# append-only rule as every other ledger.
for c in container_events kit_audits; do
  _id=$(first_id "$c")
  [ -n "$_id" ] || { bad "$c: no record to test immutability against"; continue; }
  rejected "$c rejects PATCH"  "$(patch_status "$c" "$_id" '{"by":"tampered"}')"
  rejected "$c rejects DELETE" "$(delete_status "$c" "$_id")"
done

# ---- report -----------------------------------------------------------------
echo ""
echo "-------------------------------------------------------------"
echo "smoke test: $PASS passed, $FAIL failed"
echo "-------------------------------------------------------------"
if [ "$FAIL" -ne 0 ]; then
  echo "INVARIANTS REGRESSED -- do not tag or deploy this until green." >&2
  exit 1
fi
echo "OK -- the stack reproduces from scratch and the invariants hold."
