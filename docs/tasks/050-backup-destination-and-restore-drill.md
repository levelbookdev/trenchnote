# 050 — Give the new primary an off-box backup and a rehearsed restore

Status: BLOCKED (executes on the homelab box, not from this repo)

## Context

On 2026-08-23 the VPS serving `app.trenchnote.com` was destroyed and
`pb_data/` was not exported. Every movement, reading, inspection, condition
report and reservation was lost, along with every uploaded packing slip and
damage photo. There was no replica, no backup zip, and no restore path.
[`../current-state.md`](../current-state.md) records this as realized loss
rather than risk, and names the remedy directly: *"the first deployment task
on the replacement is a backup destination and a rehearsed restore, before
crews put anything in it worth losing."* This is that task.

It matters more on the replacement than it did on the droplet, not less. The
maintainer confirmed on 2026-09-07 that the droplet is abandoned
permanently — so there is no second copy of anything, anywhere, and no
provider snapshot to fall back on. Until this task is `DONE`, the homelab
box built in [`040`](040-homelab-primary-tailnet.md) is a single point of
failure holding the only copy of whatever is put into it.

[`../DEPLOY.md`](../DEPLOY.md) → *Backups* already specifies the mechanism
in full. This task is not a design exercise; it is the act of configuring
one of the documented methods, getting the result off the box, and
**performing** a restore rather than believing in one.

`docs/current-state.md` also flags as **UNKNOWN** whether an offsite backup
destination or a restore drill was ever operational on the destroyed VPS.
That gap is what the data loss looks like from the outside. Closing it here
means the answer stops being unknown.

## Scope

**This task is executed by the maintainer, on the box and in the admin UI.**
Hence `BLOCKED` — the same convention [`README.md`](README.md) describes for
work that is specified here but cannot be carried out from this repo. An
execution session cannot open the PocketBase admin UI, create bucket
credentials, or verify a restored asset page, and must not attempt to.

**Depends on [`040`](040-homelab-primary-tailnet.md).** There is nothing to
back up until the instance exists. Do not start this task first.

**Repo files this task may touch:**
- `docs/current-state.md` — the **UNKNOWN** paragraph about whether an
  offsite destination, SMTP, or restore drill was ever operational, which
  becomes answerable for the new box once this is done.
- `docs/architecture-status.md:31` — the deployment row's open question
  "which backup destination is configured on day one".
- This file's `Status:` line.

**Do NOT touch:**
- `deploy/litestream.yml` or the Phase 6 Pi-replica material. Litestream
  replication to a Pi is a *different*, optional layer (ADR 0006) and is
  explicitly out of scope here. A scheduled backup that lands off the box is
  the requirement; a streaming replica is not.
- Application code, migrations, hooks, or `pb_public/`.

## Specification

Pick **one** destination and make it work end to end. Both are documented in
`../DEPLOY.md` → *Backups*; neither is better in the abstract.

**Method 1 — PocketBase's built-in backups to S3-compatible storage
(recommended).** Admin UI → Settings → Backups: set a nightly cron
(`0 3 * * *`), keep 7, and point the same screen at a bucket.

**Method 2 — offsite copy of the backup zips.** Keep the built-in schedule
writing to `pb_data/backups/`, and pull them from another machine on a cron
via rsync over the tailnet.

### Credential hygiene, if Backblaze B2 is chosen

B2 is already in use on `llmbox` for the unrelated vault-clerk restic
backups. **Create a new bucket and a new B2 application key scoped to it.**
Do not reuse the vault-clerk key: it is root-owned, its file must never be
read or copied, and losing or leaking the restic password it sits beside is
unrecoverable. Two independent backup systems get two independent keys.

### The restore drill is the deliverable

A configured destination is half the task. `../DEPLOY.md` is blunt: *"a
backup you have never restored is a hope, not a backup."* Perform the drill
on a **different machine** from the one being backed up — restoring onto the
same box proves nothing about surviving that box's loss:

1. Clone the repo, run `PB_VERSION=0.39.6 ./scripts/setup.sh`.
2. Take a real backup zip **from the off-box destination** — not from
   `pb_data/backups/` on the primary. Fetching it from the destination is
   part of what is being tested.
3. Unpack it into a fresh `pb_data/` (or use the admin UI restore), start
   PocketBase.
4. Open an asset page and confirm its movement history is intact, and
   confirm an uploaded file (a packing slip or damage photo) still loads —
   `pb_data/storage/` is as much the ledger's evidence as the database is,
   and a backup that silently omits it is the failure mode worth catching.

Record the date the drill was performed and what was verified. That date is
the fact `docs/current-state.md` is missing.

## Acceptance criteria

- [ ] A backup schedule exists on the primary (nightly, several retained),
      visible in Admin UI → Settings → Backups.
- [ ] Backups land **off the box** — in an S3-compatible bucket, or pulled
      to a second machine. A backup sitting only on the primary does not
      satisfy this task.
- [ ] If B2 was used: a dedicated bucket and a dedicated application key,
      not the vault-clerk restic credentials.
- [ ] The restore drill was **performed**, on a different machine, from a
      zip retrieved from the off-box destination.
- [ ] The restored instance serves an asset page with intact movement
      history, **and** an uploaded file from `pb_data/storage/` loads.
- [ ] `docs/current-state.md` updated: the UNKNOWN paragraph now states, for
      the new box, which destination is configured and the date the restore
      drill was performed and passed.
- [ ] `docs/architecture-status.md:31` open question about the day-one
      backup destination closed.
- [ ] Docs reviewed per the docs-as-code checklist in
      [`../../CLAUDE.md`](../../CLAUDE.md). No ADR expected — `../DEPLOY.md`
      already specifies the mechanism and ADR 0006 already requires a working
      off-box copy; this task carries that decision out rather than making a
      new one.

## Guardrails

- **Never copy `pb_data/` while the server is running.** SQLite keeps
  in-flight writes in `-wal` sidecar files, and a naive `cp` produces a copy
  that looks fine until it is needed. Use the built-in backup (which handles
  locking) or stop the service first. `../DEPLOY.md` calls this "rule one".
- **`pb_data/storage/` is not optional.** The uploaded packing slips and
  damage photos are dispute evidence (ADR 0013, ADR 0019). A backup covering
  only the database is not a backup of the ledger.
- **Do not build the Pi replica or Litestream here** (ADR 0006 Phase 6).
  That layer is optional, comes later, and is not a substitute for a
  scheduled off-box backup — the destroyed VPS is proof that a replica which
  is always "later" protects nothing.
- **Do not treat this as done because it is configured.** The drill is the
  acceptance criterion. The last deployment presumably had good intentions
  too.
- Do not read, print, or copy the vault-clerk credential files on `llmbox`
  under any circumstances, including to "check the B2 account". Create fresh
  credentials instead.

## Definition of done

- [ ] Acceptance criteria all checked.
- [ ] Not applicable: no build, no migrations, no `sw.js` bump — this task
      changes no application code.
- [ ] Documentation updated (`docs/current-state.md`,
      `docs/architecture-status.md`); `AGENTS.md` mirrored only if
      `CLAUDE.md` changed, which it should not.
- [ ] `Status:` above set to `DONE`. No `ROADMAP.md` milestone is tied to
      this task.
- [ ] Committed (author: maintainer only, **no `Co-Authored-By` trailer**)
      with a message naming the destination and the drill date. Then stop
      and show the maintainer.
