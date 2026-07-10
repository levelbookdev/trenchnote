# ADR 0013 — Receiving log: dispute evidence on delivery movements

**Status:** accepted · **Date:** 2026-07-10

## Context

Materials for water/wastewater jobs are delivered 12–18 months before
installation (problem #2 in the project charter: the staging-yard black
hole). When startup arrives and pieces are missing, the vendor dispute is
settled by whoever has evidence. A delivery logged with a timestamped
packing-slip photo and an over/short/damaged note **is** that evidence —
and TrenchNote already has the delivery event: a receive-shaped bulk
movement (`to_location` set, `from_location` empty — ADR 0005).

What was missing: anywhere to put the vendor's name, the PO the delivery
arrived against, a photo of the packing slip, and "received 480 of 500
per slip; 2 crates damaged."

## Decision

### Fields on the movement, not a new collection

Five optional fields on `movements` (migration `1783468815`):
`vendor_name` (text), `po_number` (text), `packing_slip` (file, 1),
`osd_note` (text), `photos` (file, up to 8 — damage close-ups).

A delivery IS a movement; the ledger row is the receiving record. A
separate `deliveries` collection would duplicate the event, need its own
append-only rules, and split "what arrived" from "where it went" — the
exact drift ADR 0002 exists to prevent. The evidence lives on the event
it proves.

The fields are **not** restricted to receive-shaped movements in the
`createRule`. An optional field left empty on a transfer hurts nothing,
and tightening the rule would risk rejecting queued offline moves from
phones running older frontend code (the ADR 0008 queue can replay days
later). The UI only offers the fields in "New delivery" mode.

Because movements are already append-only (update/delete superuser-only),
the slip photo's `created` timestamp is trustworthy — nobody can back-date
or swap evidence without superuser access, which is exactly what a
dispute needs.

### The photo nag: loud, never a wall

The delivery form shows a persistent amber warning while no packing-slip
photo is attached — *"No packing slip photo — this delivery will be hard
to prove later"* — but **submit stays enabled**. A delivery logged
without a photo still beats a delivery not logged; blocking would teach
crews to log deliveries as plain notes, and the evidence habit dies. Same
philosophy as the lower-than-previous meter reading (ADR 0012): flag,
never block.

### The receiving report is core, not premium

`receiving.html` renders deliveries per material or per PO — dates,
quantities, vendor, OS&D notes, photo appendix — print-friendly, so
File > Print produces the PDF that gets attached to the vendor dispute
email.

ADR 0011 draws the line as "the ledger is free, insight about the ledger
is paid." This page is the ledger itself, formatted for paper — a
filtered read of one collection with zero analysis, the dispute-proofing
half of a field workflow (the crew photographs the slip; the PM prints
the report). Cross-site analytics, rental burn math, and scheduled
exports remain premium. A report page that a $5 VPS renders from records
it already serves is not "insight."

### The wall: no purchase orders

`po_number` is a free-text string a human types at the truck. TrenchNote
knows **what arrived**, never **what was ordered** — no PO records, no
line items, no three-way match, no procurement workflow, no vendor
integrations. If a feature needs to compare received against ordered,
the answer is no; that lives in the accounting department's spreadsheet.
Recorded in the non-goals list (CLAUDE.md) alongside the other walls.

## Alternatives rejected

- **A `deliveries` collection** — duplicates the movement event; see above.
- **Required packing-slip photo** — blocks the log at the exact moment
  logging matters most (driver waiting, gloves on, sun on the screen).
  Flag-never-block is already the house pattern.
- **Slip photo on a separate `readings`-style ledger** — readings are
  many-per-asset over time; a slip belongs to exactly one delivery event.
  A relation would add a join to every render for zero modeling gain.
- **Structured OS&D (over/short/damaged as separate numeric fields)** —
  implies the app knows the ordered quantity (it doesn't, on purpose),
  and crews describe damage in words, not schemas. One text field.

## Consequences

- Contract v1 (docs/API.md) gains five optional movement fields —
  additive, no version bump per its own rules.
- The offline queue (ADR 0008) learned to carry files on movement
  entries: `TNSync.enqueue(movement, assetPatch, label, files)`, replayed
  as multipart exactly like reading photos. Old queued entries (no
  `files`) replay unchanged.
- Photos make movements records heavier. Bounded: `maxSelect: 8`, one
  slip, and phones only upload what crews deliberately attach. `pb_data/`
  backups grow with the photo volume — same tradeoff already accepted
  for item photos and gauge photos.
- The dashboard's recently-moved feed and derived stock math are
  untouched — the new fields are invisible to every existing sum and
  filter (regression-tested: plain move, transfer, consume, asset move).
