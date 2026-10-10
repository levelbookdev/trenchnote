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

## Amendment — 2026-08-23: the primary moves to self-hosted hardware

The rented VPS that served `app.trenchnote.com` was destroyed, and its
`pb_data/` was not exported first. The primary is being rebuilt on the
maintainer's own server, at the same hostname, as a fresh install.

**The decision above is unchanged**, and this is not a new ADR, because
nothing here was ever about renting the machine. Read "VPS" throughout this
record as *the single writable instance, wherever it runs*: one URL, one
ledger, no peers, Caddy in front, PocketBase on localhost. Owning the hardware
changes the invoice and the physical location, not the topology — which is why
nothing in `deploy/` needed editing when the provider went away.

Three things did change — the first of them a correction to this record
rather than a consequence of the move:

- **The "losing the VPS" path in the Consequences section above was wrong,
  and this is how we found out.** It says losing the VPS means "restoring to a
  new box from the Pi's replica — minutes of work." That sentence assumed a
  replica that was never built: Phase 6 of the runbook was always "later," and
  the ADR's own safety net was optional. The box went away and took the ledger
  with it. **One writable instance is a correct topology only when the copy
  that makes it survivable actually exists** — the decision here should be
  read as *one writable instance plus a working off-box copy*, with the second
  half no more optional than the first.
- **Self-hosted hardware moves availability onto the maintainer's own
  uplink, power, and IP.** A residential connection and a dynamic address are
  real constraints for crews scanning over cell data from twelve sites; a
  reverse tunnel or a static address is part of the deployment, not an
  afterthought.
- **The hostname is deliberately unchanged, which saves the printed labels —
  but only halfway.** QR labels bake in a base URL (ADR 0010), so reusing
  `app.trenchnote.com` means no reprint. The URL still carries a `tag_code`
  the rebuilt database has to recognize, so re-seeding `assets` must reuse the
  codes already laminated and hanging on the gear — for anything with a
  stenciled fleet number that code is still painted on the machine (ADR 0010
  addendum). Same URL, new codes, is the quiet failure mode: every label
  resolves and every scan says "No asset found with tag …".

## Amendment — 2026-10-10: the ledger was not lost, and the primary runs in Docker

The amendment above was written from inside this repo, which could not see
the maintainer's homelab repo. Two of its premises were wrong:

- **The droplet's `pb_data/` was exported.** The homelab repo retired the
  droplet (`trenchnote-db1`) deliberately: its data was copied to the homelab
  server, heidilab, on 2026-08-05, and the droplet was destroyed on 2026-08-23
  with that copy live and in two restic snapshots in Backblaze B2 (homelab
  `DECISIONS.md` §25). What the copy holds is test data from 2026-07-10 — two
  assets, one movement, no uploaded files. No field ledger existed to lose.
- **The primary is not a systemd + Caddy install.** It is a Docker Compose
  stack under `/srv/apps/trenchnote` on heidilab, tailnet-only, defined in the
  homelab repo (`docs/APPS.md`, `DECISIONS.md` §23 and §54 there). On
  2026-10-10 the maintainer chose Compose over an LXC for all of their
  PocketBase apps, on one image the homelab builds from the official release.

**The decision above still stands**: one writable instance, no peers. Only
the machinery under it differs, and the first amendment's lesson survives the
correction intact — *one writable instance plus a working off-box copy*. The
off-box copy that existed came from the homelab's restic job, not from
anything in `deploy/`, and it has still never been restore-tested for this
app (task 050).

What this does **not** change: the supported self-host path is still
`deploy/` (systemd, Caddy, built-in backups), and this repo still ships no
container files (ADR 0003). The homelab's compose file is the maintainer
containerizing their own instance — the case ADR 0003 explicitly leaves open.
