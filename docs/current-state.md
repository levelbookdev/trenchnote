# TrenchNote current state

**Authority:** Descriptive

**Repository snapshot:** `main`, a few commits past the `v1.0.0` release

**Reviewed:** 2026-07-21 (deployment status re-verified 2026-08-23)

This document records behavior confirmed in this repository. It does not
describe the broader product family except where an implemented integration
already exists. Status words have the following meanings throughout the
architecture documentation:

- **CURRENT** — directly confirmed in committed code or configuration.
- **DECIDED** — an accepted direction, whether or not fully deployed.
- **PROPOSED** — a candidate that still requires review.
- **DEPRECATED** — behavior intended for removal or migration.
- **UNKNOWN** — the repository does not contain enough evidence.

## Product today

**CURRENT:** TrenchNote is a self-hostable field-logistics ledger for physical
equipment and bulk materials. It answers what a thing is, where it is, and who
moved it. It also records supporting field facts that belong at that same scan
point: reservations, meter readings, receiving evidence, asset inspection
observations, and photographed condition evidence.

The application is usable as a standalone system. No paid service or sibling
application is required for field execution, data retention, or the exports
that exist today.

## Current stack

| Layer | CURRENT implementation | Repository evidence |
| --- | --- | --- |
| Application server | PocketBase `0.39.6` is the locally installed and documented tested version | `pocketbase.exe`; `docs/API.md` |
| Persistence | PocketBase collections backed by one embedded SQLite database | `pb_migrations/` |
| Server extension | One PocketBase JavaScript hook for best-effort off-site email | `pb_hooks/main.pb.js` |
| Frontend | Static HTML/CSS with inline page logic and Alpine.js | `pb_public/*.html` |
| Offline storage | Cache Storage for shell/API reads; IndexedDB for queued writes | `pb_public/sw.js`; `pb_public/tn-sync.js` |
| QR support | Native phone camera URLs, browser `BarcodeDetector`, and lazy local `jsQR` fallback | `pb_public/scan.html` |
| Runtime dependencies | Alpine.js and QR libraries vendored locally; no runtime CDN | `pb_public/vendor/` |
| Build process | None; committed files in `pb_public/` are served directly | `docs/DEVELOPER_GUIDE.md` |

`scripts/setup.sh` can download PocketBase for a supported OS and architecture.
Its default is the latest upstream release; operators who need the documented
tested version must set `PB_VERSION=0.39.6`.

## Current entry points

| Page | CURRENT purpose |
| --- | --- |
| `pb_public/index.html` | Authenticated dashboard: assets by location, bulk totals, reservations, inspection attention list, recent movements, and inspection CSV export |
| `pb_public/asset.html?code={tag_code}` | QR landing page for one asset: identity, location, movement history, reservations, readings, inspections, and moves |
| `pb_public/material.html?id={item_id}` | Bulk stock by location, delivery/transfer/consume entry, and delivery evidence |
| `pb_public/receiving.html` | Print-friendly receiving report filtered by material or typed PO reference |
| `pb_public/labels.html` | Printable asset QR labels with a caller-selected base URL |
| `pb_public/scan.html` | Single QR scan and location walk/audit mode |
| `pb_public/login.html` | PocketBase password authentication and local token storage |
| `/_/` | PocketBase superuser administration UI |
| `/api/collections/*` | PocketBase REST API; the documented public contract is `docs/API.md` |

PocketBase serves the frontend and API from the same origin. Frontend code uses
`window.location.origin`; only a printed QR label embeds a deployment address.

## Current collections

The complete schema is reproducible from the ordered migrations in
`pb_migrations/`. There are fourteen application collections.

| Collection | CURRENT purpose | Authority and mutability |
| --- | --- | --- |
| `items` | Catalog entry describing a kind of unique or bulk thing | Mutable catalog data; authenticated create/update; superuser-only delete |
| `locations` | Jobsite, yard, warehouse, or transit location | Mutable reference data; authenticated create/update; superuser-only delete |
| `assets` | One physical instance of a uniquely tracked item | Mutable master data and location cache; authenticated create/update; superuser-only delete |
| `movements` | Asset moves and bulk receipts, transfers, or consumptions | Authoritative ledger; create-only for authenticated users; superusers retain administrative access |
| `reservations` | Human claim on an asset with open/fulfilled/cancelled lifecycle | Mutable workflow record; closed records remain stored |
| `readings` | Meter or odometer observation for one asset | Authoritative ledger; create-only for authenticated users; superusers retain administrative access |
| `inspection_requirements` | Recurring obligation attached to one asset | Mutable catalog-like data; authenticated create/update; superuser-only delete |
| `inspections` | Pass, fail, or removed-from-service observation | Authoritative ledger; create-only for authenticated users; superusers retain administrative access |
| `condition_reports` | Photographed damage, wear, or condition observation | Authoritative ledger; create-only for authenticated users; superusers retain administrative access |
| `condition_resolutions` | Human-stated outcome for a condition report | Authoritative ledger; create-only for authenticated users; superusers retain administrative access |
| `manifests` | Two-site truckload handshake with forward-only status | Mutable only through authenticated forward workflow transitions |
| `manifest_lines` | Sent asset/bulk facts plus receiving quantity/note | Draft lines editable/removable; sent shape freezes at dispatch; receipt fields update in transit |
| `container_events` | Gang Box membership add/remove fact | Authoritative ledger; create-only for authenticated users |
| `kit_audits` | Dated Gang Box contents checklist | Authoritative ledger; create-only for authenticated users |

The server enforces the asset-versus-bulk movement shape and requires an
inspection requirement, when supplied, to belong to the inspected asset.

## Authoritative facts and derived state

**CURRENT authoritative facts:**

- A `movements` record is the authoritative statement that an asset or bulk
  quantity moved. Corrections are additional movement records. Its `moved_at`
  is the observation date when supplied (client-set, date-only UTC midnight);
  `created` remains entry time, and derivations sort `-moved_at,-created`.
- A `readings` record is the authoritative meter observation. Its `read_at`
  is the observation date when supplied; `created` remains entry time.
- An `inspections` record is the authoritative inspection observation.
  `inspected_at` is client-set so offline and back-entered records retain the
  field date; `created` records when the server received it.
- A `condition_reports` record is a photographed field observation, and a
  `condition_resolutions` record is a later outcome. Both retain their original
  rows and use server entry time.
- Receiving photos, packing slips, vendor text, and OS&D notes are evidence on
  the receive-shaped movement itself, not a separate delivery record.
- A manifest and its lines are the authoritative sender/receiver observations;
  the resulting movements remain authoritative for inventory.

**CURRENT derived or cached answers:**

- `assets.current_location` is a convenience cache. Clients write the
  movement first and patch the cache second.
- Bulk stock per location is movements in minus movements out.
- Dashboard bulk total is external receipts minus consumptions.
- Current job is the current location's `job_code`.
- Latest meter reading is selected by observation date, then entry time.
- Inspection status and next-due date are derived by `pb_public/tn-inspect.js`.
- Damage standing is damage reports minus reports referenced by any condition
  resolution; no damaged/open flag is stored.
- Reservation status is not derived; a person explicitly fulfills or cancels
  the claim.
- In-transit standing is derived from manifest status; dispatch does not create
  a movement or virtual location.

No executed-record signature, frozen snapshot, evidence hash, correction link,
or general record-locking mechanism exists in TrenchNote today.

## Current user workflows

**CURRENT:**

1. An administrator creates users, locations, items, assets, and optional
   inspection requirements in PocketBase or through the authenticated API.
2. A manager prints asset labels. Each QR contains
   `{baseUrl}/asset.html?code={tag_code}` and prints the tag code underneath.
3. A field user signs in once on a phone, scans a label, reviews last-known
   identity/location/status, and records a move.
4. A location walk scans successive labels, compares their cached location to
   the selected physical location, and offers a correcting movement.
5. A user opens a bulk item to receive, transfer, or consume a quantity.
   Delivery mode optionally captures vendor, typed PO reference, packing slip,
   OS&D note, and supporting photos.
6. A user can reserve an asset and later fulfill or cancel the reservation.
7. Metered assets can receive hour/odometer observations with an optional
   gauge photo.
8. Assets with inspection requirements display a derived attention badge and
   accept inspection observations. The module records visibility; it does not
   assign, approve, escalate, or certify a safety program.
9. A sender builds and dispatches a mixed transfer manifest; a receiving user
   confirms every line in one transaction, with shortfalls held at
   `Missing in transfer`.

## Current offline behavior

**CURRENT:** `pb_public/sw.js` precaches the application shell under an explicit
`VERSION`. Shell requests are cache-first. API GET requests are network-first
and fall back to responses stamped with `X-TN-Cached-At`; the UI displays the
staleness rather than presenting cached data as live.

`pb_public/tn-sync.js` queues the following writes in IndexedDB when a network
request fails:

- movements, including an optional follow-up asset-location cache patch;
- meter readings and their optional photo;
- inspections and their optional photo;
- delivery movements with packing-slip and damage-photo blobs; and
- manifest dispatch/receipt batches with a local render snapshot.

Each queued ledger record carries a pre-generated PocketBase ID so replay is
idempotent. Replay is FIFO and pauses visibly on authentication or validation
failure. Reservations and inspection-requirement edits are not queued for
offline replay.

Offline operation is not multi-instance synchronization. The device queues
writes for one authoritative PocketBase instance.

## Current exports and integrations

**CURRENT exports:**

- client-generated CSV of the inspection ledger;
- browser-printable receiving reports, including evidence images;
- browser-printable transfer manifests;
- browser-printable QR label sheets; and
- authenticated reads through PocketBase REST API contract v1.

PocketBase realtime subscriptions are part of the documented API surface, but
the core UI does not use them as an ecosystem event bus. There is no versioned
**cross-product** handoff manifest, project export, lifecycle-event envelope, or import
provenance record.

**CURRENT external side effect:** after a committed movement transfers
something between two different locations, `pb_hooks/main.pb.js` attempts to
email the origin location's `notify_email`. Missing SMTP or mail failure is
logged and never rolls back the movement.

## Current authentication and authorization

**CURRENT:** all application collection reads and writes require an
authenticated PocketBase user. Public self-registration is disabled. The
operating model is a shared field account per crew/device context and personal
accounts for managers; accounts are created by a superuser.

`pb_public/tn-auth.js` stores the token in local storage, attaches it to API
requests, and calls `auth-refresh` on page load. This refresh is also the
expiry check because PocketBase may return an empty `200` list to a guest
instead of `401`.

The movement, reading, inspection, condition-report, and condition-resolution
collections are append-only for normal authenticated clients. PocketBase
superusers are outside collection API rules, so current immutability is an
operational and client-level guarantee, not a cryptographic or absolute
database guarantee.

## Current deployment topology and status

**DECIDED reference topology:** one writable PocketBase instance on a VPS,
bound to localhost and exposed through Caddy HTTPS. An optional trailer/office
Pi receives Litestream replication of SQLite plus a separate file copy of
uploaded storage. The Pi is a replica and staging target, never a writable peer.
LAN-only, private-mesh, and fully standalone installations are also
supported. The private-mesh shape (`docs/DEPLOY.md` Option C) keeps the
localhost binding and terminates TLS at `tailscale serve` rather than Caddy,
which preserves the secure context `pb_public/sw.js` requires; it is
documented as a staging and small-team shape, not a crew-facing one, because
it requires a mesh client on every device.

Repository configuration for that topology lives in `deploy/`; operator
instructions live in `docs/DEPLOY.md`, `deploy/README.md`, and
`docs/RUNBOOK.md`.

**CURRENT deployment, verified 2026-10-10: one tailnet-only instance on the
maintainer's homelab, running pre-`v1.0.0` code. There is no public
deployment.**

- `https://trenchnote.com` still serves the public project site from GitHub
  Pages (`docs/` plus `docs/CNAME`). It is a static marketing and
  documentation site, not the app.
- `app.trenchnote.com` no longer resolves. The DigitalOcean droplet behind it
  (`trenchnote-db1`) was retired the way the homelab repo records it
  (`DECISIONS.md` §25 there): its `pb_data/` was copied to the homelab server
  `heidilab` on 2026-08-05, and the droplet was destroyed on 2026-08-23 with
  the data held live on heidilab and in two restic snapshots in Backblaze B2.
- **No ledger was lost.** From 2026-08-23 until 2026-10-10 this document said
  the droplet was destroyed without an export, taking the production ledger and
  every uploaded file with it. That was wrong: the session that wrote it could
  not see the homelab repo. The copy on heidilab is the droplet's complete
  `pb_data/`.
- **What that ledger holds is test data**, all entered on 2026-07-10: one user,
  two locations, two items, two assets (`A001`, `A002`), one movement, one
  reservation, and no uploaded files (`pb_data/storage/` does not exist). No
  field data has been entered into any TrenchNote deployment.
- **How it runs:** a Docker Compose stack at `/srv/apps/trenchnote` on
  heidilab, defined by the homelab repo (`docs/APPS.md`, `DECISIONS.md` §23
  and §54 there) rather than by this repo's `deploy/` runbook. ADR 0003 is
  unaffected — this repo still ships no container files — and ADR 0006's
  second amendment records why. It binds heidilab's tailnet address on port
  8101 and is reachable only over the Tailscale mesh.
- **Backups:** `/srv/apps` is backed up nightly by the homelab's restic job to
  B2, and PocketBase writes its own nightly backup zip into `pb_data/backups/`.
  No restore of this instance has been rehearsed (task 050).
- **It is not current, and not yet a working PWA** (task 040):
  - its code is a 2026-07-10 checkout at migration `1783468808` — 17 of the
    repository's 25 — so readings, inspections, condition reports, transfer
    manifests, gang boxes and `moved_at` do not exist there;
  - `pb_hooks/` is not mounted, so the off-site move email and the gang-box
    invariants are not enforced;
  - it is served over plain HTTP, which is not a secure context, so `sw.js`
    never registers and ADR 0008's offline layer is absent;
  - it runs the community image `ghcr.io/muchobien/pocketbase:0.39.6`, which
    the homelab is replacing with its own `homelab/pocketbase` image built from
    the official release.

**Printed labels.** Any label printed against the droplet encodes
`app.trenchnote.com`, which no longer resolves; such a label works again only
when that hostname points at a live instance *and* that instance's `assets`
carry the same `tag_code`. The surviving data holds only the two test assets,
so real gear would be seeded fresh — with the code already on its label, which
for fleet equipment is the stenciled number (ADR 0010 addendum). Re-seeding
with new codes fails silently: every scan resolves to "No asset found with
tag …".

## Current tests and verification

**CURRENT:** `scripts/smoke_test.sh` is the automated regression gate. It boots
a fresh PocketBase from `pb_migrations/` into a throwaway `pb_data_smoke/`, runs
the full `scripts/seed_demo.sh`, and asserts the core invariants through the
public REST API: authentication required on every collection for both reads and
writes, all seven ledgers append-only, the movement shape rules, the
write-movement-then-cache sequence, derived bulk stock (in minus out, including
a representable negative balance), the reservation lifecycle, the inspection
requirement/asset pairing, one-level Gang Box containment, and the kit-audit
missing-item detach/park side effect (ADR 0021). It exits non-zero on any
regression and is run before a migration lands, a tag, or a deploy.
`scripts/seed_demo.sh` itself remains a living exercise of the API contract.
`deploy/preflight.sh` validates a throwaway PocketBase startup and collection
availability, while `deploy/verify-live.sh` performs read-only checks against a
deployment.

There is still no automated browser or CI test suite. Frontend verification is
manual: exercise pages in a browser, test offline by warming caches and stopping
PocketBase, and verify queued writes after restart.

## Known limitations and active instability

- **CURRENT:** there is no public deployment. The only instance is the
  tailnet-only one on heidilab, running 2026-07-10 code against test data, over
  plain HTTP. Nothing in this document about field behavior is currently being
  exercised by real users.
- **CURRENT:** `scripts/smoke_test.sh` guards the migrations, the API access
  rules, and the derived calculations, but offline replay, internal
  documentation links, and browser flows still have no automated gate and are
  verified manually.
- **CURRENT:** API list calls commonly cap at 500 records. The inspection CSV
  export paginates; several dashboard and detail views do not.
- **CURRENT:** the QR base URL is embedded when labels are printed. Native
  camera scans require labels to be reprinted after a host change; the in-app
  scanner can accept a TrenchNote URL from an older origin.
- **CURRENT:** the two-step movement-then-cache update can leave
  `assets.current_location` stale if the second write fails. The ledger remains
  authoritative.
- **CURRENT:** offline ordering is server arrival order. Concurrent crews may
  produce an honest movement history containing stale assumptions.
- **CURRENT:** synchronous SMTP can delay a notified request when mail settings
  point to an unreachable server, although mail failure cannot undo the write.
- **CURRENT:** `v1.0.0` (2026-07-20) is the first tagged release. The release
  procedure is recorded in `RELEASING.md`.
- **UNKNOWN:** there is no committed mapping from TrenchNote locations/job codes
  to project identities in sibling products.

## Related documents

- [Product boundary](product-boundary.md)
- [Domain model](domain-model.md)
- [Invariants](invariants.md)
- [Architecture status](architecture-status.md)
- [Lifecycle map](lifecycle-map.md)
- [Public API contract](API.md)
- [Developer guide](DEVELOPER_GUIDE.md)
- [Documentation index](documentation-index.md)
