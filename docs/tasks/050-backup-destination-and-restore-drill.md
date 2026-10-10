# 050 — Rehearse a restore of the homelab instance, from its off-box backup

Status: BLOCKED (executes on the homelab machines after task 040, not from this repo)

## Context

ADR 0006's 2026-08-23 amendment set the rule this task enforces: *one
writable instance plus a working off-box copy*, with the second half no more
optional than the first. This task originally existed to create that
off-box copy, on the belief that the droplet had been destroyed with no
backup. That belief was wrong (ADR 0006, 2026-10-10 amendment), and the
off-box copy already exists:

- The instance lives at `/srv/apps/trenchnote` on heidilab, and `/srv/apps`
  is a source of the homelab's nightly **restic → Backblaze B2** job, in its
  entirety (homelab `DECISIONS.md` §10 and §23, `docs/APPS.md` → *Backup*).
  At the droplet's destruction, two restic snapshots held its `data.db`
  (homelab §25).
- PocketBase's built-in nightly backup also writes zips into
  `data/backups/`, which restic carries off the box with everything else.

So the destination is **settled** — the homelab's restic repository, not a
new bucket. What has never happened is a **restore**. [`../DEPLOY.md`](../DEPLOY.md)
is blunt about it: *"a backup you have never restored is a hope, not a
backup."* The drill is this task's deliverable.

## Scope

**Executed by the maintainer** on the homelab machines — restic's credentials
are root-owned on heidilab, and an execution session in this repo must not
read or copy them.

**Depends on [`040`](040-homelab-primary-tailnet.md).** Drill the instance
as it will actually run: on `main`, with hooks, on `homelab/pocketbase`.

**Repo files this task may touch:**
- `docs/current-state.md` — the *Backups* bullet in *Current deployment
  topology and status*: add the date the restore drill was performed and
  what it verified.
- `docs/architecture-status.md` — the deployment-topology row's risk column,
  which names the unrehearsed restore.
- This file's `Status:` line.

**Do NOT touch:**
- The homelab's restic configuration, keys or schedule. They are the homelab
  repo's, and they already work for every other app.
- `deploy/litestream.yml` or the Pi-replica material (ADR 0006, optional,
  later). A replica is not a substitute for a rehearsed restore.
- Application code, migrations, hooks, or `pb_public/`.

## Specification

1. **Give the drill something to prove.** The instance has no uploaded files
   yet, and a restore of an empty `storage/` proves nothing about one. In the
   live instance, create a throwaway location, item and asset, log one move
   with a packing slip attached (a photo of anything), and note the asset's
   tag code. Wait for that night's restic run, or trigger one.
2. **Restore on a different machine.** Restoring onto heidilab proves nothing
   about surviving heidilab. Use the lemur, the homelab's staging box: pull
   `/srv/apps/trenchnote` from the **latest B2 snapshot**, not from heidilab's
   disk. The commands are homelab `docs/RECOVERY.md` → *Scenario C*, steps 3
   and 4, restricted to that one path. The lemur's restic is deliberately
   unconfigured (homelab §31): export the credentials from the password
   manager into one shell for the drill and close it after. Do not install
   `/etc/homelab-backup/env` on the lemur.
3. **Boot it the way production runs it.** On the lemur, build the image
   (`bash apps/pocketbase/build.sh`), put the restored folder at
   `/srv/apps/trenchnote`, set `.env` to the lemur's own `BIND_ADDR` and a
   free port from the lemur's registry in homelab `docs/APPS.md`, and
   `docker compose up -d`.
4. **Verify the ledger, not the container.** Open the throwaway asset's page:
   its movement history is intact, **and the attached packing slip loads**.
   `pb_data/storage/` is the receiving log's evidence (ADR 0013), and a backup
   that silently drops it is the failure worth catching.
5. **Clean up.** Take the drill copy down on the lemur. Nothing on the lemur
   is backed up and nothing should live there (homelab §31). Mark the
   throwaway records in the live instance with a note; the ledger is
   append-only, so they are not deleted.

Record the date and what was verified. That date is the fact
`docs/current-state.md` is missing.

## Acceptance criteria

- [ ] The restore came from the **B2 snapshot**, onto the **lemur**, not
      from heidilab's disk and not onto heidilab.
- [ ] The restored instance ran on `homelab/pocketbase` at the same version
      as production.
- [ ] The test asset's page showed its movement history, and the attached
      packing slip loaded from the restored `storage/`.
- [ ] The drill copy was removed from the lemur afterwards.
- [ ] `docs/current-state.md` *Backups* bullet states the drill date and
      what passed; `docs/architecture-status.md` deployment row updated.
- [ ] Docs reviewed per the docs-as-code checklist in
      [`../../CLAUDE.md`](../../CLAUDE.md). No ADR expected: ADR 0006 already
      requires a working off-box copy, and this task proves one.

## Guardrails

- **Never copy a live `pb_data/`.** SQLite keeps in-flight writes in `-wal`
  sidecars, and a naive copy looks fine until it is needed. The restic
  snapshot is the source here; for anything else, `docker compose down` first.
- **Never read or copy restic's credentials into this repo or a task file.**
  They sit in root-owned files on heidilab; losing or leaking the repository
  password is unrecoverable.
- **Configured is not done.** The drill is the acceptance criterion.
- No real field data in the instance until this task is `DONE` (task 040's
  guardrail, restated because this is the task that lifts it).
