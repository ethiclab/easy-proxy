# .agents/008-easy-proxy-uc1.md

> Handoff agente — easy-proxy UC1 Implementation
> Data: 2026-04-02
> Stato: UC1 IMPLEMENTATO — manca solo test reale IONOS + push Docker Hub

---

## Cosa è stato fatto in questa sessione

### Risultati

1. **Base image v2.0** (`ethiclab/nginx-certbot:2.0`) creata e testata:
   - Alpine + nginx 1.26.3 + bash + Node.js 20
   - certbot 5.4.0 + certbot-dns-ionos 2024.11.9 + route53, cloudflare, digitalocean
   - `ENTRYPOINT []` resettato (altrimenti CMD viene passato a certbot)
   - `Dockerfile.build` nel repo per rebuild

2. **`skeleton.py` (Python 2) → `skeleton.js` (Node.js, zero deps)**:
   - Stesso comportamento, zero dipendenze npm
   - Fix critico: unescape `\$` → `$` per variabili nginx (`$upstream`)
   - `add_subdomain_http/https` aggiornati per chiamare skeleton.js

3. **`easy proxy certbot-ionos <domain>`** implementato:
   - Legge credenziali da `pass ionos/api-key` / `pass ionos/api-secret`
   - Fallback su `IONOS_API_KEY` / `IONOS_API_SECRET` env vars
   - Genera `/etc/letsencrypt/ionos.ini` (chmod 600) nel container
   - Lancia `certbot --dns-ionos --non-interactive`

4. **Fix vari**:
   - `nginx.conf`: `user www-data` → `user nginx` (Alpine)
   - `docker exec -it` → `docker exec` per comandi non-interattivi
   - `package.json`: v2.0.0, zero dipendenze

5. **Documentazione completa**: CLAUDE.md, STATE.md, AGENTS.md, .github/copilot-instructions.md

### Test passati ✅

- Container parte e resta Up
- Vhost HTTP generato correttamente
- Vhost HTTPS generato correttamente (`$upstream` unescapato)
- nginx reload con vhost HTTP: OK
- nginx reload con vhost HTTPS senza cert: fallisce come atteso
- `certbot-ionos` senza dominio: errore corretto
- `certbot-ionos` senza credenziali: errore corretto

---

## File modificati in questa sessione

| File | Tipo |
|------|------|
| `Dockerfile` | modificato — base image 1.1 → 2.0 |
| `Dockerfile.build` | **nuovo** |
| `easyhome/skeleton.js` | **nuovo** |
| `easyhome/ionos-config-helper.sh` | **nuovo** |
| `easyhome/add_subdomain_http` | modificato — skeleton.py → skeleton.js |
| `easyhome/add_subdomain_https` | modificato — idem |
| `easyhome/nginx.conf` | modificato — user nginx |
| `commands/proxy.sh` | modificato — aggiunto certbot-ionos, rimosso -it |
| `package.json` | modificato — v2.0.0, zero deps |
| `CLAUDE.md` | aggiornato |
| `STATE.md` | aggiornato |
| `AGENTS.md` | **nuovo** |
| `.github/copilot-instructions.md` | **nuovo** |

---

## Cosa resta da fare

### Priorità 1 — Bloccante

```bash
# 1. Ottenere API key da https://developer.hosting.ionos.it/
#    → Account → API → Create API Key
pass insert ionos/api-key
pass insert ionos/api-secret

# 2. Test reale
cd ~/ethiclab/lab/easy-proxy
export EASY_DIR="$PWD"
export EASY_LETSENCRYPT_DIR="$HOME/.easy-proxy/letsencrypt"
export EASY_DOMAINS_DIR="$HOME/.easy-proxy/domains"
export EASY_LETSENCRYPT_EMAIL="admin@ethiclab.it"
export PATH="$EASY_DIR:$PATH"
easy proxy create
easy proxy certbot-ionos dev.ethiclab.it
# expected: cert in ~/.easy-proxy/letsencrypt/live/dev.ethiclab.it/
```

### Priorità 2 — Push immagine

```bash
docker login                   # credenziali Docker Hub ethiclab
docker push ethiclab/nginx-certbot:2.0

# Mirror GHCR (se ha GitHub token):
docker tag ethiclab/nginx-certbot:2.0 ghcr.io/ethiclab/nginx-certbot:2.0
docker push ghcr.io/ethiclab/nginx-certbot:2.0
```

### Priorità 3 — UC1 completo

```bash
# Dopo aver il cert dev.ethiclab.it:
easy proxy new https platform.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:8010
easy proxy new https onceapi.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:8011
easy proxy new https onceui.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:3000
easy proxy new https backoffice.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:3001
easy proxy reload

# Hosts
echo "127.0.0.1 platform.dev.ethiclab.it onceapi.dev.ethiclab.it onceui.dev.ethiclab.it backoffice.dev.ethiclab.it" | sudo tee -a /etc/hosts

# Test browser
open https://onceui.dev.ethiclab.it
```

### Priorità 4 — Phase 2

- Split-view DNS con dnsmasq: `*.dev.ethiclab.it → 127.0.0.1` (locale), IP pubblico (esterno)
- Register.it DNS provider: `pip install certbot-dns-register-it` + `easy proxy certbot-register`

---

## Prompt per prossimo agente

```
Stai lavorando su easy-proxy (lab/easy-proxy).

UC1 è IMPLEMENTATO. Leggi STATE.md per capire dove siamo.

Il prossimo step concreto è:
1. Configurare le credenziali IONOS in `pass` (Edu deve farlo manualmente)
2. Eseguire `easy proxy certbot-ionos dev.ethiclab.it` per il primo cert reale
3. Completare il setup UC1 (vhost ELEVEN + test browser)

Se Edu ha già fatto pass insert:
- Vai direttamente a `easy proxy create` + `easy proxy certbot-ionos`
- Poi `easy proxy new https` per ogni servizio ELEVEN
- Poi `/etc/hosts` + test browser

Se deve ancora configurare pass:
- Guida Edu su come ottenere API key da https://developer.hosting.ionos.it/
- Guida su `pass init` se non ancora configurato

Ambiente test senza IONOS (per verificare infrastruttura):
cd ~/ethiclab/lab/easy-proxy
export EASY_DIR="$PWD" EASY_LETSENCRYPT_DIR=~/.easy-proxy/letsencrypt EASY_DOMAINS_DIR=~/.easy-proxy/domains EASY_LETSENCRYPT_EMAIL=admin@ethiclab.it
export PATH="$EASY_DIR:$PATH"
easy proxy status        # container running?
easy proxy new http ...  # testa generazione vhost
easy proxy reload        # deve uscire senza errori
```
