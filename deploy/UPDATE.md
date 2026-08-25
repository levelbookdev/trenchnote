# TrenchNote — updating a live instance

For a box that's **already deployed and serving** at your **DOMAIN** (the
hostname from the [README](README.md) runbook — the one the QR labels encode).
New deploy instead? Use [README.md](README.md). The why behind these commands
is in [docs/DEPLOY.md → Updating](../docs/DEPLOY.md#updating).

> **No instance is deployed as of 2026-08-23.** The VPS that served
> `app.trenchnote.com` was destroyed without exporting `pb_data/`, so the
> primary is being rebuilt from scratch on self-hosted hardware at the same
> hostname. Until it is back up, this file is the procedure for *afterwards* —
> stand the box up with [README.md](README.md) first.

The whole update is `git pull` + restart — schema ships as migrations that
auto-apply on boot. The discipline around it is what this checklist is for,
because you're touching **production data**.

## The golden rule

**Back up before you pull. Every time.** A migration runs against the real
ledger on restart; a backup is your only undo. If you don't yet have the Pi
replica (runbook Phase 6), this manual backup is your *only* safety net.

## Checklist

### 1. Back up — and get the backup OFF the box
Admin UI → **Settings → Backups → Create**, then download the zip to your
laptop (or confirm the S3 target has it). A backup sitting only on the server
protects against nothing — that is the whole lesson of a box that no longer
exists.

### 2. Note the current version (for rollback)
```sh
cd /opt/trenchnote/app
git rev-parse --short HEAD     # write this down — the commit to roll back to
```

### 3. Pull + restart
```sh
sudo -u trenchnote git pull
sudo systemctl restart trenchnote      # pending migrations auto-apply, in order
systemctl status trenchnote            # active (running)
journalctl -u trenchnote -n 30         # skim for migration errors
```

### 4. Verify it's actually current
From your laptop, in a checkout of the version you just deployed:
```sh
sh deploy/verify-live.sh https://DOMAIN
```
Expect `LIVE VERIFY PASS`. It checks health, that every collection exists
(catches a migration that didn't apply), that `receiving.html` serves the real
page (not the catch-all dashboard), and that the deployed `sw.js` VERSION
matches your checkout. Or check by hand:
```sh
curl -s -o /dev/null -w '%{http_code}\n' https://DOMAIN/api/collections/inspections/records  # want 200
curl -s https://DOMAIN/sw.js | grep 'const VERSION'                                          # want the repo's version
```

### 5. Phones update themselves
The bumped `sw.js` VERSION makes each phone re-download the app shell on its
next visit with signal — no crew action needed. **Labels do NOT need
reprinting** for a code update: they encode `asset.html?code=…`, unchanged.
(Reprint only when the *domain/URL* changes.)

## Rollback (if step 4 fails or something's wrong)

Additive migrations (new collections / new optional fields) don't remove data,
so most bad updates are a code problem, not a data one:

```sh
cd /opt/trenchnote/app
sudo -u trenchnote git checkout <the short hash from step 2>
sudo systemctl restart trenchnote
```

If a migration itself misbehaved and you need the data back, restore the
step-1 backup: Admin UI → Settings → Backups → restore on the zip (it unpacks
and restarts PocketBase). This is why step 1 is non-negotiable.

## The 2026-07 catch-up jump — obsolete

This file used to end with a plan for dragging a long-lived box from a
pre-readings schema up to `main`, migration by migration. That box was the VPS
behind `app.trenchnote.com`; it was destroyed on 2026-08-23 and its `pb_data/`
was not exported, so there is no old database left to drag anywhere. The
replacement starts from `main` and applies every migration on first boot, in
order, with nothing to stage.

The section is gone rather than updated because a catch-up plan is only ever
about a *specific* box's specific lag. Write a new one if a future instance
ever falls behind — and note that the reason this one never got applied is
that the box stopped existing first, which is an argument for step 1 of this
checklist, not against it.
