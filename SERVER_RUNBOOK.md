# easy-proxy — Server Runbook (ethicserver)

> Recovery runbook for the managed proxy after a CLI upgrade and the certbot
> failures seen on 2026-06-09. Run as `root@ethicserver`.
> CLI target: **v2.3.2**

---

## TL;DR

```bash
# 1. Update the CLI
npm install -g 'git+https://github.com/ethiclab/easy-proxy.git#v2.3.2'
easy --version          # → 2.3.2

# 2. Recreate the container (fixes the broken bind mount + loads the valid cert)
easy proxy destroy && easy proxy create

# 3. (Recommended) Switch to an auto-renewing IONOS wildcard cert
easy proxy certbot-ionos ethiclab.it
easy proxy reload
```

Then reload `https://www.ethiclab.it` in the browser — it should be valid.

---

## Background — what broke

Three failures, all surfaced after the container image's certbot drifted
(`FROM certbot/certbot:latest`) and the CLI was upgraded:

| Symptom | Root cause | Fixed by |
|---------|-----------|----------|
| `certbot: error: unrecognized arguments: --manual-public-ip-logging-ok` | Flag removed from modern certbot | CLI v2.3.1 (#35) |
| `certbot: error: ambiguous option: --dns-ionos` | Bare `--dns-ionos` selector is now an ambiguous prefix | CLI v2.3.1 (#35) — uses `--authenticator dns-ionos` |
| `Missing properties in credentials configuration file /etc/letsencrypt/ionos.ini` | Plugin dropped `dns_ionos_api_key`/`api_secret` keys | CLI v2.3.2 (#36) — writes `dns_ionos_prefix`/`secret`/`endpoint` |
| `nginx: [emerg] open() "/usr/local/share/easy/nginx.conf" failed` on `reload` | `npm install -g` rewrote `easyhome/` while the container was up, breaking its bind mount | Recreate the container (step 2) |

Note: the manual `easy proxy certbot` run **succeeded** and produced a valid
cert at `/etc/letsencrypt/live/ethiclab.it/` (covers `ethiclab.it` +
`*.ethiclab.it`, so `www.` is covered). The browser kept showing
`ERR_CERT_DATE_INVALID` only because nginx never reloaded onto it.

---

## Step-by-step

### 1. Update the CLI

```bash
npm install -g 'git+https://github.com/ethiclab/easy-proxy.git#v2.3.2'
easy --version          # must print 2.3.2
```

> `easy proxy --version` just prints the subcommand list — use `easy --version`.

### 2. Recreate the container

Required after any `npm install -g` upgrade: the proxy bind-mounts the CLI's
`easyhome/` directory, and reinstalling replaces it on disk, so a running
container ends up pointing at a stale (deleted) directory. A plain `reload` is
not enough.

```bash
easy proxy destroy && easy proxy create
```

Certs and vhosts live in host volumes (`EASY_LETSENCRYPT_DIR`,
`EASY_DOMAINS_DIR`), so nothing is lost. `create` auto-runs `easy proxy verify`.

Reload `https://www.ethiclab.it` — it should now be valid (served by the cert
from the manual run).

### 3. (Recommended) Auto-renewing IONOS wildcard cert

The manual cert does **not** auto-renew. Replace it with an IONOS DNS-01 cert,
which does:

```bash
easy proxy certbot-ionos ethiclab.it
easy proxy reload
```

This writes `/etc/letsencrypt/ionos.ini` in the format the current plugin needs:

```ini
dns_ionos_prefix   = <ionos/api-key>      # IONOS "Public Prefix"
dns_ionos_secret   = <ionos/api-secret>   # IONOS "Secret"
dns_ionos_endpoint = https://api.hosting.ionos.com
```

Credentials come from `pass` (`ionos/api-key`, `ionos/api-secret`) or the env
vars `IONOS_API_KEY` / `IONOS_API_SECRET`. The endpoint can be overridden with
`IONOS_API_ENDPOINT`.

---

## Troubleshooting

| Problem | What to do |
|---------|-----------|
| A site stops responding after `destroy && create` | Backends are on Docker networks the new container didn't join. Run `easy proxy recover`, or set `EASY_PROXY_NETWORK` before `create`. |
| `certbot-ionos` returns 401/403 (auth), not "missing properties" | The stored `ionos/api-key` / `ionos/api-secret` are swapped or combined. The IONOS key is `prefix.secret`: `api-key` = prefix, `api-secret` = secret. Re-store them correctly. |
| `easy proxy reload` still fails after upgrade | You skipped step 2 — recreate the container. |
| `easy proxy rfc2136` → "target DNS server ... is not a valid IPv4/IPv6 address" | Server-side config, not a CLI bug. In `/etc/letsencrypt/secret.txt` set `dns_rfc2136_server` to an **IP** (resolve the hostname with `dig +short <host>`), and `chmod 600 /etc/letsencrypt/secret.txt`. |
| General health check | `easy proxy verify` (is it up?) · `easy proxy doctor` (read-only diagnosis) · `easy proxy log` (container logs). |

---

## Verify the certificate

```bash
# From the server
openssl x509 -in /etc/letsencrypt/live/ethiclab.it/cert.pem -noout -dates -subject

# From anywhere
echo | openssl s_client -connect www.ethiclab.it:443 -servername www.ethiclab.it 2>/dev/null \
  | openssl x509 -noout -dates -subject
```

---

_Last updated: 2026-06-09 · See also [CLAUDE.md](CLAUDE.md), [STATE.md](STATE.md), [UC1_LOCAL_SSL_SETUP.md](UC1_LOCAL_SSL_SETUP.md)_
