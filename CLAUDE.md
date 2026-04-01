# easy-proxy — CLAUDE.md

> Dynamic nginx reverse proxy CLI with integrated Let's Encrypt SSL
> Status: **ACTIVE** (riprendere e modernizzare)
> Ultima build: v1.0.24 (2021-11-17)

---

## 1. Cos'è easy-proxy

**Scopo**: CLI Node.js che orchestra container Docker con nginx per esporre servizi interni su sottodomini pubblici con SSL/TLS automatico via Let's Encrypt.

**Problema che risolve**: Gestire multiple vhost nginx + certificati SSL senza configurazione manuale.

**Esempio workflow**:
```bash
easy proxy create                                    # Avvia container nginx
docker run nginx server1                              # Container con app
docker network connect network1 server1              # Connetti a network
easy proxy new http server1.example.com example.com http://server1:80
easy proxy certbot                                   # Genera SSL
easy proxy reload                                    # Ricarica nginx
# → server1.example.com raggiungibile con HTTPS automatico
```

**Chi lo usa**: Network admin, DevOps, developer per test environment con SSL realistico.

---

## 2. Architettura

### 2.1 Struttura repository

```
easy-proxy/
├── easy                           # Entry point bash (CLI orchestrator)
├── commands/
│   └── proxy.sh                   # Implementazione del comando `easy proxy`
├── easyhome/                      # Template + config nginx
│   ├── nginx.conf                 # Main config (include /domains/*/*.conf)
│   ├── common.conf                # Snippet condiviso
│   ├── templates/                 # Template per vhost http/https
│   │   ├── http.conf
│   │   ├── http.default.conf
│   │   ├── https.conf
│   │   └── https.default.conf
│   ├── add_subdomain_http         # Script per aggiungere vhost
│   ├── add_subdomain_https
│   ├── add_domain
│   ├── easy-proxy-start           # Entrypoint del container
│   └── options-ssl-nginx.conf     # Opzioni SSL/TLS
├── package.json                   # Meta npm (bin: easy)
├── Dockerfile                     # Build image (usa base ethiclab/nginx-certbot:1.1)
└── README.md
```

### 2.2 Flusso dell'applicazione

```
UTENTE LOCALE (dev)
    │
    ├─ npm install -g @ethiclab/easy-cli
    │
    └─ easy [command] [args]
        ↓
        bash easy script
        │
        ├─ dispatcher: ruby/python/shell?
        │
        └─ source commands/proxy.sh
            └─ __easy_command_proxy_[subcommand]
                ├─ create    → docker run ethiclab/nginx-easy
                ├─ new       → docker exec add_subdomain_{http|https}
                ├─ certbot   → docker exec certbot --email --manual
                ├─ reload    → docker exec nginx -s reload
                ├─ logs      → docker logs -f
                ├─ status/id → cat .id or docker ps
                └─ destroy   → docker stop + rm
                    ↓
                CONTAINER DOCKER (ethiclab/nginx-certbot:1.1)
                    │
                    ├─ nginx (www-data)
                    │   └─ client_max_body_size: 5GB
                    │   └─ include /domains/*/*.conf
                    │
                    ├─ certbot + rfc2136 DNS solver
                    │
                    └─ volumes:
                       ├─ /domains → EASY_DOMAINS_DIR (local)
                       ├─ /etc/letsencrypt → EASY_LETSENCRYPT_DIR (local)
                       └─ /usr/local/share/easy → easyhome/ (repo)
```

### 2.3 Dipendenze

**Runtime**:
- `bash` / `zsh` (CLI orchestrator)
- Docker CLI (per docker run/exec/logs)
- Node.js (solo per bin mapping — non eseguito)
- `which`, `date` (POSIX utilities)

**Container base**:
- `ethiclab/nginx-certbot:1.1` — **CRITICO**: container custom prebuildo
  - Contiene: nginx, certbot, rfc2136 DNS plugin, sudo, CA certs
  - Nessun link pubblico trovato — va rebuild da `Dockerfile` oppure ricreato

**Environment variables (OBBLIGATORI)**:
```bash
export EASY_DIR=$(dirname $(realpath $(which easy)))        # Auto set, ma usato
export EASY_LETSENCRYPT_DIR=/path/to/letsencrypt/persist  # Obbligatorio
export EASY_DOMAINS_DIR=/path/to/domains/config            # Obbligatorio
export EASY_LETSENCRYPT_EMAIL=admin@example.com            # Per certbot
export EASY_LETSENCRYPT_DOMAIN=example.com                 # Per rfc2136
```

---

## 3. Comandi disponibili

| Comando | Sottocmd | Effetto |
|---------|----------|--------|
| `easy --version` | — | Stampa versione da package.json |
| `easy proxy help` | — | Stampa help |
| `easy proxy create` | — | Avvia container docker (salva ID in `.id`) |
| `easy proxy build` | — | Build image da Dockerfile → `ethiclab/nginx-easy` |
| `easy proxy new` | `[http\|https] <fqdn> <domain> <target>` | Aggiunge vhost |
| `easy proxy certbot` | — | Richiede certificato a Let's Encrypt (manual mode) |
| `easy proxy rfc2136` | — | Certificato con DNS-01 via RFC2136 |
| `easy proxy status` | — | Docker PS: mostra se container è running |
| `easy proxy id` | — | Cat `.id` (Docker container ID) |
| `easy proxy start` | — | `docker start` |
| `easy proxy stop` | — | `docker stop` |
| `easy proxy restart` | — | `docker restart` |
| `easy proxy reload` | — | `docker exec nginx -s reload` |
| `easy proxy sh` | — | `docker exec -it bash` |
| `easy proxy log` | — | `docker logs -f` |
| `easy proxy destroy` | — | Stop + rm + clean `.id` |

---

## 4. Use case attuali (Edu)

### 4.1 Scenario: EthicLab cluster locale con SSL

**Situazione attuale**: Eleven/BGOL/ETICA girano in `localhost:<porta>`.
- Sviluppatori testano in HTTP locale
- Client demo necessitano HTTPS + vhost veri (es. `platform.demo.ethiclab.it`)
- Let's Encrypt per cert reali (non self-signed)

**Con easy-proxy**:
```bash
# Setup una volta
export EASY_LETSENCRYPT_DIR=~/certs
export EASY_DOMAINS_DIR=~/domains
easy proxy create              # Container nginx → ports 80/443

# Aggiungere servizio Eleven platform
docker network create ethiclab
docker run -d --name platform --network ethiclab -p 8010:8010 <eleven-platform>
easy proxy new https platform.demo.ethiclab.it demo.ethiclab.it http://platform:8010
easy proxy certbot

# → https://platform.demo.ethiclab.it raggiungibile con cert SSL valido
```

**Vantaggi**:
- Singolo proxy per tutti i servizi cluster
- SSL/TLS trasparente (auto-renew certbot ogni 90gg)
- Config vhost in `/domains/demo.ethiclab.it/*.conf` (tracciabile in git)
- Load balancing opzionale (nginx upstream blocks)

### 4.2 Scenario: Demo/roadshow con sottodomini temporanei

**Situazione**: Evento domani, clienti vedono feature Eleven su `https://vendor-X.demo.ethiclab.it`

**Con easy-proxy**:
```bash
# Veloce: 2 minuti
easy proxy new https vendor-X.demo.ethiclab.it demo.ethiclab.it http://platform-staging:8010
easy proxy reload
# Fatto. Client vede nome reale + SSL.

# Dopo: cleanup
easy proxy destroy              # Remove all
rm -rf ~/domains ~/certs
```

### 4.3 Scenario: Migrazione cloud (future)

**Oggi**: easy-proxy Docker locale.
**Domani**: Traefik / OIDC proxy in AWS per prod.

easy-proxy rimane per:
- Dev locale con SSL
- Staging/test in piccola infra (VPS singolo)
- Learning tool (capire nginx/Let's Encrypt)

---

## 5. Stack tecnico

| Componente | Versione | Note |
|-----------|----------|------|
| Node.js | (any) | Solo bin mapping, non eseguito |
| Bash | POSIX | CLI orchestrator |
| Docker | 20.10+ | Obbligatorio |
| nginx | (in container) | Da base image ethiclab/nginx-certbot:1.1 |
| certbot | (in container) | DNS-01 (rfc2136), manual |
| Python | (in container) | Certbot dependency |

**Compatibilità OS**:
- Linux: ✅ (primary)
- macOS: ⚠️ (necessita `gdate` gnu-tools)
- Windows: ❌ (Bash nativo, no Hyper-V proxy)

---

## 6. Problemi noti / gap

| Problema | Severità | Note |
|----------|----------|------|
| **Base image persa** | 🔴 CRITICO | `ethiclab/nginx-certbot:1.1` non trovato su Docker Hub — va rebuild o ricreato |
| **Dipendenza da EASY_DOMAINS_DIR/EASY_LETSENCRYPT_DIR** | 🟡 MEDIO | Non automatizzato in setup — richiede manual env config |
| **No test automatizzati** | 🟡 MEDIO | package.json: `"test": "echo \"Error: no test specified\""` |
| **Niente sidekick monitoring** | 🟠 BASSO | Niente health check container, niente auto-restart |
| **Single proxy instance** | 🟠 BASSO | `.id` è singleton — una sola istanza proxy locale (OK per dev) |
| **No reload protection** | 🟠 BASSO | `easy proxy reload` senza validation pre-reload |
| **Python 2/3 ambiguità** | 🟡 MEDIO | `skeleton.py` nel repo ma mai usato — serve? |

---

## 7. Roadmap miglioramento

### Fase 1: Foundation (2 giorni)
- [ ] Rebuild / discover base image `ethiclab/nginx-certbot:1.1`
- [ ] Test locale `easy proxy create` → `easy proxy new http` → `easy proxy status`
- [ ] Aggiornare README.md con quick-start moderno
- [ ] Aggiungere `./.env.example` per EASY_* variables

### Fase 2: Modernizzazione (3-4 giorni)
- [ ] CLI rewrite: bash → **Node.js/TypeScript** (oclif o commander.js)
  - Migliore di gestione error, logging, piping
  - Easier testing (Jest)
- [ ] Add unit tests (Jest) per comandi critici
- [ ] Docker Compose alternativo per setup semplificato
- [ ] Health check container + auto-restart policy

### Fase 3: Production readiness (4-5 giorni)
- [ ] Metrics: prometheus endpoint /metrics (nginx + certbot)
- [ ] Logging: ECS/JSON format per container logs
- [ ] Multi-instance proxy pattern (load balance between proxies)
- [ ] Graceful reload: validazione config pre-reload

### Fase 4: Integration (future)
- [ ] Integration con `devel/bin/mini`? (es. `mini proxy create`)
- [ ] Terraform module per deploy in AWS ECS/ALB
- [ ] GitOps: domains config sync da git

---

## 8. File cruciali

| File | Ruolo |
|------|-------|
| `easy` | Entry point CLI — leggi qui per capire dispatcher |
| `commands/proxy.sh` | 150 linee, logica principale, router subcommand |
| `easyhome/nginx.conf` | Main nginx config (semplicissima: include /domains/*) |
| `easyhome/add_subdomain_http` | Script che genera vhost config da template |
| `easyhome/templates/*.conf` | Template vhost http/https — studiare per capire variabili |
| `Dockerfile` | Build image, dipende **non disponibile** `ethiclab/nginx-certbot:1.1` |

---

## 9. Prossimi step

1. **Subito**: Dove è la base image `ethiclab/nginx-certbot:1.1`?
   - Se in Docker Hub → test pull locale
   - Se persa → rebuild da source (Env Dockerfile) o locate.sh
   - Se mai esistita → crearla (nginx + certbot + rfc2136)

2. **Quick test**:
   ```bash
   cd lab/easy-proxy
   npm install -g .                            # Installa easy CLI locale
   easy --version                              # Test basic
   easy proxy help                             # List comandi
   ```

3. **Documentazione**:
   - README aggiornato
   - `.env.example` template
   - [OPTIONAL] Arch diagram (draw.io?

4. **Decidere**: Easy-proxy per quale cluster / uso case è PRIORITARIO?
   - Eleven (dev env)?
   - BGOL (game-api)?
   - Shared lab tool per demo?

---

## 10. Referenze

- Original inspiration: https://github.com/jwilder/nginx-proxy
- Certbot rfc2136 DNS plugin: https://certbot-dns-rfc2136.readthedocs.io/
- Let's Encrypt wildcard: https://letsencrypt.org/docs/faq/

---

**Creato**: 2026-04-01
**Aggiornato da**: Claude (sessione ripresa easy-proxy)
**Stato**: DRAFT — attende test locale e rebuilding base image
