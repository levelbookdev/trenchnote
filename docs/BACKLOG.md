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

> **Evidence addendum — historical job records (added 2026-10-11).** A review of
> a general contractor's past job records, spanning about fifteen years and
> several water and wastewater jobs, turned up equipment and materials paperwork
> from before any of this existed. Corroborating evidence, not a new incident.
> What it adds:
>
> - **Rental trackers kept by hand on a live job.** A shoring tracker records,
>   per item, the system it belongs to, quantity, ordered, delivered, rental
>   start, *called out* (the off-rent call made) and *picked up* (the vendor
>   actually collected it). An off-rent table records category, item, vendor,
>   current use and location, **off-rent trigger**, target call-off date, action
>   and status. The triggers are construction events, not dates ("after slide
>   gate is grouted", "after recirculation loop complete", "after startup
>   complete"), and the target dates that were filled in read `TBD` or `ASAP`.
>   One rented item had
>   been on rent for over two years with its vendor recorded as unknown. Enriches
>   item 12.
> - **A third dialect of the equipment timecard.** Monthly per-job equipment
>   lists ran for eight years: job, item number, description, model, an `X` per
>   week across four months, notes, prior hours and current hours. Each PM got
>   the list and sent it back. At least one "returned" file is byte-identical to
>   the one sent: no update made, the same decay the 2020 timecards show.
>   Enriches item 7.
> - **Spare parts handed over under signature.** A spare-parts storage and
>   transfer record carries a custody-transfer sentence and three signatures;
>   about fifteen were signed over to the owner in six months at one job's
>   closeout. TrenchNote has no item for a handover to a party outside the
>   ledger. The nearest shipped shapes are consumption (ADR 0005) and the
>   receive-confirmed manifest (ADR 0020), and neither is quite it.
> - **Permanent equipment tracked by tag while it waits.** An equipment status
>   log carries tag, manufacturer, rep, submittal number, status, lead time,
>   release, delivery and **storage location**. The procurement half stays
>   outside the PO wall (ADR 0013); delivery and storage location are
>   TrenchNote's facts, and this is goal 2's staging yard in spreadsheet form.
> - **Material release and laydown standards.** Numbered material releases to
>   suppliers, tied to submittal approval with a two-week follow-up, and an
>   older internal standard that tied material ordering, laydown location and
>   invoice coding together. Only the receiving and location halves are
>   TrenchNote's; ordering and invoice coding are the accounting department's
>   spreadsheet (ADR 0013, and the billing non-goal in CLAUDE.md).

> **Evidence addendum — an equipment department's records (added 2026-10-19).**
> The same kind of contractor's equipment department files (live to 2026), its
> 2015 equipment manual, and its parent company's warehouse procedures.
> Corroborating evidence, not a new incident. What it adds:
>
> - **The receiving end of incident 2.** About 1,000 weekly and monthly cards
>   over 46 months, each re-keyed by hand into the accounting system's
>   equipment module and moved to an `Approved` folder, tracked on a
>   job-by-month grid of "received, not input" against "completed". One month
>   held 21 cards in about ten naming schemes and three file formats; a 2025
>   card still used the 2014 revision of a form revised in 2018, which lacks the
>   job-charged and idle columns. One truck was charged to three jobs in three
>   days. Enriches item 7.
> - **The location of record is a monthly cell.** A 2025 master list keeps one
>   location per asset per month for 390 assets. Of 3,220 filled cells, 44 read
>   `???`, 76 `N/A` and 84 `SOLD`: an explicit unknown state, and disposal kept
>   in the location column. 48 assets are located by a person, not a site. When
>   a card does not arrive, billing falls back to this list, so a stale entry is
>   billed as truth. Enriches items 2 and 5.
> - **The 2015 manual states incident 1 as policy.** It forbids buying
>   equipment for a job and "sequestering" it outside the master inventory, and
>   its acquisition checklist tags a new asset only *after* delivering it to the
>   user. It also requires a yearly physical confirmation of every asset's
>   location, makes "Idle" an approved status that releases the asset to other
>   projects, and logs a non-binding expected move-off date when an asset is
>   requested. Enriches items 1, 2, 5 and 12.
> - **Disposal is a final location.** The manual records disposal as a transfer
>   to Sold, Destroyed, Junked, Lost or Stolen, with the record kept forever as
>   inactive; a separate checklist lists six disposal methods. TrenchNote has no
>   retirement event, and no item here proposes one yet.
> - **Four classes of thing.** The parent company's warehouse procedures sort
>   everything into equipment (individually numbered), quantity equipment ("one
>   equipment number for all items of that same description": forms, shoring,
>   crane mats, counted back on return), small tools, and consumables (charged
>   at order, not expected back). Unreturned tools and quantity equipment are
>   charged at replacement value, returns are counted as they are unloaded, and
>   a move between projects needs a signed transfer request. A per-item class
>   that decides unit-or-count identity and whether a return is owed bears on
>   [open question 7](open-questions.md) and on whether equipment and materials
>   are one catalog.
> - **Custody can sit with a person.** In records from 2015 and 2025, vehicles
>   and some containers are held by a named person rather than a site or job.
>   Whether a person can be a holder, given that field users have no accounts,
>   is open.
> - **Receipt and installation merged.** A plant job's embed log (37 marked wall
>   pipes and sleeves) keeps one "check in" column: mostly a date and initials,
>   twice the word "Installed". Two movements, a receive and a consume (ADRs 0013
>   and 0005), recorded as one fact.
> - **An inspection owed only on working days.** A daily crane inspection log
>   owes a pre-trip check only on days the crane works; idle days are struck
>   through. ADR 0014's calendar `interval_days` would show such a requirement
>   overdue on every idle day. A design question, not a change.
> - **A calibration clock that stops on the shelf.** The parent company's
>   calibration procedure stops the clock while an instrument sits in its
>   warehouse ("shelf time not included"): it is calibrated when it comes back
>   from a project and gets a new sticker, with the issue date and a new due
>   date, when it is next issued. A due date computed from the last calibration
>   plus an interval would show every shelved instrument overdue; for this class
>   the due date of record is the sticker's, set at issue. With the crane log,
>   a second requirement whose clock does not run on the calendar (ADR 0014).
> - **Receiving has a disposition, and storage has a level.** The same
>   company's receiving procedure gives every delivery one of four
>   dispositions: inspected and stored; over, short, damaged or incorrect;
>   released straight to the work, with where it went noted; or held for
>   inspection, hold-tagged and segregated so it cannot be installed. Storage is
>   rated A to D, from indoor and climate-controlled to a designated, drained
>   outdoor yard on cribbing. The receiving report records the storage location,
>   time in and out, condition checks and the documents that came with the
>   shipment. ADR 0013 records what arrived and its condition, not whether a
>   delivery is on hold, stored, or already gone into the work; a hold would be
>   an event and a later release another, the state derived. The storage level
>   is a property of the location.
> - **The freight bill decides the damage claim.** Its over-short-damaged-
>   incorrect report keeps the four cases apart, records which document
>   comparison found each (packing slip against PO, freight bill against
>   packing slip, freight bill against count), and asks whether the carrier's
>   agent signed a damage notation on the freight bill. That signature wins the
>   claim. A reason to prompt for a photo of the signed freight bill beside the
>   packing slip, not to model the report; ADR 0013's `osd_note` stays free text.
> - **A mark is a count, not a unit.** The contractor's 2017 house templates
>   for valve and pipe-support logs end in release date, expected delivery,
>   backorder, actual delivery date, packing slip and storage location. Valves
>   are identified by valve number; pipe supports by a design mark carrying a
>   quantity and a revised quantity. The delivery and location tail is
>   TrenchNote's (ADR 0013) and the release and backorder half is procurement.
>   A mark counted against a design quantity is the permanent-materials
>   counterpart of "quantity equipment".
> - **Call-off numbers are old, and stop dates decay into words.** A rental
>   ledger from 2002 to 2007 (419 rentals) has a call-off number column, filled
>   on 116 rows. Of its filled "rental stop" cells, about 121 hold a word
>   instead of a date: "off rent" (74), "renting", "cancelled", "stopped".
>   A separate sheet counts idle days. Enriches items 5 and 12.

> **Evidence addendum — the equipment system's launch papers and pre-use forms
> (added 2026-10-21).** The rest of the 2015 equipment manual's folder from the
> 10-19 read: the launch deck and memo, the procedure for running equipment in
> the accounting system, the timecard instructions, a 2016 chart of the
> company's lists of record, the parent company's equipment, maintenance and
> vehicle procedures, a 2024 check-out form, and the safety department's blank
> pre-use checklists. Corroborating evidence, not a new incident. What it adds:
>
> - **The launch deck asks TrenchNote's questions.** "What do we own? What are
>   the details? Where is it? When did it get there? When do we expect it to be
>   available?" Its "what this isn't" list (cost tracking, depreciation,
>   maintenance, hourly billing) ends every line with "(yet)". The non-goals in
>   [CLAUDE.md](../CLAUDE.md) carry no "yet".
> - **At launch, one item in six had no known location.** The launch memo
>   counts 403 owned items, 64 of them at location "Unknown", and equipment
>   still shown at two jobs that had demobilized. It calls the first inventory,
>   from the equipment staff's own records, a bad example, and the second, a
>   walk of each site by its PM, "better but lots of errors". The 2025 `???`
>   cells above are the same gap ten years on. Enriches items 2 and 3.
> - **Location is corrected upstream of billing, never inside it.** A wrong job
>   on the month's billing batch cannot be fixed in the batch: the batch is
>   cleared, the transfer record corrected, and the batch run again. Rate and
>   idle overrides are made in the batch; location is not. That is item 7's
>   line: TrenchNote says where things were, and accounting decides what that
>   costs.
> - **A new asset's first location is a transfer.** The procedure enters every
>   new asset at the home shop and then records a transfer to its first job, so
>   its location history starts with an arrival. Each transfer carries an in
>   date and an estimated out date, and a mass transfer moves several assets
>   between the same two places in one entry. An asset created in TrenchNote's
>   admin UI with `current_location` already set has no arrival in the ledger.
> - **The timecard asks for a reading on the way out.** Hour-meter and odometer
>   readings are due at month end and again when an item leaves a site, with
>   the move-off date. That is ADR 0012's optional reading at a move, already
>   shipped. The "date first on site" and "date moved off site" columns are the
>   day the move happened, not the day it was keyed: ADR 0023's `moved_at`.
> - **What earns a number.** Tracked equipment is owned heavy equipment,
>   vehicles and trailers, anything needing a state registration, construction
>   equipment above a value line with more than a year of life, anything
>   capitalized, and anything else the equipment manager chooses. Equipment
>   bought on a job's own budget is still entered, and billed at nothing. The
>   asset number is assigned in the office once a purchase is imminent; the
>   physical tag goes on after delivery, so for a while the number exists and
>   nothing carries it. A small pump like incident 1's likely falls below the
>   value line and is left to the catch-all. Enriches item 1.
> - **The equipment list is one list of record among several.** A 2016 chart
>   names the lists of record: the equipment list, DMV and air-board
>   registration lists, accounting's fixed assets, the auto and inland-marine
>   insurance schedules, the property-tax list, and hardware and software
>   lists. Each has its own keepers, and accounting reconciles across them.
>   Registration, insurance and tax stay outside TrenchNote; what it can offer
>   the others is a location to reconcile against (item 10).
> - **A two-party check-out on paper.** The safety department's 2024 check-out
>   form issues tools to a person: employee number and name, job number,
>   customer, foreman, division and jobsite address, then lines of tool number,
>   description and in/out, signed by whoever issued and whoever received. The
>   return is marked on the same sheet as the issue. TrenchNote's `moved_by` is
>   one free-text name, and custody by a person exists only as `assigned_to`
>   (ADR 0012). Bears on the custody question above.
> - **Out-and-back inspections in the yard.** The parent company's maintenance
>   procedure inspects equipment on a type-specific form before it goes to a
>   project and again on return, noting damage on the return form. Damage found
>   on a project is reported with photos, and the machine is out of service
>   until the equipment manager clears it. That is ADR 0019's `condition_note`
>   at delivery and return and ADR 0014's `removed_from_service`, done by a
>   mechanic in the yard rather than a crew on site.
> - **Pre-use checklists are a daily layer, and stay on paper.** Blank forms for
>   forklifts, a towable generator, scissor and boom lifts, and scaffold mark
>   every item Y/N/N/A or pass/fail at the start of each shift ("no items are to
>   be left blank"), go to a supervisor for approval, and end in a "safe to
>   operate" signature. ADR 0014 records an inspection's result, not its line
>   items, and refuses sign-off chains, so at most TrenchNote holds a result
>   with a photo of the completed sheet. The forklift form has an hour-reading
>   row for every day: the first place a meter is read, upstream of the
>   timecard's month-end reading. The generator form was cloned from the
>   forklift's and still says "forklift" in its fluid checks.
> - **Vehicles are assigned two ways.** The parent company's vehicle policy
>   assigns a vehicle to an employee or to a project, and it goes back to the
>   equipment department when the need ends or the project closes. Mileage-based
>   maintenance relies on the driver reporting the odometer weekly. Custody by a
>   person, and readings reported by the custodian, both as ADR 0012 shaped
>   them.

> **Evidence addendum — the tracker already bought, and other registers (added
> 2026-10-23).** The same contractor's IT department files (its 2018
> tool-tracking evaluation and subscription, and the 2024 build sheet for
> jobsite network kits), its archive-room box register, two exports of its
> equipment master from Vista, the equipment department's per-unit folders,
> and its monthly equipment log. Corroborating evidence, not a new incident.
> What it adds:
>
> - **A tool tracker was bought, at the tier TrenchNote is shaped like.** In
>   2018 IT compared GigaTrak, ToolHound and ToolWatch, plus the tool partners
>   Viewpoint lists for Vista. GigaTrak's quote offered rugged handhelds and
>   Bluetooth scanners, warning that its small round labels "may not be
>   readable with the mobile devices camera". The company bought ToolWatch
>   Essentials, capped at 500 assets: tools and equipment, materials and
>   consumables, pick tickets and transfers, requisitions, verify, dashboards.
>   It turned down the Pro tier, which added service and calibration, job cost
>   and billing, and counts. It renewed at the same tier in 2021, and at the end
>   of 2021 still had users in three roles (admin, tool manager, foreman), each
>   an employee record with a home stock location. Yet the location list of
>   record in 2022 to 2025 was still Vista's export and spreadsheets (the
>   addenda above). ToolWatch's own feature grid gives the back-office tier
>   alone tool kits, retiring tools, service plans, work orders, purchase
>   orders, job cost and billing charges, and invoices. That list is,
>   nearly line for line, the non-goals in [CLAUDE.md](../CLAUDE.md).
> - **The accounting master keeps location in two exclusive columns.** Vista's
>   January 2022 export (390 owned units, 115 columns) gives each unit either a
>   yard or office location or a job, never both: 219 sit on a job, 120 at a
>   yard or the office, 44 at location "Unknown", and 7 have neither. So about
>   one unit in eight had no known place, the same gap as the 2015 launch memo's
>   one in six. One unit in eight names an operator: custody by a person
>   again. The September 2023 list (570 rows) keeps disposal in the location
>   column ("Sold/Gifted to Others" 117, "Junked/Trashed" 36, "Stolen" once),
>   and one location reads `NON-OPP Rocky Mountain Yard`: a status packed
>   into the location's text. Enriches items 2, 5 and 8.
> - **The master stores tag codes fixed-width.** Every equipment code in the
>   2022 export is nine characters, padded inside: `   H-  06`, `  TC- 114`.
>   386 of 390 carry internal spaces. The per-unit folders and the stencils
>   write `H-06`. A code copied out of the master brings its padding along,
>   the likely source of the stray spaces item 8 records. Enriches item 8.
> - **The master separates "attached to" from "component of".** Vista carries
>   both relations on a unit, each with its own description fields. In 2022
>   one unit of 390 used the first (truck crane `TC-114` on truck `T-114`) and none
>   used the second. The accounting vendor draws the same line as item 13
>   against ADR 0021's gang boxes, and the field barely uses either.
> - **Status lives in folder names.** The equipment department keeps 486
>   per-unit folders, one per fleet number, filed under class prefixes. About
>   36 folder names carry a final state, in at least six spellings (`SOLD`,
>   `- SOLD`, `(Sold)`, `Junked`, `total loss`, `NON-OP`), and one reads
>   `(LEASED)`. Enriches item 5 and the disposal point above.
> - **IT built a gang box without ever seeing ADR 0021.** Since 2024 a
>   jobsite network kit is a rolling case of four tagged components. In the IT
>   asset system (Freshservice) the kit is a parent asset whose tag is the
>   patch panel's. Each component carries its own tag and serial, is linked "in
>   rack" to the kit, and has its location set to a placeholder named "Project
>   Kit", so its place comes from the kit. The kit, not its components, is
>   assigned to the PM or superintendent and linked to the job's site-request
>   ticket. The job has to be requested as a location before the kit can sit
>   there; until then the kit's place is written into its network name
>   (`… – In-Stock` renamed to `… – <job> – <name>`). Corroborates ADR 0021
>   (contents derive location from the box, the box moves as one) and bears
>   on the custody question above.
> - **A register with numbers waiting.** The archive room's box register sets
>   aside 5,000 container numbers in sequence. 3,596 are used and 1,404 wait
>   for boxes. Two numbers that were never used are marked "Voided Number" and
>   kept, not reissued. Each box is located by room plus a rack-and-shelf code
>   (`J3`), and a destroyed box stays in the register with a flag. A numbered
>   pool ahead of the things it will name is item 1, kept by hand. The void
>   rule is ADR 0010's. TrenchNote's locations are flat, and whether a shelf
>   inside a room is a location of its own is a question, not a proposal.
> - **Demand comes before the unit.** The monthly equipment log's per-job
>   sheets list equipment by fleet number with dates in and out, and its
>   pipeline sheet lists units planned for jobs not yet started. In the
>   January 2025 log, four rows in two job sheets read `TBD` in the unit column
>   against a kind of machine ("Office Trailer", "Excavator 308 Rubber
>   Tracks"), one with a date required. TrenchNote's reservations name one
>   asset, so a request for "a 308, any 308" has nowhere to go until a unit is
>   picked. A design question, not a change.
> - **Heavy iron already reports its own hours.** An April 2024 dealer quote
>   installs CAT Product Link on 30 "remaining machines in the fleet", and a
>   January 2022 export of the master is named for Tenna, a GPS tracking service. For
>   machines with a device, the hour meter already lives somewhere else. That
>   strengthens item 6's wall (no telematics ingestion): manual readings
>   matter most for what has no device, such as pickups, trailers and small
>   gear.


> **Evidence addendum — late deliveries and the notice question (added
> 2026-10-26).** A review of a general contractor's closed jobs, read for how
> notice was given when something ran late. Corroborating evidence, not a new
> incident. What it adds:
>
> - **The answer was in no one place.** On one job, a purchased conveyor
>   package was due 2023-07-12. The supplier said nothing until 2023-07-19,
>   when it admitted the slip, and the company put it on notice under a
>   purchase-order clause on 2023-07-31: seven days late to learn of it, nineteen
>   days past due before notice went out. On another job, on 2023-07-27,
>   the purchasing office asked how late a supplier was and whether it had been
>   put on notice, and nobody could say. The three dates that answer it
>   (promised delivery, actual receipt, notice to the supplier) lived in
>   different people's email and folders.
> - **A slow chain can look the same.** On a third job, pipe flanges were
>   ordered 2025-01-23, released 2025-02-20 and delivered 2025-05-05: 102 days
>   from order to the dock, with the release step in the middle. Whether that
>   was late depended on a promised date no ledger held.
> - **What the ledger could hold.** TrenchNote already records the third date
>   in part: the receiving log (ADR 0013) stamps when a delivery arrived, with
>   the vendor, the free-text `po_number` and an over/short/damaged note. A
>   promised date and a notice date would sit beside them as facts a human
>   types, the way `po_number` is, which answers "how late, and were they put
>   on notice?" from the record. Items 11 and 12 are the nearest neighbours: one
>   surfaces material that has sat too long, the other a rental past its
>   call-off.
> - **The wall holds.** A promised date typed onto a delivery is not a PO
>   record, and matching it against an order is the received-vs-ordered
>   comparison ADR 0013 rules out. The notice itself (a letter, a clause, an
>   owner's clock) belongs to change management, not here: an owner's notice
>   period is per contract, not per asset. Whether even the typed promised date
>   is worth a field is a question for a design session, not a proposal.
>
> Evidence only. No item added, no schema or code changed, nothing built.

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

**Evidence (2026-10-19 addendum).** A company equipment procedure puts "take
delivery, deliver to user" before "tag the asset", and the manual it belongs to
forbids buying for a job and holding the item outside the master inventory.
Incident 1's gap is written into the procedure, so a policy alone does not
close it; a tag at the point of arrival would.

**Evidence (2026-10-23 addendum).** The same company's archive room already
runs a pool by hand: 5,000 box numbers set aside in sequence, 1,404 still
waiting, and the two never used kept as "Voided Number" rather than reissued.

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

**Evidence (2026-10-19 addendum).** The office's location of record is one
cell per asset per month, and 44 of 3,220 filled cells read `???`. The same
company's manual asks for a physical confirmation of every location once a
year. A sighting is the event that replaces both the monthly guess and the
yearly walk.

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

**Evidence (2026-10-23 addendum).** With no status field, status goes wherever
there is text: into the location (`NON-OPP Rocky Mountain Yard` in the 2023
master) and into folder names (about 36 per-unit folders end in `SOLD`,
`Junked`, `total loss` or `NON-OP`, in at least six spellings).

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

**Evidence (2026-10-11 addendum).** A third dialect of the same ritual: monthly
per-job lists with an `X` per week and prior and current hours, sent to each PM
and returned. One returned file was identical to the one sent. A derived report
cannot come back unchanged, because nobody has to remember to fill it in.

**Evidence (2026-10-19 addendum).** The receiving end: about 1,000 cards over
46 months, each re-keyed into the accounting system and tracked on a
"received, not input / completed" grid, in about ten naming schemes and three
formats in one month, some on a form two revisions old. One truck went to
three jobs in three days, so the export's segments must split within a week
(ADR 0022).

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

**Evidence (2026-10-23 addendum).** The internal spaces have a likely source:
Vista stores every equipment code fixed-width and padded (`   H-  06`; 386 of
390 codes in a 2022 export), while stencils and folders write `H-06`. Collapsing
whitespace on lookup is what makes the two the same tag.

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

**Evidence (2026-10-11 addendum).** Real off-rent tracking keys on a
construction event ("after startup complete"), not a date, and the target
dates that were filled in read `TBD` or `ASAP`. It also separates the call-off from the pickup, which are two
facts a single `off_rent_date` cannot tell apart. Neither changes this item's
shape: the flag still compares a date. They are a reason to keep the human's
trigger visible in a note rather than to model it, and a reason to read
`off_rent_date` as "called off", not "gone". One rental on the same list had
been on rent over two years with no known vendor, the black hole in its
rented form.

**Evidence (2026-10-19 addendum).** A large contractor's rental procedure
stickers each rented unit with a company tracking number, the vendor and the
serial, photographs damage on arrival, and discontinues the rental against a
vendor **release number** that the invoice is later checked against. That
number is the call-off's proof, and the natural thing to record on the
off-rent event, in its note if nowhere else. The practice is old and patchy:
a 2002–2007 rental ledger has the column filled on about a quarter of its
rows, and records 74 stops only as "off rent", a call-off nobody can date.

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

**Evidence (2026-10-23 addendum).** Vista's equipment master already carries
both relations, "attach to" and "component of", as separate fields: the same
line this item draws against ADR 0021. In 2022 one unit of 390 used the first
and none the second, so the relation exists and goes unused. The field needs
the link to cost one tap, not that it be possible.
