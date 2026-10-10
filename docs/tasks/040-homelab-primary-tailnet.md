# 040 — Bring the homelab instance to `main`, on the shared image, over tailnet HTTPS

Status: BLOCKED (executes on heidilab, after homelab DECISIONS §54 is committed and its image built there; not from this repo)

## Context

TrenchNote's only instance runs on the maintainer's homelab server, `heidilab`,
as a Docker Compose stack at `/srv/apps/trenchnote`. It holds the complete
`pb_data/` of the retired droplet behind `app.trenchnote.com`, copied there on
2026-08-05 (homelab repo `DECISIONS.md` §25). That data is test data from
2026-07-10: two assets (`A001`, `A002`), one movement, no uploaded files. The
full account is in [`../current-state.md`](../current-state.md) under
*Current deployment topology and status*, and in ADR 0006's 2026-10-10
amendment.

This task previously specified a fresh install in an LXC, on the belief that
the droplet's data was lost. Neither premise held, and on 2026-10-10 the
maintainer settled the hosting question for all of their PocketBase apps:
**Docker Compose, on one image the homelab builds from the official release**
(`homelab/pocketbase:<version>`, homelab `DECISIONS.md` §54 and
`docs/APPS.md`). That is a **settled input**, not a choice for the executing
session. ADR 0003 is unaffected: the compose file lives in the homelab repo,
and this repo ships no container files.

What is wrong with the instance today, and what this task fixes:

1. **Old code.** `app/` is a 2026-07-10 checkout at migration `1783468808` —
   17 of 25. Readings, inspections, condition reports, manifests, gang boxes
   and `moved_at` do not exist there.
2. **No hooks.** `pb_hooks/` is not mounted, so the off-site move email
   (`main.pb.js`) and the gang-box invariants (`containers.pb.js`) do not run.
   The compose file still carries a comment saying TrenchNote has no hooks.
3. **Community image.** It runs `ghcr.io/muchobien/pocketbase:0.39.6`, which
   the homelab is replacing with `homelab/pocketbase:0.39.6`.
4. **Plain HTTP.** It is served at `http://100.75.94.35:8101`. Plain HTTP over
   the mesh is not a secure context, so `sw.js` never registers and ADR 0008's
   offline layer (shell cache, write queue, stale banner) is absent while the
   app looks healthy. [`../DEPLOY.md`](../DEPLOY.md) Option C explains why TLS
   is required, and why `tailscale serve` is how a tailnet-only box gets it.

Going public is a later, separate move. Nothing here touches the
`trenchnote.com` zone or the GitHub Pages records (task 060).

## Scope

**This task is executed by the maintainer, on heidilab** — or by a session
that can reach heidilab and has the maintainer's go-ahead for each step that
changes the live stack. `tailscale serve` needs root or Tailscale operator
rights there.

**Settle before starting: keep the test data, or start empty?** The
recommended default, used below, is **archive and start empty**: the ledger
is append-only, so test rows kept now ("John" moving `A001` to
"1234 District Pump Station") stay in the real ledger forever. The archive
stays inside `/srv/apps/trenchnote`, so restic keeps it. If the maintainer
says keep it, skip step 3; migrations bring the old database forward.

**Repo files this task may touch, and only after the instance is verified:**
- `docs/current-state.md` — the *Current deployment topology and status*
  section: code level, hooks, HTTPS URL, the data decision, date verified.
- `docs/architecture-status.md` — the deployment-topology row's status word
  and its open question about the HTTPS port.
- This file's `Status:` line.

**Do NOT touch:**
- Anything in `pb_public/`, `pb_migrations/`, or `pb_hooks/`. This is a
  deployment, not a code change. No `sw.js` VERSION bump is involved.
- `deploy/` — it remains the self-hoster's systemd path and is not used here.
- No Dockerfile or compose file in this repo (ADR 0003). The compose file is
  the homelab's; its template is homelab `docs/APPS.md`.
- The `trenchnote.com` DNS zone and the GitHub Pages records.

## Specification

Commands run on heidilab as a user in the `docker` and `homelab` groups. The
`app/` checkout is owned by `homelab`, so git needs
`-c safe.directory=/srv/apps/trenchnote/app` (or `sudo -u homelab`).

1. **Precondition.** In `~/homelab`: `git pull`, then
   `bash apps/pocketbase/build.sh`, which must print `0.39.6`. Confirm last
   night's restic snapshot contains `/srv/apps/trenchnote/data` (homelab
   `docs/APPS.md` → *Backup*), because the migrations below are one-way.
2. **Stop the stack:** `cd /srv/apps/trenchnote && docker compose down`.
3. **Archive the test data** (skip if keeping it):
   `mv data data.droplet-20260805 && install -d -m 755 data`. Never delete it.
4. **Update the code:** `git -C app pull --ff-only` to `main`, then confirm
   `app/pb_hooks/` holds `main.pb.js` and `containers.pb.js`.
5. **Rewrite `docker-compose.yml`** to the homelab `docs/APPS.md` template:
   `image: homelab/pocketbase:0.39.6`, `pull_policy: never`, no `command:`
   line, and the `./app/pb_hooks:/pb_hooks:ro` mount. Delete the stale
   "no pb_hooks" comment. Then `docker compose config >/dev/null`.
6. **Start and check:** `docker compose up -d`, healthy within a minute, and
   the logs show no migration or hook errors. All 25 app migrations are in
   `_migrations` (read the database only after `docker compose stop`, or the
   WAL hides recent writes).
7. **HTTPS on the tailnet.** Port 443 on heidilab's `tailscale serve` already
   fronts Jellyfin, so TrenchNote gets its own HTTPS port. Claim it in the
   homelab `docs/APPS.md` registry, then run
   `tailscale serve --bg --https=<port> http://100.75.94.35:8101` and confirm
   with `tailscale serve status`. Do not rebind the container to `0.0.0.0`.
8. **First-run config** (on an empty database): create the superuser, set
   Application URL to `https://heidilab.tail059fc0.ts.net:<port>`, and create
   the shared field account and the personal PM accounts. SMTP is optional;
   moves work without it and the hook logs a skip line.

Seed only what verifies the install. **Do not run `scripts/seed_demo.sh`
against this instance.** No real gear is entered until task 050 is `DONE`.
When it is, every `tag_code` must match the label already on that piece of
gear, which for fleet equipment is the stenciled number (ADR 0010 addendum).

## Acceptance criteria

- [ ] `docker compose ps` shows the `trenchnote` container **healthy** on
      `homelab/pocketbase:0.39.6`; `docker compose config` shows no
      `command:` and a `pb_hooks` mount.
- [ ] `_migrations` lists all 25 TrenchNote migrations, the newest
      `1783468826_movement_moved_at.js`.
- [ ] `tailscale serve status` maps `https://heidilab.tail059fc0.ts.net:<port>`
      to `http://100.75.94.35:8101`, and that port is claimed in homelab
      `docs/APPS.md`.
- [ ] `sh deploy/verify-live.sh https://heidilab.tail059fc0.ts.net:<port>`
      prints `LIVE VERIFY PASS`, run from a checkout of the deployed commit so
      the `sw.js` VERSION comparison is meaningful.
- [ ] **The service worker registers.** On a real device over the `https://`
      URL, DevTools → Application → Service Workers shows `sw.js` *activated
      and running*. Without it the deployment is not done.
- [ ] The test data is either archived at `data.droplet-20260805/` or
      deliberately kept, and `docs/current-state.md` says which.
- [ ] No demo data, no labels printed from this instance.
- [ ] `docs/current-state.md` and `docs/architecture-status.md` reconciled:
      code level, hooks, the HTTPS URL, and the date verified.

## Guardrails

- **No real field data until task 050 is `DONE`.** Backups exist (restic to
  B2, plus PocketBase's own zips), but no restore of this app has ever been
  rehearsed.
- **Plain HTTP is not done.** A page that loads over `http://` on the mesh is
  missing its whole offline layer and gives no sign of it.
- **Do not print labels**, and do not treat the `.ts.net` address as final.
  It is unreachable off the mesh, so a label encoding it is dead the day the
  deployment goes public.
- **Do not relitigate settled decisions:** no container files in this repo
  (ADR 0003); no LXC (homelab §54); no second writable instance (ADR 0006).
- Tailscale on every device is an app-store install per phone, which the
  ethos rules out for crews. This is a staging and small-team shape; do not
  plan a crew rollout on top of it.

## Definition of done

- [ ] Acceptance criteria all checked.
- [ ] No application code changed, so no `sw.js` bump.
      `scripts/smoke_test.sh` is unaffected but should be green on the
      deployed commit.
- [ ] Docs reconciled as above. `AGENTS.md` mirrored only if `CLAUDE.md`
      changed, which it should not.
- [ ] `Status:` above set to `DONE`.
- [ ] Committed (author: maintainer only, **no `Co-Authored-By` trailer**),
      then stop and show the maintainer.
