# easy-proxy — Server Runbook

> Operating easy-proxy on a production host: upgrades, certificates, automatic
> renewal, connecting app stacks. Commands run as root on the host.
> CLI target: **v2.3.2**
>
> Keep deployment-specific details (hostnames, IPs, which sites run where,
> credentials) in a private ops repo, not here.

---

## TL;DR — upgrade the CLI

```bash
npm install -g 'git+https://github.com/ethiclab/easy-proxy.git#v2.3.2'
easy --version                       # → 2.3.2 (easy proxy --version only lists subcommands)
easy proxy destroy && easy proxy create
```

Recreating is **required** after any `npm install -g`: the proxy bind-mounts the
CLI's `easyhome/`, reinstalling replaces it on disk, and the running container
keeps pointing at the deleted directory (`reload` fails with
`nginx: [emerg] open() "/usr/local/share/easy/nginx.conf" failed`). Certs and
vhosts live in host volumes, so nothing is lost. `create` auto-runs `easy proxy verify`.

---

## Host layout

| Container path | Host path | Notes |
|---|---|---|
| `/domains` | `$EASY_DOMAINS_DIR` | vhosts. No secrets — keep it under git (see below) |
| `/etc/letsencrypt` | `$EASY_LETSENCRYPT_DIR` | certs, keys, ACME account, DNS credentials. `/etc/letsencrypt` usually does **not** exist on the host |
| `/var/www/certbot` | anonymous volume | HTTP-01 webroot, shared by nginx and certbot in the same container |

Non-interactive SSH shells often don't load the `EASY_*` exports: use literal
host paths there, and run certbot/nginx through `docker exec easy-proxy ...`
(nginx needs `-c /usr/local/share/easy/nginx.conf`).

### Version the vhosts, never the certificates

```bash
cd "$EASY_DOMAINS_DIR" && git init -b main && git add -A && git commit -m "baseline: vhosts as found"
```

Change flow: edit → `docker exec easy-proxy nginx -c /usr/local/share/easy/nginx.conf -t`
→ `easy proxy reload` → `curl` every site → `git commit`.

> ⚠️ Never `git add -A` in `$EASY_LETSENCRYPT_DIR`, not even for a private repo: it
> holds private keys, the ACME account key and DNS credentials. To version certbot
> config, use a separate repo with an allowlist (`renewal/*.conf`, `renewal-hooks/`)
> and back up secrets with encryption.

---

## Certificates — pick the challenge by DNS provider

| DNS provider | Challenge | Command | Wildcard | Auto-renews |
|---|---|---|---|---|
| IONOS | DNS-01 | `easy proxy certbot-ionos <domain>` | yes | yes |
| Route53 / Cloudflare / DigitalOcean | DNS-01 | plugin in the image (`--authenticator dns-<name>`) | yes | yes |
| Anything else (e.g. Aruba) | **HTTP-01 webroot** | see below | no | yes |
| — | DNS-01 manual | `easy proxy certbot` | yes | **no — avoid in production** |

A manual lineage cannot renew non-interactively and makes every `certbot renew`
run fail (see below). Wildcards need DNS-01; without a plugin, prefer apex + the
names you actually use over HTTP-01. If a wildcard is truly needed, move the zone's
nameservers to a supported provider (the registrar can stay). A CNAME delegation of
`_acme-challenge` does **not** work with `certbot-dns-ionos` as-is: it picks the
zone from the certificate domain and does not follow CNAMEs.

### IONOS credentials

`easy proxy certbot-ionos` regenerates `/etc/letsencrypt/ionos.ini` on every run
from `pass` (`ionos/api-key`, `ionos/api-secret`) or `IONOS_API_KEY` /
`IONOS_API_SECRET`. The IONOS key is `prefix.secret`: `api-key` = prefix,
`api-secret` = secret. Check them without touching Let's Encrypt:
`curl -s -H "X-API-Key: <prefix>.<secret>" https://api.hosting.ionos.com/dns/v1/zones`.

### HTTP-01 webroot (no DNS plugin)

1. Port-80 vhost in `$EASY_DOMAINS_DIR/<domain>/http.<domain>.conf`:
   ```nginx
   server {
    listen 80;
    server_name example.com www.example.com;
    location ^~ /.well-known/acme-challenge/ { root /var/www/certbot; default_type text/plain; }
    location / { return 301 https://$host$request_uri; }
   }
   ```
2. Reload, then probe through public DNS:
   ```bash
   docker exec easy-proxy sh -c 'mkdir -p /var/www/certbot/.well-known/acme-challenge && echo ok > /var/www/certbot/.well-known/acme-challenge/probe'
   curl -s http://example.com/.well-known/acme-challenge/probe   # → ok
   ```
3. Issue. To convert an existing (e.g. manual) lineage in place, reuse its
   `--cert-name`: `live/<name>/` paths stay the same, and no `<name>-0001` appears.
   Copy the old `renewal/<name>.conf` to `renewal.disabled/` first, as a record.
   ```bash
   docker exec easy-proxy certbot certonly --non-interactive --agree-tos \
     --webroot -w /var/www/certbot --cert-name example.com \
     -d example.com -d www.example.com --dry-run    # then without --dry-run
   ```
4. Port-443 vhost. The `easy proxy new https` template has no WebSocket headers,
   so hand-write it when the app needs them. Keep `set $upstream ...; proxy_pass $upstream;`
   with `resolver 127.0.0.11`, so a stopped backend gives that site a 502 instead of
   keeping nginx from starting.

---

## Automatic renewal

Two decoupled pieces:

1. **Deploy hook** — `$EASY_LETSENCRYPT_DIR/renewal-hooks/deploy/reload-nginx.sh`, `chmod +x`:
   ```sh
   #!/bin/sh
   nginx -c /usr/local/share/easy/nginx.conf -s reload
   ```
   Runs inside the container, only when a cert actually renewed. Without the
   executable bit certbot skips it silently. Export `EASY_LETSENCRYPT_DIR` before
   creating it, or it lands in `/renewal-hooks` on the host root.
2. **systemd timer**, twice daily (renew is a no-op until 30 days before expiry):

   `/etc/systemd/system/easy-proxy-certbot-renew.service`
   ```ini
   [Unit]
   Description=Renew easy-proxy Let's Encrypt certificates
   Requires=docker.service
   After=docker.service

   [Service]
   Type=oneshot
   ExecStart=/usr/bin/docker exec easy-proxy certbot renew --quiet
   ```
   `/etc/systemd/system/easy-proxy-certbot-renew.timer`
   ```ini
   [Unit]
   Description=Run easy-proxy certbot renew twice daily

   [Timer]
   OnCalendar=*-*-* 03,15:00:00
   RandomizedDelaySec=3600
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```
   ```bash
   systemctl daemon-reload && systemctl enable --now easy-proxy-certbot-renew.timer
   ```

`certbot renew` walks **every** `renewal/*.conf` and exits non-zero if any single
lineage fails. One `authenticator = manual` lineage turns the service `failed` on
every run, which hides real failures. Move dead lineages to `renewal.disabled/`
(`mv`, not `certbot delete`). Certificates issued outside this container (another
certbot, copied files) have no `renewal/` entry and **never renew** — list
`live/` against `renewal/` to spot them.

```bash
systemctl list-timers easy-proxy-certbot-renew.timer --all        # NEXT has a date
systemctl start easy-proxy-certbot-renew.service
systemctl status easy-proxy-certbot-renew.service --no-pager      # status=0/SUCCESS
docker exec easy-proxy certbot renew --dry-run                    # exit 0, all lineages
docker exec easy-proxy sh -c 'ls /etc/letsencrypt/live; ls /etc/letsencrypt/renewal'
```

---

## Connecting an app stack to the proxy

- Set `EASY_PROXY_NETWORK` (the edge network) before `easy proxy create`.
- Attach **only** the entry container (usually the frontend) to the edge network,
  in an explicitly named override (e.g. `docker-compose.<edge>.yml`) added to the
  production `-f` list. `docker-compose.override.yml` is ignored as soon as any
  `-f` is passed.
- Compose registers service names (`backend`, `frontend`, `db`, `api`) as aliases
  on every network the service joins, so several stacks on the edge network end up
  sharing the same generic names. Inside a container attached to the edge network,
  refer to siblings by their unique `container_name`.
- Don't publish 80/443 from the app stack: they belong to easy-proxy.

---

## Troubleshooting

| Problem | What to do |
|---------|-----------|
| `certbot: error: unrecognized arguments: --manual-public-ip-logging-ok` / `ambiguous option: --dns-ionos` | CLI older than 2.3.1 against a modern certbot image — upgrade the CLI |
| `Missing properties in credentials configuration file .../ionos.ini` | CLI older than 2.3.2 (old key names) — upgrade, then rerun `certbot-ionos` |
| `certbot-ionos` returns 401/403 | `ionos/api-key` / `ionos/api-secret` swapped or combined — see IONOS credentials |
| `reload` fails with `open() "/usr/local/share/easy/nginx.conf" failed` | CLI reinstalled while the container was running — `easy proxy destroy && easy proxy create` |
| A site returns 502 | Backend down or not on the edge network: `docker exec easy-proxy getent hosts <container>` |
| A site stops responding after `destroy && create` | Backends are on networks the new container didn't join: `easy proxy recover`, or set `EASY_PROXY_NETWORK` |
| Renewal service is `failed` | `journalctl -u easy-proxy-certbot-renew.service` — usually one broken or manual lineage |
| `easy proxy rfc2136` → "target DNS server ... is not a valid IPv4/IPv6 address" | In `/etc/letsencrypt/secret.txt` set `dns_rfc2136_server` to an **IP**, `chmod 600` |
| General health check | `easy proxy verify` · `easy proxy doctor` · `easy proxy log` |

---

## Verify a certificate

```bash
openssl x509 -in "$EASY_LETSENCRYPT_DIR/live/<domain>/cert.pem" -noout -dates -subject
echo | openssl s_client -connect <host>:443 -servername <host> 2>/dev/null | openssl x509 -noout -dates -subject
```

---

_Last updated: 2026-09-10 · See also [CLAUDE.md](CLAUDE.md), [STATE.md](STATE.md), [UC1_LOCAL_SSL_SETUP.md](UC1_LOCAL_SSL_SETUP.md)_
