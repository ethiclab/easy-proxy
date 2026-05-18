# easy-proxy — CLAUDE.md

> Nginx reverse proxy CLI con Let's Encrypt SSL automation e multi-DNS provider.
> Stato: **ATTIVO** — v2.2.0
> Ultimo aggiornamento: 2026-05-18

---

## 0. Primo passo obbligatorio

```bash
cd ~/ethiclab/lab/easy-proxy
cat STATE.md                    # stato WIP e blocchi attivi
easy proxy status               # container running?
```

---

## 1. Cos'è e perché esiste

CLI bash+Docker che:
1. Avvia un container nginx con certbot preinstallato
2. Genera vhost nginx da template (`easy proxy new http|https ...`)
3. Richiede certificati SSL Let's Encrypt via DNS-01 automatico (**IONOS API**)

**Usecase primario (UC1)**: dev locale ELEVEN/BGOL con HTTPS valido e nomi reali (`platform.dev.ethiclab.it`) invece di `localhost:8010`.

---

## 2. Architettura corrente (v2.0.0)

```
easy (bash entry point)
 └─ dispatcher: .sh / .py / .rb
     └─ commands/proxy.sh
         └─ __easy_command_proxy_[subcommand]
             ├─ create          → docker run ethiclab/nginx-easy
             ├─ new http|https  → docker exec add_subdomain_{http|https}
             │                       └─ skeleton.js (template renderer, zero deps)
             ├─ certbot-ionos   → certbot --dns-ionos (auto TXT record via IONOS API)
             ├─ certbot         → certbot --manual (interattivo, TXT a mano)
             ├─ rfc2136         → certbot/dns-rfc2136 (TSIG DNS)
             ├─ reload          → docker exec nginx -s reload
             └─ ...

CONTAINER: ethiclab/nginx-easy   (Dockerfile self-contained, un solo build)
 └─ FROM certbot/certbot:latest   (immagine pubblica ufficiale)
     ├─ nginx (Alpine)
     ├─ bash, Node 20
     ├─ certbot + certbot-dns-ionos
     ├─ certbot-dns-route53, cloudflare, digitalocean
     └─ ENTRYPOINT []   ← resettato (non eredita certbot entrypoint)

VOLUMI (host → container):
 EASY_DOMAINS_DIR     → /domains         (vhost .conf generati)
 EASY_LETSENCRYPT_DIR → /etc/letsencrypt (certificati persistenti)
 easyhome/            → /usr/local/share/easy (templates, scripts, skeleton.js)
```

### Flusso template

```
easy proxy new https myapp.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:8010
  └─ docker exec add_subdomain_https myapp.dev.ethiclab.it dev.ethiclab.it http://...
      └─ skeleton.js -t templates/https.conf --server_name ... --domain ...
          └─ sostituisce $server_name, $domain, $location_path, $location_target
          └─ unescape \$ → $ (per variabili nginx come $upstream)
          └─ output → /domains/dev.ethiclab.it/https.myapp.dev.ethiclab.it.conf
```

---

## 3. Setup locale (Quick Start)

### Prerequisiti

```bash
docker --version       # 20.10+
node --version         # qualsiasi (solo per bin easy)
shellcheck --version   # 0.11.0 — linter shell, pinned in CI (brew install shellcheck)
```

### Lint

```bash
npm run lint    # shellcheck su easy, commands/*.sh, easyhome/* shell, .husky/pre-push
```

Lo script `lint` è eseguito anche dal hook `.husky/pre-push`. I file con finding pre-esistenti
hanno una direttiva `# shellcheck disable=` baselined (vedi issue #8 per la pulizia).

### Installazione

```bash
cd ~/ethiclab/lab/easy-proxy
npm install -g .           # installa 'easy' nel PATH
# oppure usa path diretto:
export PATH="$HOME/ethiclab/lab/easy-proxy:$PATH"
```

### Environment variables (obbligatorie)

```bash
export EASY_DIR="$HOME/ethiclab/lab/easy-proxy"
export EASY_LETSENCRYPT_DIR="$HOME/.easy-proxy/letsencrypt"
export EASY_DOMAINS_DIR="$HOME/.easy-proxy/domains"
export EASY_LETSENCRYPT_EMAIL="admin@ethiclab.it"
mkdir -p "$EASY_LETSENCRYPT_DIR" "$EASY_DOMAINS_DIR"
```

Aggiungi queste righe a `~/.zshrc` o `~/.bashrc` per averle sempre disponibili.

Opzionale — `EASY_PROXY_NETWORK`: se impostata, `easy proxy create` aggancia il
container a quella rete Docker (creata se non esiste) e ricrearlo non perde la
connettività verso i backend. I siti si collegano con `easy proxy attach`.

### Build immagine locale

Il `Dockerfile` è self-contained (`FROM certbot/certbot:latest`): un solo build,
nessuna immagine base custom da preparare prima.

```bash
easy proxy build                          # → ethiclab/nginx-easy
# oppure direttamente: docker build -t ethiclab/nginx-easy .
```

### Avvio container

```bash
easy proxy create
easy proxy status   # → container ID se running
```

---

## 4. Comandi

| Comando | Uso |
|---------|-----|
| `easy proxy create` | Avvia container nginx sulle porte 80/443 |
| `easy proxy build` | Build `ethiclab/nginx-easy` da Dockerfile locale |
| `easy proxy new http\|https <fqdn> <domain> <target>` | Aggiunge vhost |
| `easy proxy certbot-ionos <domain>` | Genera wildcard cert via IONOS DNS-01 (auto) |
| `easy proxy certbot` | Genera cert via DNS-01 manuale (interattivo) |
| `easy proxy rfc2136` | Genera cert via RFC2136/BIND DNS |
| `easy proxy reload` | Ricarica nginx (dopo new o modifica conf) |
| `easy proxy status` | Container ID se running, vuoto se fermo |
| `easy proxy id` | Container ID (`docker ps` per nome `easy-proxy`, anche se fermo) |
| `easy proxy doctor` | Diagnosi read-only: vhost non-standard, `nginx -t`, reti del proxy |
| `easy proxy verify` | Verifica che il proxy sia davvero up; `create` la esegue da solo |
| `easy proxy recover [--consolidate]` | Break-glass: trova le reti dei backend, collega il proxy, riavvia |
| `easy proxy attach\|detach <container>` | Collega/scollega un container alla rete edge `EASY_PROXY_NETWORK` |
| `easy proxy networks [prune]` | Mostra le reti del proxy; `prune` scollega quelle non-edge |
| `easy proxy start/stop/restart` | Ciclo container |
| `easy proxy sh` | Shell interattiva nel container |
| `easy proxy log` | `docker logs -f` del container |
| `easy proxy destroy` | Stop + rm del container `easy-proxy` |

---

## 5. Integrazione IONOS (UC1)

### Prerequisiti

```bash
brew install pass          # macOS
pass init "<gpg-key-id>"   # prima configurazione

pass insert ionos/api-key       # API Key da IONOS → Account → Developer → API Keys
pass insert ionos/api-secret    # API Secret (stesso pannello)
```

Oppure via env vars (meno sicuro):
```bash
export IONOS_API_KEY="xxx"
export IONOS_API_SECRET="yyy"
```

### Flusso UC1 completo

```bash
# 1. Genera cert wildcard per dev.ethiclab.it e *.dev.ethiclab.it
easy proxy certbot-ionos dev.ethiclab.it
# → Crea /etc/letsencrypt/ionos.ini (chmod 600) dentro il container
# → certbot usa IONOS API per creare TXT _acme-challenge.dev.ethiclab.it
# → Let's Encrypt verifica e rilascia il cert

# 2. Crea vhost per ELEVEN (porte locali)
easy proxy new https platform.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:8010
easy proxy new https onceapi.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:8011
easy proxy new https onceui.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:3000
easy proxy new https backoffice.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:3001

# 3. Reload
easy proxy reload

# 4. Aggiungi a /etc/hosts (finché non hai split-view DNS)
echo "127.0.0.1 platform.dev.ethiclab.it onceapi.dev.ethiclab.it onceui.dev.ethiclab.it backoffice.dev.ethiclab.it" | sudo tee -a /etc/hosts

# 5. Test
curl -k https://platform.dev.ethiclab.it/
```

Guida completa: [UC1_LOCAL_SSL_SETUP.md](UC1_LOCAL_SSL_SETUP.md)

---

## 6. Test

### Test automatici (bats)

```bash
brew install bats-core kcov   # prerequisiti (una tantum)

bats test/                    # esegue la suite
npm test                      # idem, via npm script
kcov coverage bats test/      # suite + report copertura in coverage/
```

La suite (`test/`) copre il dispatcher `easy`, il routing di `easy proxy`
(inclusi gli error path di `certbot-ionos`, con mock di `docker`/`pass`) e il
renderer `skeleton.js`. Gira isolata — non richiede Docker né credenziali IONOS.
Eseguita anche dal hook `.husky/pre-push` e dalla CI.

### Test manuale end-to-end (richiede Docker)

```bash
cd ~/ethiclab/lab/easy-proxy
export EASY_DIR="$PWD"
export EASY_LETSENCRYPT_DIR="$HOME/.easy-proxy/letsencrypt"
export EASY_DOMAINS_DIR="$HOME/.easy-proxy/domains"
export EASY_LETSENCRYPT_EMAIL="test@ethiclab.it"
export PATH="$EASY_DIR:$PATH"

# Test 1: container lifecycle
easy proxy create
easy proxy status        # ← deve stampare un ID
docker ps | grep nginx-easy

# Test 2: vhost HTTP (non richiede cert)
easy proxy new http myapp.test.ethiclab.it test.ethiclab.it http://host.docker.internal:8010
ls "$EASY_DOMAINS_DIR/test.ethiclab.it/"   # ← 2 file .conf
easy proxy reload                            # ← deve uscire senza errori

# Test 3: nginx risponde
curl -s -o /dev/null -w "%{http_code}" http://localhost/  # ← 404 = OK (no backend)

# Test 4: error paths certbot-ionos
easy proxy certbot-ionos              # ← deve dire "Domain required"
easy proxy certbot-ionos test.it      # ← deve dire "IONOS API credentials not found"

# Cleanup
easy proxy destroy
rm -rf "$EASY_DOMAINS_DIR"/*
```

### Test con IONOS reale

```bash
# Richiede: pass ionos/api-key e pass ionos/api-secret configurati
easy proxy certbot-ionos dev.ethiclab.it
# Verifica cert
openssl x509 -in ~/.easy-proxy/letsencrypt/live/dev.ethiclab.it/cert.pem -noout -dates
```

### Rebuild immagine (dopo modifiche al Dockerfile)

```bash
easy proxy build
# Ricrea container
easy proxy destroy
easy proxy create
```

---

## 7. File chiave

| File | Scopo | Modificare? |
|------|-------|------------|
| `commands/proxy.sh` | Tutti i comandi easy proxy | ✅ Sì |
| `easyhome/skeleton.js` | Template renderer (zero deps) | ✅ Sì |
| `easyhome/templates/*.conf` | Template nginx vhost | ✅ Sì |
| `easyhome/nginx.conf` | Config nginx main | ⚠️ Con cautela |
| `easyhome/ionos-config-helper.sh` | Helper credenziali IONOS | ✅ Sì |
| `Dockerfile` | Build nginx-easy, self-contained (`FROM certbot/certbot:latest`) | ⚠️ Raro |
| `easy` | CLI dispatcher bash | ⚠️ Non toccare |

---

## 8. Gotcha

| Problema | Causa | Fix |
|----------|-------|-----|
| `easy proxy create` fallisce: porta già allocata | Container vecchio ancora running | `easy proxy destroy` poi ricrea |
| `easy proxy create`: "already an easy proxy instance named easy-proxy" | Esiste già un container `easy-proxy` (anche solo fermo) | `easy proxy destroy` poi ricrea |
| nginx reload fallisce: cert non trovato | `certbot-ionos` non ancora eseguito | Esegui `easy proxy certbot-ionos <domain>` prima |
| `easy proxy new https` genera file ma reload fallisce | Cert non esiste per quel dominio | Usa `http` per test senza cert |
| `docker exec` "not a TTY" | Solo `sh` usa `-it`, gli altri no | OK by design, non aggiungere `-it` ai comandi non-interattivi |
| `skeleton.js`: variabile nginx `$upstream` scompare | Manca unescape `\$` → `$` | Già fixato in v2.0.0 — verificare se ritorni |
| Container usa `nginx` user (Alpine) non `www-data` | nginx su Alpine usa `nginx` | `nginx.conf` ha `user nginx;` — non cambiare |

---

## 9. Prossimi step (roadmap)

### Subito (bloccante UC1)
- [ ] Ottenere API key IONOS da pannello IONOS → configurare in `pass`
- [ ] Eseguire `easy proxy certbot-ionos dev.ethiclab.it` (primo cert reale)
- [ ] Test UC1 end-to-end con ELEVEN locale

### Prossima sessione
- [ ] Split-view DNS con dnsmasq (UC1 Phase 2)
- [ ] Register.it DNS provider support (Phase 3)
- [ ] `easy proxy renew` command (auto-renew certs)
- [ ] `.env.example` file per onboarding nuovi dev

### Futuro
- [ ] `easy proxy certbot-route53` (per infra AWS)
- [ ] `mini proxy [...]` wrapper in devel/bin/mini
- [ ] (opz.) pubblicare `ethiclab/nginx-easy` su un registry per saltare il build locale

---

## 10. Decisioni architetturali

Vedi `decisions.md` (da creare) per le scelte fatte.

Principali:
- **Bash CLI** mantenuto (non migrato a Node.js) — semplicità > ergonomia
- **Zero-dependency skeleton.js** — evita yargs globale nel container
- **Dockerfile self-contained** (`FROM certbot/certbot:latest`) — un solo `docker build`, nessuna immagine base custom da preparare/pushare. Prima c'era un `Dockerfile.build` separato per `ethiclab/nginx-certbot:2.0`: rimosso, creava solo un problema di bootstrap senza registry
- **Alpine base** (da `certbot/certbot`) — immagine più piccola, ma richiede `user nginx;` invece di `www-data`
- **ENTRYPOINT []** resettato nel Dockerfile — altrimenti CMD viene passato come arg a certbot
- **pass CLI** per credenziali — sicurezza > comodità env vars
- **Container identificato per nome fisso** (`easy-proxy`), non da un file di stato `.id` — Docker è l'unica fonte di verità. Il vecchio `.id` veniva scritto nella install dir, root-owned dopo `npm install -g` → permission denied (issue #5)

---

**Vedi anche**: [STATE.md](STATE.md) · [UC1_LOCAL_SSL_SETUP.md](UC1_LOCAL_SSL_SETUP.md) · [USE_CASES.md](USE_CASES.md)

## metaswarm

This project uses [metaswarm](https://github.com/dsifry/metaswarm) for multi-agent orchestration with Claude Code. It provides 18 specialized agents, a 9-phase development workflow, and quality gates that enforce TDD, coverage thresholds, and spec-driven development.

### Workflow

- **Most tasks**: `/start-task` — primes context, guides scoping, picks the right level of process
- **Complex features** (multi-file, spec-driven): Describe what you want built with a Definition of Done, then tell Claude: `Use the full metaswarm orchestration workflow.`

### Available Commands

| Command | Purpose |
|---|---|
| `/start-task` | Begin tracked work on a task |
| `/prime` | Load relevant knowledge before starting |
| `/review-design` | Trigger parallel design review gate (5 agents) |
| `/pr-shepherd <pr>` | Monitor a PR through to merge |
| `/self-reflect` | Extract learnings after a PR merge |
| `/handle-pr-comments` | Handle PR review comments |
| `/brainstorm` | Refine an idea before implementation |
| `/create-issue` | Create a well-structured GitHub Issue |

### Quality Gates

- **Design Review Gate** — Parallel 5-agent review after design is drafted (`/review-design`)
- **Plan Review Gate** — Automatic adversarial review after any implementation plan is drafted. Spawns 3 independent reviewers (Feasibility, Completeness, Scope & Alignment) in parallel — ALL must PASS before presenting the plan. See `skills/plan-review-gate/SKILL.md`
- **Coverage Gate** — `.coverage-thresholds.json` defines thresholds. BLOCKING gate before PR creation

### Team Mode

When `TeamCreate` and `SendMessage` tools are available, the orchestrator uses Team Mode for parallel agent dispatch. Otherwise it falls back to Task Mode (existing workflow, unchanged). See `guides/agent-coordination.md` for details.

### Guides

Development patterns and standards are documented in `guides/` — covering agent coordination, build validation, coding standards, git workflow, testing patterns, and worktree development.

### Testing & Quality

- **TDD is mandatory** — Write tests first, watch them fail, then implement
- **100% test coverage required** — Enforced via `.coverage-thresholds.json` as a blocking gate before PR creation and task completion
- **Coverage source of truth** — `.coverage-thresholds.json` defines thresholds. Update it if your spec requires different values. The orchestrator reads it during validation — this is a BLOCKING gate.

### Workflow Enforcement (MANDATORY)

These rules override any conflicting instructions from third-party skills:

- **After brainstorming** → MUST run Design Review Gate (5 agents) before writing-plans or implementation
- **After any plan is created** → MUST run Plan Review Gate (3 adversarial reviewers) before presenting to user
- **Execution method choice** → ALWAYS ask the user whether to use metaswarm orchestrated execution (more thorough, uses more tokens) or superpowers execution skills (faster, lighter-weight). Never auto-select.
- **Before finishing a branch** → MUST run `/self-reflect` and commit knowledge base updates before PR creation
- **Complex tasks** → Use `/start-task` instead of `EnterPlanMode` for tasks touching 3+ files. EnterPlanMode bypasses all quality gates.
- **Standalone TDD on 3+ files** → Ask user if they want adversarial review before committing
- **Coverage** → `.coverage-thresholds.json` is the single source of truth. All skills must check it, including `verification-before-completion`.
- **Subagents** → NEVER use `--no-verify`, ALWAYS follow TDD, NEVER self-certify, STAY within file scope
- **Context recovery** → Approved plans and execution state persist to `.beads/`. After compaction, run `bd prime --work-type recovery` to reload.
