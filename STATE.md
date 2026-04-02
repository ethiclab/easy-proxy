# easy-proxy — STATE.md

> Stato attuale e blocchi del progetto
> Aggiornato: 2026-04-02

---

## Versione corrente

| Aspetto | Valore |
|---------|--------|
| **Versione** | 2.0.0 (npm: `@ethiclab/easy-cli`) |
| **Branch** | `master` |
| **Ultimo commit** | 2026-04-02 — UC1 completo (IONOS DNS automation) |
| **Remote** | `git@github.com:ethiclab/easy-proxy.git` |
| **Base image** | `ethiclab/nginx-certbot:2.0` (locale, da pushare) |

---

## WIP corrente

| Task | Stato | Note |
|------|-------|------|
| **UC1: IONOS DNS automation** | ✅ IMPLEMENTATO | `easy proxy certbot-ionos <domain>` funzionante |
| **skeleton.py → skeleton.js** | ✅ COMPLETATO | Zero dipendenze, unescape `\$` fix incluso |
| **Base image v2.0** | ✅ BUILD OK | Da pushare a Docker Hub + ghcr.io |
| **Test locali UC1** | ✅ PASSATI | container, vhost HTTP/HTTPS, reload, error paths |
| **Test reale IONOS** | 🔴 PENDING | Richiede API key IONOS in `pass` |
| **Push Docker Hub** | 🟡 PENDING | `docker push ethiclab/nginx-certbot:2.0` |

---

## Blocchi attivi

| Blocco | Gravità | Next step |
|--------|---------|-----------|
| **API key IONOS non ancora in `pass`** | 🔴 BLOCCANTE per test reale | `pass insert ionos/api-key` + `pass insert ionos/api-secret` dalla console IONOS |
| **Base image non su Docker Hub** | 🟡 MEDIO | `docker login && docker push ethiclab/nginx-certbot:2.0` |

---

## Test completati (2026-04-02)

| Test | Risultato |
|------|-----------|
| `easy proxy create` — container Up | ✅ |
| `easy proxy new http` — vhost generato | ✅ |
| `easy proxy new https` — template corretto (`$upstream` unescapato) | ✅ |
| `easy proxy reload` con vhost HTTP | ✅ |
| `easy proxy reload` con vhost HTTPS senza cert | ✅ fallisce come atteso |
| `easy proxy certbot-ionos` senza dominio | ✅ errore corretto |
| `easy proxy certbot-ionos` senza credenziali | ✅ errore corretto |
| `easy proxy destroy` | ✅ |

---

## Modifiche significative v2.0.0

| File | Modifica |
|------|----------|
| `Dockerfile` | `FROM ethiclab/nginx-certbot:1.1` → `2.0` |
| `Dockerfile.build` | Nuova base image da zero: Alpine + nginx 1.26 + bash + Node 20 + certbot-dns-ionos |
| `easyhome/skeleton.js` | **NUOVO** — sostituisce skeleton.py (Python 2); zero deps; fix `\$` unescape |
| `easyhome/nginx.conf` | `user www-data` → `user nginx` (Alpine) |
| `easyhome/add_subdomain_http/https` | Chiama `skeleton.js` invece di `skeleton.py` |
| `easyhome/ionos-config-helper.sh` | **NUOVO** — helper per creare `/etc/letsencrypt/ionos.ini` |
| `commands/proxy.sh` | **NUOVO** `certbot-ionos` subcommand; rimosso `-it` da exec non-interattivi |
| `package.json` | v1.0.24 → 2.0.0; zero dipendenze npm |

---

## Prossimi step (ordine priorità)

1. **Ottenere API key IONOS** dal pannello → `pass insert ionos/api-key`
2. **Test reale**: `easy proxy certbot-ionos dev.ethiclab.it`
3. **Push Docker Hub**: `docker push ethiclab/nginx-certbot:2.0`
4. **Setup `/etc/hosts`** per test browser con ELEVEN locale
5. **Split-view DNS** con dnsmasq (Phase 2)

---

## Prossima sessione — handoff

Vedi `.agents/008-easy-proxy-uc1.md` per context completo.

```bash
# Quick resume:
cd ~/ethiclab/lab/easy-proxy
export EASY_DIR="$PWD"
export EASY_LETSENCRYPT_DIR="$HOME/.easy-proxy/letsencrypt"
export EASY_DOMAINS_DIR="$HOME/.easy-proxy/domains"
export EASY_LETSENCRYPT_EMAIL="admin@ethiclab.it"
export PATH="$EASY_DIR:$PATH"
easy proxy status   # container running?
```
