# ADR 0006 — Deployment topology: VPS primary, Pi as replica + staging

**Status:** accepted · **Date:** 2026-07-09

## Context

TrenchNote is leaving the maintainer's laptop. The division's crews scan
from ~12 sites over cell data, which requires an internet-facing instance
(ADR 0004's lockdown made that safe). The maintainer also has a Raspberry
Pi available, and the ledger — the thing that wins vendor disputes — must
survive a dead VPS.

The tempting wrong answer was two live peers (VPS + Pi) syncing with each
other. Multi-master sync of a SQLite ledger is a distributed-systems
project, and TrenchNote's ethos (and the non-goals list) says no.

## Decision

- **The VPS is the single production instance.** DNS + Caddy HTTPS, per
  DEPLOY.md Option B. All phones, all sites, one URL, one ledger.
- **The Pi is a replica and staging box, never a peer.** It receives
  continuous replication of the production database (Litestream) and/or
  pulls the nightly backup zips. It also runs throwaway PocketBase
  instances against restored copies to rehearse upgrades and migrations
  before they touch production.
- **A genuinely offline site (no cellular at all) gets its own standalone
  TrenchNote install** — its own PocketBase, its own accounts, its own
  printed labels (QR labels encode a base URL, so they bind to one
  instance anyway). It is not a peer of the main instance and is never
  merged automatically.

## Consequences

- One writable ledger means no conflict resolution, ever. Losing the VPS
  means restoring to a new box from the Pi's replica — minutes of work,
  documented in DEPLOY.md with a mandatory rehearsal.
- Litestream covers the SQLite files only; uploaded photos
  (`pb_data/storage/`) ride along on a scheduled rsync. PocketBase's own
  scheduled zip backups stay on as the second, independent layer.
- The Pi replica is read-only by construction (a restored copy, not a
  server crews can reach) — nobody can accidentally fork the ledger by
  scanning against the wrong box.
- If a standalone offline-site instance ever needs its history folded
  into the main ledger, that's a deliberate one-time import job (the
  movements collection is append-only CSV-shaped data), not sync.
