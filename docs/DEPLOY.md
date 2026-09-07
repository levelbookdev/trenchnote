# TrenchNote — Deployment & Backups

How to run TrenchNote somewhere other than your laptop, and how to make sure
a dead SD card can't erase eighteen months of ledger history.

> **Auth status:** as of migration `1783468806`, every API rule requires a
> signed-in user and there is no public self-registration (see ADR 0004).
> All three options below are safe. For anything internet-facing, use Option B's
> HTTPS setup — never expose the bare HTTP port to the world — and use
> strong passwords on the admin and user accounts.

## First-boot hardening (any internet-reachable box)

Before the app, in this order (learned on the real deployment). On a LAN-only
trailer box this is optional; on a VPS it is not.

1. `apt update && apt upgrade -y`, then reboot if `/var/run/reboot-required`
   exists (fresh images usually have a pending kernel).
2. **A non-root admin user, key-only:**
   `adduser --disabled-password --gecos "" deploy`, add to `sudo` group, copy
   `/root/.ssh/authorized_keys` into `/home/deploy/.ssh/` (mode 700/600,
   owned by deploy). A passwordless account can't use password-prompting
   sudo — grant it explicitly:
   `echo 'deploy ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/deploy` and
   validate with `visudo -c`. **Verify you can SSH in as deploy and sudo
   works BEFORE the next step** — and keep your root session open until
   you have.
3. **Disable root login and passwords** with a drop-in at
   `/etc/ssh/sshd_config.d/00-hardening.conf`:
   ```
   PermitRootLogin no
   PasswordAuthentication no
   KbdInteractiveAuthentication no
   ```
   The `00-` prefix matters: OpenSSH keeps the *first* value it sees, and
   cloud images ship a `50-cloud-init.conf` that would otherwise win.
   Validate with `sshd -t` (silence = valid), then `systemctl reload ssh`,
   then prove root is refused and deploy still works before closing anything.
4. **Firewall, allows queued before enabling:**
   `ufw allow OpenSSH && ufw allow 80/tcp && ufw allow 443/tcp && ufw enable`.
   Note what's absent: 8090. PocketBase binds to localhost and is reachable
   only through Caddy.
5. `apt install unattended-upgrades` and enable it (both lines in
   `/etc/apt/apt.conf.d/20auto-upgrades` set to `"1"`), so security patches
   don't wait for you.

## Option A — a box on the LAN (job trailer, office)

The right first deployment: a Raspberry Pi, a mini PC, or any always-on
machine on the same network as the phones. No domain, no TLS certificates,
no monthly bill.

```sh
# On the box (any Linux; a Pi 3 or better is plenty):
sudo useradd --system --create-home --home-dir /opt/trenchnote --shell /usr/sbin/nologin trenchnote
sudo -u trenchnote git clone https://github.com/levelbookdev/trenchnote.git /opt/trenchnote/app
sudo -u trenchnote sh -c "cd /opt/trenchnote/app && PB_VERSION=0.39.6 ./scripts/setup.sh"
```

(`--shell /usr/sbin/nologin`: the app account is not for humans. The
`sh -c` wrapper is because your admin user can't `cd` into the app user's
home — that's the 750 permissions working, not a problem.)

Give the box a **fixed address** — reserve its IP in your router's DHCP
settings (e.g. `192.168.1.50`). The QR labels will encode this address;
if it changes, every printed label dies.

### Run it as a service (systemd)

Create `/etc/systemd/system/trenchnote.service`:

```ini
[Unit]
Description=TrenchNote (PocketBase)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=trenchnote
WorkingDirectory=/opt/trenchnote/app
# 0.0.0.0 = listen on the LAN, not just localhost
ExecStart=/opt/trenchnote/app/pocketbase serve --http=0.0.0.0:8090
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Then:

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now trenchnote
```

The service starts on boot, restarts on crashes, and survives power cuts to
the trailer. Visit `http://192.168.1.50:8090/_/` once to create the admin
account, create the app logins in the **users** collection (a shared field
account for crews + personal ones for PMs), seed your
locations/items/assets, then print labels from
`http://192.168.1.50:8090/labels.html` with the Base URL set to
`http://192.168.1.50:8090`.

**Phones must be on the same network** (the site Wi-Fi or an office AP that
reaches the yard). If crews are on cell data only, you need Option B. Note
also that a plain-HTTP LAN address is not a secure context, so the offline
layer (ADR 0008) does not register here — see Option C for why that matters
and how a mesh avoids it.

## Option B — an internet-facing box (rented VPS or your own hardware)

For crews scanning over cell data from twelve different sites, TrenchNote
needs a real domain and HTTPS.

The box can be rented or yours. Everything in this section — the systemd
unit, Caddy, the firewall, the backups — is identical either way, and
nothing in [`deploy/`](../deploy/) is provider-specific. "VPS" below just
means *the machine running the single writable instance*.

> **In a hurry? Use the runbook.** [`deploy/`](../deploy/) has an ordered,
> copy-paste VPS checklist ([deploy/README.md](../deploy/README.md)) plus
> ready-to-use config files — the `trenchnote.service` unit, the `Caddyfile`,
> a `litestream.yml` for the Pi replica, and a `preflight.sh` that proves a
> fresh checkout applies every migration before you cut over. This section
> and the ones below remain the *why* behind each step.

Any $5-tier VPS (1 CPU, 512 MB) is more than enough. Setup is Option A plus
a reverse proxy for HTTPS. [Caddy](https://caddyserver.com) is the boring
choice because it fetches and renews certificates automatically:

```sh
# PocketBase listens on localhost only; Caddy is the front door
ExecStart=/opt/trenchnote/app/pocketbase serve --http=127.0.0.1:8090
```

`/etc/caddy/Caddyfile` — this is the entire proxy config:

```
trenchnote.example.com {
    reverse_proxy 127.0.0.1:8090
}
```

Point your domain's DNS at the VPS, `sudo systemctl reload caddy`, and
TrenchNote is at `https://trenchnote.example.com`. Reprint the labels with
that as the Base URL.

### If that box is your own hardware

Same install, three extra things a rented VPS gave you for free. None is
hard; all three are load-bearing, because crews on cell data can only reach
what your uplink publishes.

1. **A stable public address.** Caddy can only get a certificate for a name
   that resolves to this box. Either a static IP from your ISP, or dynamic
   DNS, or — often the least trouble at home — a tunnel (Cloudflare Tunnel,
   or Tailscale Funnel) so nothing is port-forwarded at all. If you tunnel,
   TLS terminates at the tunnel and Caddy's auto-HTTPS may be redundant;
   don't run both halves of the same job.
2. **Ports 80 and 443 actually reaching the box** if you are not tunneling:
   forwarded at the router, and not blocked by the ISP (residential plans
   commonly block 80 — which also blocks Caddy's HTTP-01 certificate
   challenge; the DNS-01 challenge is the way around it).
3. **Power and uplink are now yours.** The failure modes a datacenter
   absorbed — a power cut, a modem reboot, an upstream outage — are now
   visible to every phone in the field. A UPS and the Phase 6 replica stop
   being optional polish at the point where the yard depends on this.

Weigh those against what you get back: no monthly bill, the ledger sits on
hardware you physically control, and nobody can delete the machine but you.

### Moving between boxes later (LAN to internet, or provider to your own)

Copy `pb_data/` from the old box to the new one (stop the service first,
see Backups below) — that directory *is* the ledger plus every uploaded
packing slip and damage photo, so copy it before you decommission anything.
Then reprint every label whose URL changed: the old QRs encode the old
address, and a LAN IP is unreachable from cell data. Keeping the same public
hostname across a move is the one way to avoid the reprint entirely. This is
why you don't laminate 200 labels before choosing where TrenchNote lives.

**If the old `pb_data/` is gone** — destroyed box, no backup — you are doing a
fresh install, and the labels already hanging on the gear are the constraint.
They encode `asset.html?code={tag_code}`, so reusing the same hostname keeps
them resolving, but only the same **tag codes** make them find anything: seed
`assets` with the codes printed on the labels, exactly. Gear with a stenciled
fleet number carries its own code (ADR 0010 addendum), so most of the catalog
can be rebuilt by walking the yard and reading the paint. A fresh install with
new codes fails quietly — the page loads and says *No asset found with tag …*
for every scan. Rebuild the catalog before the crews come back, then walk the
yard with [`scan.html`](../pb_public/scan.html) to put things back on the map.

## Option C — a private mesh (Tailscale), no domain, no port forwarding

Between A and B there is a third shape: the box stays unreachable from the
public internet, but authorised devices reach it from **anywhere** — a yard,
a hotel, a home office — over a private WireGuard mesh. No DNS record, no
router configuration, no certificate challenge, and TLS that browsers
actually trust.

This is the right choice for **standing an instance up**: rebuilding a
catalog, rehearsing a restore, or piloting with two or three people, before
you commit to a public hostname. It is **not** the crew-facing answer — read
the limits at the end of this section before planning a rollout around it.

### Why not just bind to the mesh address

The obvious move is to point the unit at the mesh interface and browse to
`http://100.x.y.z:8090`. Don't. **Plain HTTP is not a secure context, and
browsers refuse to register a service worker outside one.** TrenchNote's
whole offline layer — the cached app shell, the IndexedDB write queue, the
staleness banner (ADR 0008) — *is* `pb_public/sw.js`, so over plain HTTP it
silently does not exist. The app then looks perfectly healthy on a desk with
good wifi and fails in exactly the dirt-lot conditions it was built for.

`localhost` is the one exception browsers make, which is why this never
shows up while developing. Option A accepts it knowingly: a LAN box with no
certificate has the same limitation, and the tradeoff is that crews need no
mesh account. Option C can do better for free, so it should.

So the mesh has to terminate TLS. Tailscale does that for you.

### The setup

PocketBase keeps the **unmodified** localhost binding from Option B —
`deploy/trenchnote.service` needs no edit at all:

```sh
ExecStart=/opt/trenchnote/app/pocketbase serve --http=127.0.0.1:8090
```

Then enable **HTTPS Certificates** for the tailnet once, in the Tailscale
admin console, and on the box:

```sh
tailscale serve --bg 8090      # publish localhost:8090 over the tailnet, with TLS
tailscale serve status         # confirm the https:// URL it chose
```

TrenchNote is now at `https://<host>.<tailnet>.ts.net` with a real
certificate, reachable by every device signed in to your tailnet and by
nothing else. Verify it the same way as any other deployment:

```sh
sh deploy/verify-live.sh https://<host>.<tailnet>.ts.net
```

**Do not also run Caddy.** `tailscale serve` is the front door here; Caddy
would be a second attempt at the same job, and its HTTP-01 challenge cannot
succeed on a name that resolves only inside the mesh. Option B's Caddy setup
and this are alternatives, never layers.

**Running in a container?** Tailscale needs `/dev/net/tun`. An unprivileged
LXC does not get it by default — pass it through from the host, or
`tailscale up` fails with a TUN device error before any of the above
matters.

**Firewall:** nothing to open. Port 8090 stays on localhost and the mesh
carries the traffic, so the `ufw allow 80,443` lines from the hardening
section have no equivalent here.

### The limits — read before planning a rollout

- **Every device needs Tailscale installed and signed in.** That is an
  app-store download and an account per phone, which is precisely what
  TrenchNote's ethos rules out for crews: a check-in is supposed to be a
  native camera scan into a browser and nothing else. Fine for you and a
  couple of PMs; wrong for twenty laborers on company iPads.
- **QR labels bake in whatever base URL you print.** A `.ts.net` address on
  a laminated label is unreadable to any phone outside the mesh, so **do not
  print production labels from an Option C instance.** Print them once you
  are on the public hostname (see *Moving between boxes later*).
- **It is not a public deployment.** When crews need it, move to Option B.
  That move is a hostname change, not a reinstall: same `pb_data/`, same
  unit — add DNS and Caddy, or keep the mesh and put Tailscale Funnel in
  front, which publishes the same instance without a port forward.

## Off-site move alerts (email setup)

When a location has a **notify email** set, TrenchNote emails that address
the moment anything is logged as leaving that location — item, tag code,
where it went, who moved it, and a link. The losing site's PM finds out
when the truck pulls away, not on Friday.

Two steps: tell TrenchNote how to send email (once per install), then say
who gets notified (per location).

**No email server configured? Nothing breaks.** Moves work exactly the
same; TrenchNote just notes "SMTP not configured — skipped off-site
email" in its log (Admin UI → Logs) and carries on. The alert is
best-effort by design — a scan can never fail because a mail server did.

### Step 1 — give TrenchNote a way to send email

TrenchNote doesn't run its own mail server (nobody should); it hands the
message to one you already have, using a protocol called SMTP — think of
it as the address and password of a post office.

Open **Admin UI → Settings → Mail settings**:

1. **Sender name / sender address** — what the email appears from, e.g.
   `TrenchNote` / `trenchnote@yourcompany.com`.
2. Toggle **SMTP** on and fill in the four boxes from your provider:

   **Google Workspace / Gmail:**
   - SMTP server host: `smtp.gmail.com` · Port: `587` (leave TLS off —
     port 587 upgrades to encryption automatically)
   - Username: the Google account address the mail should come from
   - Password: an **App password**, not the account password — create one
     at myaccount.google.com → Security → 2-Step Verification → App
     passwords (2-Step must be on). Google caps sending (~2,000/day on
     Workspace, 500 on plain Gmail) — far more than a division moving
     equipment will ever send.

   **A transactional mail service (SMTP2GO, Mailgun, Postmark…):** sign
   up, add/verify your sending domain or address, and the dashboard hands
   you exactly these four values — e.g. SMTP2GO: host `mail.smtp2go.com`,
   port `587`, plus the username/password it generates. Free tiers
   (SMTP2GO: ~1,000 emails/month) are plenty.

3. **Send a test** — the paper-plane/"send test email" button on the same
   settings screen. If the test lands in your inbox, you're done. If it
   errors, the message names the problem (wrong password, blocked port —
   some office networks block 25 but allow 587).

Also check **Settings → Application → Application URL** is the address
crews actually use (e.g. `https://trenchnote.example.com`) — it's used to
build the link in the email.

### Step 2 — say who gets notified, per location

Admin UI → Collections → **locations** → edit a jobsite → set
**notify_email** to the PM or superintendent for that site. Leave it
blank for locations where nobody needs a ping (the yard, the shop).
One address per location; a distribution list (e.g.
`bearcreek-team@yourcompany.com`) works fine if more people should see it.

That's it. The email fires when a move's **from** location has a notify
email and the move has a real destination — deliveries arriving on site
and bulk material consumed *on* the site don't count as leaving it.

**Good to know:**

- Every attempt is in Admin UI → **Logs** (search "TrenchNote notify"):
  sent, skipped (no SMTP), or failed and why. A failed email never blocks
  or fails the move itself.
- If mail settings point at a server that's down, moves still succeed —
  but each notified move waits on the mail attempt timing out, which can
  make scans feel slow. If crews report sluggish moves and the log is
  full of "off-site email failed", fix or disable SMTP.

## Updating

```sh
cd /opt/trenchnote/app
sudo -u trenchnote git pull
sudo systemctl restart trenchnote   # pending migrations auto-apply on start
```

Schema changes ship as migrations, so `git pull` + restart is the whole
upgrade. To also upgrade the PocketBase binary itself: stop the service,
delete `pocketbase`, re-run `scripts/setup.sh`, start — but read the
PocketBase release notes first, and take a backup before any binary upgrade.

## Backups

**What needs backing up: `pb_data/` and nothing else.** The schema is
rebuilt from `pb_migrations/` in git; the binary is re-downloadable. But
`pb_data/` holds the ledger — the thing that wins vendor disputes — and the
uploaded photos. If TrenchNote becomes the division's source of truth,
`pb_data/` on one SD card is the single point of failure.

### Rule one: never copy `pb_data/` while the server is running

SQLite keeps in-flight writes in sidecar files (`-wal`); a naive `cp` of a
live database can produce a corrupt copy that *looks* fine until you need
it. Use either of these instead:

### Method 1 — PocketBase's built-in backups (recommended)

Admin UI → **Settings → Backups**. PocketBase snapshots `pb_data/` into a
zip safely (it handles the database locking for you), on demand or on a
schedule — set the cron expression to e.g. `0 3 * * *` for nightly at 3am,
and keep several (e.g. max 7). The same settings screen can store backups
directly in any S3-compatible bucket (Backblaze B2, Wasabi, AWS), which
gets them **off the box** — a backup on the same SD card as the database
protects against nothing.

Restoring: Admin UI → Settings → Backups → restore on the zip. PocketBase
unpacks it and restarts itself.

### Method 2 — offsite copy of the backup zips

If you'd rather not hand PocketBase S3 credentials, ship the zips somewhere
else on a schedule. The built-in backups land in `pb_data/backups/`, so a
nightly cron on another machine (or the same one, pushing outward) works:

```sh
# e.g. on the office NAS / your workstation, in crontab -e:
# pull last night's backups from the trenchnote box at 4am
0 4 * * * rsync -a trenchnote@192.168.1.50:/opt/trenchnote/app/pb_data/backups/ ~/trenchnote-backups/
```

For a fully manual cold copy without the built-in system: stop the service
(`sudo systemctl stop trenchnote`), copy the whole `pb_data/` folder, start
it again. Fine for a pre-upgrade snapshot; too manual to be your only plan.

### Test the restore — once, now

A backup you have never restored is a hope, not a backup. Do the drill once:
on any spare machine, clone the repo, run `setup.sh`, unzip a backup into a
fresh `pb_data/` (or use the admin UI restore), start PocketBase, and check
that an asset page loads with its movement history intact. Ten minutes, and
now the recovery procedure is something you've done rather than something
you believe in.

## The reference topology: VPS primary + trailer Pi replica

This is the setup the maintainer runs (ADR 0006). One writable instance,
one ledger, and a Pi that exists to make the VPS expendable.

```
phones (cell data) ──HTTPS──▶ VPS: Caddy → PocketBase   (the ONLY writable instance)
                                   │
                                   ├─ Litestream ──▶ Pi   (continuous SQLite replication)
                                   ├─ rsync ───────▶ Pi   (pb_data/storage/ — uploaded photos)
                                   └─ PocketBase zip backups (second, independent layer)
```

The Pi is **never a peer**: it doesn't serve crews, and nothing syncs back.
It holds a warm copy of the ledger and doubles as a staging box. A site
with no cellular at all gets its own standalone TrenchNote install with its
own printed labels — not a synced copy of this one.

### Reaching the Pi from the VPS

Litestream *pushes* from the VPS, and a Pi in a trailer or office sits
behind NAT where the VPS can't see it. The boring fix is
[Tailscale](https://tailscale.com) on both machines — the Pi gets a stable
private address (e.g. `100.x.y.z`) reachable from the VPS with zero
firewall work. (Alternative if you'd rather run nothing extra: skip
Litestream and have the **Pi pull** the nightly backup zips instead —
`rsync` over SSH from the Pi to the VPS is outbound-only and NAT doesn't
care. You lose point-in-time recovery; you keep last-night's ledger.)

### Litestream on the VPS

Litestream streams every SQLite write to the replica — losing the VPS
costs you seconds of ledger, not a day. Install it on the VPS, then
`/etc/litestream.yml`:

```yaml
dbs:
  - path: /opt/trenchnote/app/pb_data/data.db
    replicas:
      - type: sftp
        host: 100.x.y.z:22          # the Pi's Tailscale address
        user: trenchnote
        key-path: /opt/trenchnote/.ssh/id_ed25519
        path: /home/trenchnote/replica/data.db
```

Enable its systemd service and check `litestream replicas` reports the Pi.
`data.db` is the one that matters (the whole ledger); `auxiliary.db` is
just request logs. Photos live outside SQLite, so add a cron on the VPS:

```sh
# crontab -e on the VPS — photos to the Pi, hourly
0 * * * * rsync -a /opt/trenchnote/app/pb_data/storage/ trenchnote@100.x.y.z:/home/trenchnote/replica/storage/
```

### The restore drill (mandatory, same rule as ever)

On the Pi, prove the replica is real — this is also exactly the procedure
for standing up a replacement VPS:

```sh
litestream restore -o /tmp/restore/data.db sftp://trenchnote@100.x.y.z:22/home/trenchnote/replica/data.db
# drop it into a fresh checkout's pb_data/ + copy storage/, start PocketBase,
# open an asset page, check the movement history is intact
```

### Staging on the Pi

Before upgrading PocketBase or applying a new migration on the VPS:
restore last night's ledger into a scratch `pb_data` on the Pi, run the
new binary/migration against it (`--dir` pointing at the scratch copy),
click through the pages. Ten minutes of rehearsal against real data, and
production upgrades stop being exciting.

## Quick reference

Day-two operations — restarts, logs, restores, password rotation, safe
PocketBase upgrades — live in [RUNBOOK.md](RUNBOOK.md).

| Task | Command |
|---|---|
| Status / logs | `systemctl status trenchnote` · `journalctl -u trenchnote -f` |
| Restart | `sudo systemctl restart trenchnote` |
| Update app | `git pull` then restart |
| Backup now | Admin UI → Settings → Backups → Create |
| Restore | Admin UI → Settings → Backups → ⟲ on the zip |
| Mesh URL (Option C) | `tailscale serve status` |
