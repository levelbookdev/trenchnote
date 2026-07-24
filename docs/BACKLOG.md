# TrenchNote — product backlog

This file is the holding pen for product ideas that are **motivated but not
yet built**. It exists so a real field incident can be captured while it is
still fresh — the war story, the shape of a fix, and the scope wall around it
— without opening a code session or committing to a design.

Each item is written so a future session can start from it cold. When an item
graduates:

1. It moves out of here into a working session (and usually an ADR, per the
   docs-as-code rule in [CLAUDE.md](../CLAUDE.md)).
2. Its entry is deleted from this file, or reduced to a one-line pointer at the
   ADR that superseded it.

An item living here is **not** a commitment to build it. Some of these will be
declined at design time for the same ethos reasons that keep TrenchNote small
(see the non-goals in [CLAUDE.md](../CLAUDE.md)). "Explicitly not" on each item
is the scope wall drawn *now*, while the motivation is clear, so a future
session does not quietly let the feature grow into an ERP.

Every item below traces to one of two real July 2026 incidents, summarized
once here and referenced by the items:

- **Incident 1 — "the missing pump."** A boxed 1/3 HP pump, bought for one
  project and parked in a *different* project's yard conex for storage, went
  missing. It had never been tagged — it went straight from purchase to
  storage without passing any cataloging step. Finding it became a reply-all
  email to eight people across roughly six job sites, with three managers
  cc'd, asking everyone to walk their sites. Negative reports ("checked mine,
  not here") piled up in the thread; someone even photographed a
  different-brand pump as a maybe-match. An APB run over email.

- **Incident 2 — "the weekly equipment timecard."** Six PMs hand-maintain a
  weekly Excel sheet mapping every owned fleet asset (trucks `P-###`,
  forklifts `FL-##`, containers `SC-##`, misc `MISC-##`) to the job number it
  sat at that week, with arrival/removal dates and month-end hour-meter /
  odometer readings. Accounting derives equipment billing from it — fractional
  job-splits like 0.25/0.25/0.25/0.25 for one week spread across four sites.
  The GM personally emails reminders to verify it before the monthly
  collection, and margin notes like "on hold; not in use" are the only way to
  record an asset's status. It is a movements ledger maintained by hand, every
  Friday, by six people.

> **Evidence addendum — three 2020 weekly timecards.** Three historical weekly
> equipment timecards surfaced later (2020, from a large single-job division —
> a different *dialect* of the same corporate form incident 2's division uses).
> Where that dialect records WHICH JOB each asset sat at weekly, this one
> records USAGE STATE per week — `X` (worked), `IDLE`, `STORED`, `BROKE DOWN`,
> with margin comments like "AWAITING REPAIR". They also exposed concrete
> data-quality failures: fat-fingered month-to-month meter readings, an `O`
> typed for a `0` inside a tag number, and a sheet filled for week 1 and left
> blank for weeks 2–4 (the Friday manual ritual dying mid-month). This is
> corroborating field evidence, not a new incident — it enriches items 5, 6,
> 7, and 8 below, and motivates the new item 13.

> **Reconciliation note (readings).** Item 6 talks about a "readings concept."
> An append-only **`readings`** ledger already ships (ADR 0012): `asset`,
> `value`, `reading_type` = `hours` | `odometer`, `recorded_by`, `photo`. So
> item 6 is really *generalize the ledger we already have* to also carry
> sighting events — not build one from scratch. It is written that way below.

---

## 1. Pre-printed unassigned tag pools

**Motivation.** Incident 1: the pump was never tagged because tagging was a
desk task that storage bypassed entirely. If a roll of labels had been sitting
in the receiving area, whoever set the pump down could have slapped one on it
in five seconds.

**Proposed shape.** Print rolls of QR labels whose `tag_code`s have no asset
behind them yet — a pool of live, unclaimed codes. Scanning an unclaimed tag
opens a lightweight "claim this tag" flow (item name, optional photo, maybe a
location) that creates the asset on the spot, instead of a 404 / "not in
TrenchNote." This turns tagging from a cataloging step into a receiving-dock
reflex: tag first, fill in details later. Fits the existing label-printing
(`labels.html`) and scanner (`scan.html`) surfaces; the codes are ordinary
`tag_code`s, so ADR 0010's permanence and uniqueness rules already cover them.

**Explicitly not.** No purchase-order or procurement integration — claiming a
tag records *what showed up*, never *what was ordered* (the PO wall, ADR 0013,
stays up). Not a bulk asset-import tool.

**Depends on.** Nothing hard. Pairs naturally with the scanner session (the
claim flow is a new branch of the "unknown tag" scan result). Interacts with
the fleet-number convention (item 8): pooled codes stay in the invented
short-code namespace, distinct from stenciled fleet numbers.

## 2. Sightings / last-confirmed-seen

**Motivation.** Incident 1: the ledger says where a thing was *last moved*, but
nobody had *laid eyes on it* in months, so its recorded location was worthless
the moment it was doubted. A "someone actually saw this here, on this day"
fact is different from a move.

**Proposed shape.** Record "asset X confirmed present at location Y at time T"
as an appended observation event, distinct from a movement (a sighting does
not change `current_location` or write to the movements ledger — it only
confirms it). Surface assets whose ledger location has *not* been visually
confirmed in N months, so the staging-yard black hole (goal 2 in CLAUDE.md)
becomes visible before startup instead of at it. The natural capture surface
already half-exists: `scan.html` walk mode audits a location by scanning
everything in it.

**Explicitly not.** No mandatory audit cycles, no nag workflow, no
"you must re-confirm every 30 days or else" in v1 — a sighting is data offered,
not a chore enforced. (Same restraint the inspections module keeps, ADR 0014.)

**Depends on.** Item 6 — a sighting is one `reading_type` on the generalized
readings ledger, not its own collection. Inventory-walk mode (planned Session
4) is the natural capture UI.

## 3. Missing status + passive resolution

**Motivation.** Incident 1: the search was an active, human-coordinated APB —
one email, eight walkers, days of negative replies. The system already knew how
to answer "where is X" the instant *anyone* scanned X anywhere; nobody had
asked it to.

**Proposed shape.** Let a person mark an asset **missing**. It then renders
amber on dashboards and asset lists. Any scan of that asset's tag, at any
location, *passively resolves* the search — the scan supplies a location and
timestamp and clears the missing flag, turning a reply-all hunt into "oh,
someone scanned it at the Hwy 12 yard yesterday." The resolution is the scan
that already happens; no separate "found it" step.

**Explicitly not.** No push notifications / alerts in v1 — resolution is
visible on the dashboard, not pushed to anyone's phone. No search-party
assignment or coordination workflow.

**Depends on.** Item 5 — "missing" is one value of the asset-status field, not
a bolt-on boolean. (Optionally item 9 for capturing the negative reports that
accumulate while the flag is still set.)

## 4. Project / charged-to field on assets

**Motivation.** Both incidents. "Bought for project A, physically sitting in
project B's yard" is *two* facts, and TrenchNote models only the physical one.
Incident 1's pump was A-money in a B-conex; Incident 2's timecard is entirely
about which project each asset belongs to versus where it currently sits.

**Proposed shape.** A plain owning-project attribution on the asset — a
select or free-text field (e.g. a job label). It is deliberately *separate*
from the existing derived "current job," which is already computed from the
asset's current location's `job_code` (ADR 0012). Two fields, two meanings:
*whose equipment this is* vs *whose dirt it is standing on*. This enables a
"project A's equipment, wherever it currently sits" view that neither the
location cache nor the movements ledger can express today.

**Explicitly not.** No cost codes, billing rates, or accounting integration.
This is an **attribution label**, not a ledger of money — it says which project
owns the asset, never what that ownership costs or bills. (Reinforced by the
Part C non-goal added to CLAUDE.md, and by ADR 0015 keeping rates out of core.)

**Depends on.** Nothing hard; a single field on `assets`. Feeds item 7's report
(the owning-project column) and sharpens item 2's staleness view.

**Ecosystem note (2026-07-21).** When this field is built, leave room for it to
carry a *stable project reference* compatible with the sibling `project_ref`
contract sketched in [ecosystem-contracts.md](ecosystem-contracts.md) — not only
a human job label. TrenchNote has no project entity today (an open issue in that
doc); a plain owning-project label is fine for the field itself, but shaping it
with a stable id in mind avoids a painful cross-product retrofit later.

## 5. Asset status beside location

**Motivation.** Incident 2: an asset's *state* — "on hold; not in use",
"down for repair" — survives today only as a margin note in an Excel cell,
invisible to everyone who is not looking at that spreadsheet that week.
Location answers "where," but the timecard also needs "and is it even working."
The 2020 timecards (evidence addendum) make the vocabulary concrete: the weekly
cells already carry a working taxonomy — `X` (worked), `IDLE`, `STORED`,
`BROKE DOWN`, plus "AWAITING REPAIR" comments. Crews have been recording asset
state by hand for years; there is a field-validated set of values to model.

**Proposed shape.** A first-class asset status field, its values informed by
that field taxonomy — e.g. `active` / `idle` / `stored` / `down_for_repair` /
`missing` (in-service the default) — rendered next to location everywhere an
asset appears, replacing the margin note with structured state. Crucially this
records **operational STATE, not usage-for-billing**: `idle` says a machine is
sitting, not what (if anything) sitting bills at. Whether `IDLE` bills
differently from `X` is the Equipment Division's call in *their* process, never
TrenchNote's (the billing non-goal in [CLAUDE.md](../CLAUDE.md)). **Missing
(item 3) is one value of this field**, not a parallel mechanism.

**Explicitly not.** No maintenance scheduling, work orders, or repair tracking
— `down_for_repair` is a *label a human sets and clears*, not the front end of
a maintenance module (ADR 0019 keeps work-order management out; condition
reports there record damage evidence, this records operational state — keep the
two distinct at design time).

**Depends on.** Nothing hard; a field on `assets` plus render changes.
Underpins items 3 and 9.

## 6. Readings as append-only observation events

**Motivation.** Incident 2: month-end hour-meter and odometer readings are
transcribed by hand into the timecard for billing. Incident 1: "I saw it here
today" wants to be recorded, not emailed. Both are the same shape — *an
observation about an asset at a point in time* — and TrenchNote already models
exactly this shape for meters. The 2020 timecards (evidence addendum) show why
this matters *and* why it needs a guardrail: they contain real transcription
errors that sailed into billing inputs unchecked — one hour meter recorded as
3,248 one month and 32,609 the next, another as 7,708 then 78,929. Those are
fat-fingered digits (a machine cannot accrue tens of thousands of hours in a
month), and nothing caught them before they became billing math.

**Proposed shape.** Generalize the **existing** `readings` ledger (ADR 0012 —
`asset`, `value`, `reading_type`, `recorded_by`, `photo`, append-only) so
`reading_type` also admits `sighting`, with `value` optional (a sighting has a
place and a time, not a number). One schema shape then covers both month-end
meter capture *and* item 2's sightings, as observation events appended to an
asset — never mutations, exactly like the movements ledger. The generalization,
not a new collection, is the whole point: the pattern is already proven here.

Because readings are append-only *per asset*, cheap validation is possible at
entry — the previous reading is right there to compare against. A meter reading
that is **lower** than its predecessor, or a **delta beyond a plausible bound**
(e.g. > 750 hours or a large odometer jump in one month), gets **flagged for
confirmation before saving** — the same confirm-guard pattern as the bulk
negative-stock guard. This is a **confirm, never a block**: a genuinely lower
number is real (replaced meter, or the typo the confirm just caught), so the
save still goes through once the human okays it — consistent with the shipped
rule that a lower reading is accepted and flagged at render, never rejected
(see the `readings` notes in [CLAUDE.md](../CLAUDE.md)). The point is to make a
fat-fingered `32,609` announce itself at the keyboard, not three weeks later on
an invoice.

**Explicitly not.** No automated meter ingestion — no telematics feeds, no
vendor APIs pushing hours (that would breach the no-integrations wall). Readings
stay human-entered, like `moved_by`.

**Depends on.** Nothing hard — it extends a shipped collection. **Blocks** items
2 and 9. Note the migration must preserve every existing `hours`/`odometer`
record unchanged.

## 7. Monthly equipment report export

**Motivation.** Incident 2 in full: the weekly timecard *is* a movements ledger
plus meter readings, maintained by hand by six PMs every Friday, because no
system produced it for them. TrenchNote already holds the raw material — moves
(where, when, who) and readings (hours/odometer) — as source-of-truth data.
The 2020 timecards (evidence addendum) sharpen the case two ways. First, the
same corporate form is used in **two dialects** — one records the JOB per week,
the other the USAGE STATE per week (`X`/`IDLE`/`STORED`/`BROKE DOWN`) — so a
generated report must be honest about which columns it can fill. Second, the
observed **decay**: in one month's file week 1 is filled and weeks 2–4 are
blank — the Friday manual ritual dying mid-month. That specific failure is
exactly what a ledger-DERIVED report does not have, because it is computed from
what actually moved, not from whether someone remembered to type on Friday.

**Proposed shape.** Generate the timecard's content — per asset, per week, the
job location it sat at, with arrival/removal dates and the latest meter reading
— as a **derived query** over the movements ledger + readings, exported as CSV
for the existing process to consume. TrenchNote records reality; this is a
*report about reality*, computed, never hand-kept. (The dashboard's inspection
CSV export in `index.html` is the pattern to follow.) The export fills **only
what the ledger knows** — presence, location, arrival/removal dates, latest
meter readings — and leaves the USAGE cells (`X` vs `IDLE`) for the PM to mark.
TrenchNote does not track usage and must not infer it; a readings delta can at
most *hint* whether a machine ran, and the report should not pretend otherwise.

**Explicitly not.** TrenchNote must **never become the billing system.** The
export *feeds* the Equipment Division's existing billing process; it does not
compute charges, apply rates, or do fractional-cost job-splits — accounting
still owns billing and does the split from this data. It also does not fabricate
the usage column: presence is derived, but *usage* (`X`/`IDLE`) stays a human
mark, never a guess from meter deltas. This boundary is now also
a first-class non-goal in [CLAUDE.md](../CLAUDE.md) (Part C: "No equipment
billing or rate calculation") and echoes ADR 0015 (rates stay in the premium
sidecar).

**Depends on.** Item 6 (latest reading per asset) and item 4 (the owning-project
column) make the report complete, but a first cut can derive columns from the
movements ledger alone.

## 8. Company fleet numbers as tag codes — **ADOPTED**

**Status: adopted as a live deployment convention** — not a future item. This
entry stays as the war-story record; the operative rule lives in
[CLAUDE.md](../CLAUDE.md)'s conventions section.

**Motivation.** Incident 2: every owned asset already carries a stenciled
company number the crews *speak* — `P-138`, `FL-16`, `SC-50`, `MISC-37`. These
numbers are painted on the equipment and have been for years. Inventing a
second TrenchNote-only ID (the `A001` style) to sit beside them would fight a
decade of stenciled paint and force crews to learn a parallel vocabulary for
things they already have names for.

**Decision.** For fleet equipment that already carries a company asset number,
`tag_code` **is that number, verbatim** (uppercase, as stenciled). Invented
short codes (`A001` style) remain the convention only for untagged small tools
and for the future unassigned-tag pools (item 1). The `tag_code` field, its
unique index, and ADR 0010's permanence rules already accommodate these
formats with no schema change; verification (an earlier session) confirmed
hyphens, mixed length, and trailing letters all store and scan fine, and set
the uppercase-entry rule to match how lookups compare. See the conventions
section of CLAUDE.md for the operative text.

**Normalization (extended from the 2020 timecards).** The evidence addendum
turned up three real-world failure modes that the convention now guards
against, documented operatively in CLAUDE.md/AGENTS.md:
- *Inconsistent casing in the wild* — the same file writes "Misc-62" and
  "MISC-53". Already handled: the unique index is case-insensitive (migration
  `1783468825`, `COLLATE NOCASE`) and `asset.html`/`scan.html` uppercase a
  scanned or typed code before the `=` lookup.
- *Stray whitespace* — "T-19O B" also shows internal spaces creep in. Now
  handled on the scan/lookup path: `scan.html`'s `parseTag` strips **all**
  whitespace (as well as uppercasing) before the lookup (VERSION `v20`). Entry-
  side stripping still waits on a future frontend create/claim flow — asset
  creation is admin-UI-only today.
- *`O`/`0` and `I`/`1` lookalikes* — one timecard reads "T-19O B", a letter `O`
  typed for a zero **in a billing document**. The convention now says: at
  asset-creation / claim time, a tag code containing an ambiguous `O`/`0` or
  `I`/`1` should be **flagged for confirmation** (not blocked). This stays
  forward-looking — a scan resolves an *existing* code, so the guard belongs to
  the future claim flow (item 1) or any future frontend create, not `parseTag`.

These are also standing evidence for **scan-over-type**: a QR scan cannot typo
an asset ID, so every one of these failure modes is one the scanner (`scan.html`)
sidesteps entirely.

**Explicitly not.** TrenchNote does not *import* or *sync* the company fleet
registry — a PM types the existing number in as the tag code once, at
cataloging. No fleet-system integration.

**Depends on.** Nothing — adopted now, as the first production assets are being
cataloged.

## 9. Negative-report capture

**Status: maybe — flagged as possibly YAGNI.**

**Motivation.** Incident 1: while the pump was missing, "looked for it at the
Hwy 12 yard, not there" was said eight times over email. Each negative report
is genuine data — it narrows the search — but it evaporated into a thread.

**Proposed shape.** While an asset is flagged missing (item 3), let a walker
record "looked for X at location Y, not found" as a lightweight negative
observation, so the search state is visible in TrenchNote instead of an inbox.
Probably a thin layer over items 2 and 6 (a sighting event with a "not found"
result) plus item 3's missing flag — not its own anything.

**Explicitly not.** Not a search-coordination or assignment system. If it can't
be a thin read/write over existing sightings + missing status, it is not worth
building — capturing negatives is lower value than surfacing the one positive
scan that ends the search (item 3).

**Depends on.** Items 2 and 3 (and therefore 6). Deliberately last; build only
if the sighting + missing machinery makes it nearly free.

---

> Items 10–12 came from a roadmap-maintenance ideation pass (2026-07-21), not
> from a July 2026 field incident. They are shaped and boundary-walled the same
> way, but their motivation is the product goals in [CLAUDE.md](../CLAUDE.md),
> not a specific war story.

## 10. Full ledger data export

**Motivation.** The AGPL self-hoster ethos and open-core trust: a user should be
able to get **all** their data out, not just the inspection CSV that ships today.
It is also the honest boundary — any authenticated API client can already pull
every record, so a built-in export is pure convenience and stays firmly free
("the ledger is free; insight about the ledger is paid," ADR 0011).

**Proposed shape.** A client-generated export of the core ledgers — movements,
assets, readings, locations, items — as CSV (a zip of per-collection CSVs is
fine), following the pattern of the existing inspection CSV export in
`index.html`. Read-only. **Must paginate** (the REST API caps list calls at 500;
current-state.md's "Known limitations" flags views that don't page).

**Explicitly not.** Not a backup/restore tool — that is operator territory
(Litestream + a file copy, ADR 0006), not a browser button. Not analysis or
reporting — computed insight is the premium sidecar (ADR 0011). Raw rows out, no
derived numbers.

**Depends on.** Nothing hard; the inspection CSV export is the pattern to copy.

## 11. Stale bulk-material surfacing

**Motivation.** Goal 2 (the staging-yard black hole) for the **bulk** world.
Item 2 (sightings) attacks stale *asset* locations; nothing surfaces bulk stock
that has sat untouched in a yard for months and may have quietly walked off
before startup — the exact black hole, one aisle over.

**Proposed shape.** A derived view — item + location whose most recent movement
is older than N months — surfaced on the dashboard or `material.html`. Pure
derivation over the movements ledger (the same in-minus-out engine that already
derives stock); nothing stored.

**Explicitly not.** No automated audit cycle or nag (same restraint as
inspections, ADR 0014, and item 2). No reorder or procurement logic (the PO
wall, ADR 0013).

**Depends on.** Nothing hard; it is a query. Complements item 2 so both the
unique and the bulk halves of the black hole are visible.

## 12. Rental off-rent-due flag

**Motivation.** Goal 3 (rented equipment). ADR 0015 put `on_rent_date` /
`off_rent_date` in core and `asset.html` already *shows* the off-rent date — but
a rented lift sitting idle past its off-rent date is burned money, and nothing
surfaces it as *attention*.

**Proposed shape.** Render a rented asset amber/red when its `off_rent_date` is
near or past — the same passive, human-cleared pattern `asset.html` already uses
to flag an overdue reservation red. The dashboard could list rentals due back
soon. ADR 0015 explicitly names "flag overdue rentals in core itself" as future
core scope.

**Explicitly not.** No burn-cost or rate math — that needs rates, which stay in
the premium sidecar (ADR 0015 / ADR 0011). This flags a **date**, never a
dollar. No vendor integration (ownership stays manual).

**Depends on.** Nothing hard; the date fields exist (migration `1783468816`).
A date comparison plus a render change.

---

> Item 13 traces to the 2020 timecard evidence addendum at the top of this
> file, not to a July 2026 incident or the 2026-07-21 ideation pass.

## 13. Attachments / travels-with relationships

**Motivation.** The 2020 timecards model attachments as **unnumbered child rows
indented under a parent asset** — an excavator followed by its 60"/48"/36"/30"
buckets and a compaction wheel; a loader followed by its forks; a skidsteer
followed by its sweeper. None of these carry fleet numbers. They are exactly the
high-value, swappable, unlabeled items that walk off — a ripper shank is a
four-figure item with no ID — and the spreadsheet's only model for them is
visual indentation under the parent. When the parent moves, the attachments are
assumed to go with it; when one gets swapped onto another machine, nothing
records it.

**Proposed shape.** A lightweight parent link on assets — "travels with X".
Moving the parent **offers** to move its linked children in the same action;
children can be **detached** and moved independently; and children can be
**individually tagged** (giving the bucket its own `tag_code` — the very
no-number problem the spreadsheet cannot solve). The default coupling is a
convenience, not a cage: the link makes the common case (bucket rides with the
excavator) one tap, without pretending the attachment is welded on.

**Explicitly not.** No kit/BOM management, no quantity-per-kit, no attachment
compatibility rules — a child is one asset with a parent pointer, not a bill of
materials. And deliberately **distinct from the Gang Box membership model**
(ADR 0021): a gang box is container-and-contents for a tool box (contained
assets clear their `current_location` and *cannot* move independently), whereas
an attachment is parent-and-machine where the child *can* detach and move on its
own. Keep the two mechanisms from bleeding into each other at design time.

**Depends on.** Nothing hard — a single self-relation on `assets`. Interacts
nicely with item 1 (unassigned tag pools): unnumbered attachments are prime
claim-a-tag candidates, the fastest path from "indented spreadsheet row" to
"scannable thing."
