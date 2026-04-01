# ANALISI TECNICA EASY-PROXY — 2026-04-01

## Indice
1. [Architettura](#architettura)
2. [Flow comandi](#flow-comandi)
3. [Struttura easyhome](#struttura-easyhome)
4. [Deployment flow](#deployment-flow)
5. [Use case Edu](#use-case-edu)
6. [Quick start](#quick-start)

---

## Architettura

### Concetto generale

**easy-proxy** è un **orchestratore Docker CLI** che:
1. Gestisce un container Docker singolo nginx + certbot
2. Espone sottodomini attraverso configurazione dinamica
3. Automatizza certificati SSL via Let's Encrypt

### Differenza da Traefik / moderne alternative

| Aspetto | easy-proxy | Traefik | nginx (standalone) |
|---------|-----------|---------|------------------|
| **Configurazione** | File-based vhost | Container labels | Manuale |
| **SSL/Let's Encrypt** | Built-in certbot | Built-in ACME | Plugin esterni |
| **Complessità setup** | Bash CLI | Docker compose | Alto |
| **CI/CD integration** | Minimal | Native | Minimal |
| **Scalability** | Single instance | Multi-instance ready | Requires HAproxy |
| **Learning curve** | Basso (nginx classic) | Medio (nuovo paradigma) | Medio |
| **Per cosa va bene** | Dev/staging local | Prod multi-container | Prod legacy |

**Perché easy-proxy per Edu**: Semplicità locale, niente orchestrazione Kubernetes, SSL realistico senza Let's Encrypt delay.

---

## Flow comandi

### Dispatcher bash (easy script)

```bash
#!/bin/bash
easy [--version|command [subcommand] [args]]

Dispatcher logic:
1. Se --version → stampa package.json version
2. Se command assente → error + help
3. Cerca command in order:
   a) commands/{command}.rb  (ruby)
   b) commands/{command}.py  (python)
   c) commands/{command}.sh  (bash + source)
4. Se .sh → source + chiama __easy_command_{command} function
5. Passa tutti gli args al comando

ESEMPIO:
$ easy proxy new http myapp.demo.ethiclab.it demo.ethiclab.it http://myapp:3000

DISPATCH:
  easy
  ├─ Command: "proxy"
  ├─ Look for: commands/proxy.sh ✓ found
  ├─ Source commands/proxy.sh
  ├─ Call __easy_command_proxy $@
  │   ├─ Subcommand: "new"
  │   ├─ Chiama: __easy_command_proxy_new
  │   │   └─ Parsing args: [http, myapp.demo.ethiclab.it, demo.ethiclab.it, http://myapp:3000]
  │   │   └─ Docker exec in container
  │   │   └─ Run: /usr/local/share/easy/add_subdomain_http myapp.demo.ethiclab.it demo.ethiclab.it http://myapp:3000
  │   │
  │   └─ Exit code 0 ✓
  └─ Return 0
```

### Subcommands proxy principali

#### `easy proxy create` → avvia container

```bash
function __easy_command_proxy_create {
  # Check if already running
  EASY_PROXY=$(easy proxy id)
  if [[ ! -z "${EASY_PROXY}" ]]; then
    echo "Already running with ID ${EASY_PROXY}"
    return 1
  fi

  # Verificare env vars obbligatori
  if [[ -z "${EASY_LETSENCRYPT_DIR}" ]]; then
    echo "Error: EASY_LETSENCRYPT_DIR non set"
    return 1
  fi

  # Run container
  CONTAINER_ID=$(docker run -d \
    -v ${EASY_DOMAINS_DIR}:/domains \               # ← config vhost (esterno)
    -v ${EASY_LETSENCRYPT_DIR}:/etc/letsencrypt \   # ← certificati (esterno)
    -v ${EASY_DIR}/easyhome:/usr/local/share/easy \ # ← template nginx (repo)
    -p 80:80 \                                        # ← HTTP port
    -p 443:443 \                                      # ← HTTPS port
    -t ethiclab/nginx-easy)

  echo $CONTAINER_ID > $EASY_DIR/.id   # Save for future reference
  echo $CONTAINER_ID
}
```

**Volumi**:
- `/domains` ← EASY_DOMAINS_DIR (host) — archiviabile in git per reproducibility
- `/etc/letsencrypt` ← EASY_LETSENCRYPT_DIR — backup frecuente (certificati)
- `/usr/local/share/easy` ← easyhome (repo) — sola lettura

#### `easy proxy new` → aggiungi vhost

```bash
easy proxy new [http|https] <fqdn> <domain> <backend>

ESEMPIO:
easy proxy new https app.staging.ethiclab.it staging.ethiclab.it http://app:3000

FLOW:
1. Valida proxy è running (easy proxy status)
2. Parsed args: [https, app.staging.ethiclab.it, staging.ethiclab.it, http://app:3000]
3. Decide: https → add_subdomain_https
4. Docker exec in container:
   /usr/local/share/easy/add_subdomain_https \
     app.staging.ethiclab.it \
     staging.ethiclab.it \
     http://app:3000
5. Script crea:
   /domains/staging.ethiclab.it/app.conf  (nginx vhost)
6. Return exit code
```

#### `easy proxy certbot` / `rfc2136` → certificati SSL

```bash
easy proxy certbot
├─ Require: EASY_LETSENCRYPT_EMAIL (certbot registration)
├─ Require: EASY_LETSENCRYPT_DOMAIN (wildcard domain)
├─ Docker exec in container:
│   certbot --email ${EMAIL} --agree-tos --manual --preferred-challenges dns \
│     -d "${DOMAIN},*.${DOMAIN}"
│   # ← Interactive: risponderà alle challenge DNS manualmente
└─ Certificati salvati in EASY_LETSENCRYPT_DIR/live/...

easy proxy rfc2136
├─ RFC2136 = Dynamic DNS update protocol (DNS-01 solver)
├─ Per domini con supporto BIND DNS
├─ Richiede: /etc/letsencrypt/secret.txt con credenziali BIND
└─ Fully automated senza interazione
```

#### `easy proxy reload` → applica config

```bash
easy proxy reload
├─ Get container ID da .id
├─ Docker exec:
│   nginx -c /usr/local/share/easy/nginx.conf -s reload
├─ Nginx ricarica *.conf in /domains senza drop connessioni
└─ Exit code 0 ✓
```

---

## Struttura easyhome

### nginx.conf (master config)

```nginx
user www-data;
worker_processes auto;              # Auto-scale su CPU count
pid /run/nginx.pid;

events {
  worker_connections 100;           # Per-worker max connections
}

http {
  client_max_body_size 5g;          # Allow large file uploads
  include /domains/*/*.conf;         # ← CHIAVE: Dynamic vhost loading
}
```

**Pattern**: Una sola direttiva `include /domains/*/*.conf` → qualsiasi file `.conf` in subdirectory per dominio viene incluso.

### Struttura /domains/ (host filesystem)

Per dominio, cria directory e vhost config:

```
EASY_DOMAINS_DIR/
/domains/
├── staging.ethiclab.it/
│   ├── app.conf              (nginx vhost per app.staging.ethiclab.it)
│   ├── api.conf              (nginx vhost per api.staging.ethiclab.it)
│   └── ...
├── demo.ethiclab.it/
│   ├── platform.conf
│   └── ...
└── local/
    ├── dev.conf
    └── ...
```

**Versioning**: Directory /domains è ideale per git tracking. Facile vedere quali vhost sono deployati.

### Templates vhost (easyhome/templates/)

#### http.conf template

```nginx
upstream ${VAR_UPSTREAM_NAME} {
  server ${VAR_UPSTREAM};
}

server {
  listen 80;
  server_name ${VAR_SERVER_NAME};
  location / {
    proxy_pass http://${VAR_UPSTREAM_NAME};
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

#### https.conf template

```nginx
upstream ${VAR_UPSTREAM_NAME} {
  server ${VAR_UPSTREAM};
}

server {
  listen 443 ssl http2;
  server_name ${VAR_SERVER_NAME};

  ssl_certificate /etc/letsencrypt/live/${VAR_DOMAIN}/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/${VAR_DOMAIN}/privkey.pem;
  include /usr/local/share/easy/options-ssl-nginx.conf;

  location / {
    proxy_pass http://${VAR_UPSTREAM_NAME};
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
  }
}

# HTTP → HTTPS redirect
server {
  listen 80;
  server_name ${VAR_SERVER_NAME};
  return 301 https://$server_name$request_uri;
}
```

### add_subdomain_http / add_subdomain_https (script in container)

```bash
# Signature: add_subdomain_http <FQDN> <DOMAIN> <BACKEND>
# $1 = app.staging.ethiclab.it
# $2 = staging.ethiclab.it
# $3 = http://app:3000

FQDN=${1}
DOMAIN=${2}
BACKEND=${3}

# Estrarre upstream name (da FQDN)
UPSTREAM_NAME=$(echo $FQDN | sed 's/\./_/g' | sed 's/-/_/g')  # app_staging_ethiclab_it

# Create directory
mkdir -p /domains/${DOMAIN}

# Sostituire variabili in template
sed -e "s/\${VAR_UPSTREAM_NAME}/${UPSTREAM_NAME}/g" \
    -e "s/\${VAR_SERVER_NAME}/${FQDN}/g" \
    -e "s|\${VAR_UPSTREAM}|${BACKEND}|g" \
    -e "s/\${VAR_DOMAIN}/${DOMAIN}/g" \
    /usr/local/share/easy/templates/http.conf \
  > /domains/${DOMAIN}/${UPSTREAM_NAME}.conf

# Reload nginx
nginx -s reload
```

---

## Deployment flow (step by step)

### Prerequisiti

```bash
# 1. Setup environment
export EASY_LETSENCRYPT_DIR=~/letsencrypt  # persistent certs
export EASY_DOMAINS_DIR=~/domains          # persistent config
mkdir -p $EASY_LETSENCRYPT_DIR $EASY_DOMAINS_DIR

# 2. Installa easy-cli
npm install -g @ethiclab/easy-cli
# oppure: npm install -g ~/ethiclab/lab/easy-proxy

# 3. Verifica installation
easy --version   # → 1.0.24
which easy       # → /usr/local/bin/easy
```

### Step 1: avvia proxy

```bash
# Build image (o pull se disponibile)
easy proxy build
# → docker build /usr/local/lib/node_modules/@ethiclab/easy-cli -t ethiclab/nginx-easy

# Create container
easy proxy create
# → docker run -d -v ... ethiclab/nginx-easy
# → salva container ID in $EASY_DIR/.id
# → stdout: container ID

# Verify running
easy proxy status   # → prints container ID if running
easy proxy logs     # → live tail logs
```

### Step 2: connetti app interno

```bash
# Sup: app giù su http://127.0.0.1:3000
# Obiettivo: esporre via https://app.staging.ethiclab.it

# Creare Docker network (opzionale, ma recommended)
docker network create ethiclab

# Connettere app al network E al proxy
docker network connect ethiclab <app-container-id>
docker network connect ethiclab $(easy proxy id)

# App raggiungibile ora con hostname "app-container-name" in rete Docker
```

### Step 3: configure vhost

```bash
# Aggiungere vhost HTTPS
easy proxy new https app.staging.ethiclab.it staging.ethiclab.it http://app:3000
# → genera /domains/staging.ethiclab.it/app_3000.conf
# → reload nginx (incluso nel script)

# Opzionale: HTTP-only (senza SSL)
easy proxy new http test.demo.ethiclab.it demo.ethiclab.it http://test:8080
```

### Step 4: get SSL certificati

```bash
# Manual mode (test/sviluppo)
export EASY_LETSENCRYPT_EMAIL=edu@ethiclab.it
export EASY_LETSENCRYPT_DOMAIN=staging.ethiclab.it
easy proxy certbot
# → Certbot interattivo:
#    Please verify the dns xxx challenge:
#    → Manualmente aggiungere record DNS TXT
#    → Rispondere quando pronto
# → Certificati salvati in ~/letsencrypt/live/{domain}/

# RFC2136 mode (produzione, richiede DNS BIND)
# (Not recommended per dev)
```

### Step 5: test

```bash
# Locale
curl http://localhost/       # → nginx default page
curl https://app.staging.ethiclab.it/  # ← richiede DNS risolvere

# Network (da autre macchina su rete)
# Aggiungere /etc/hosts entry
# 192.168.1.100 app.staging.ethiclab.it   # ← IP host docker
curl https://app.staging.ethiclab.it

# Oppure port-forward SSH
ssh -L 443:localhost:443 edu@192.168.1.100
curl https://app.staging.ethiclab.it
```

---

## Use case Edu

### Usecase 1: Eleven dev + SSL locale

**Situazione**: Sviluppatrice locale lavora su platform.
- Backend Java @ localhost:8010
- Frontend @ localhost:3000
- Need: HTTPS + vhost realistico per testare OAuth/Cognito

**Setup**:

```bash
# Una volta
export EASY_LETSENCRYPT_DIR=~/letsencrypt
export EASY_DOMAINS_DIR=~/domains
easy proxy create

# Aggiungere platform
easy proxy new https platform.dev.ethiclab.it dev.ethiclab.it http://localhost:8010
easy proxy new https ui.dev.ethiclab.it dev.ethiclab.it http://localhost:3000

# Generatee self-signed certs (per test rapido SENZA Let's Encrypt)
# [TBD: add script easy proxy selfsigned]
easy proxy certbot  # ← today requires manual DNS

# Add /etc/hosts
echo "127.0.0.1 platform.dev.ethiclab.it ui.dev.ethiclab.it" >> /etc/hosts

# Test
curl https://platform.dev.ethiclab.it/health  # ← backend
curl https://ui.dev.ethiclab.it/   # ← frontend

# Cleanup
easy proxy reload  # if config changed
easy proxy destroy # if done for day
```

### Usecase 2: Demo roadshow

**Situazione**: Domani Salone Padova, clienti vedono Eleven live.
- Preparare ambiente staging con vhost realistici
- Named dopo cluster: `fund-A.roadshow.ethiclab.it`, `fund-B.roadshow.ethiclab.it`
- SSL cert da Let's Encrypt per credibilità

**Setup**:

```bash
# Pre-event (2 hours before)
easy proxy new https fund-a.roadshow.ethiclab.it roadshow.ethiclab.it http://platform-staging-1:8010
easy proxy new https fund-b.roadshow.ethiclab.it roadshow.ethiclab.it http://platform-staging-2:8010

export EASY_LETSENCRYPT_EMAIL=sales@ethiclab.it
export EASY_LETSENCRYPT_DOMAIN=roadshow.ethiclab.it
easy proxy certbot
# → Handle DNS challenges via hosting provider

# Event (show time)
# Demo via screen share / live devices
# Navigate to fund-a.roadshow.ethiclab.it in browser
# → HTTPS, realistico, niente "Untrusted cert" warns

# Post-event
easy proxy destroy
rm -rf ~/domains  # cleanup config
```

### Usecase 3: Multi-developer workspace

**Situazione**: Team di 3 sviluppatori (Edu + Fulvio + new hire).
- Condividono staging server con easy-proxy
- Ogni developer branch/feature esposta su subdomain dedicato
- Central demo link per team

**Setup**:

```
PRODUCTION Easy-Proxy Server (AWS EC2 / VPS)
├─ Base image: ethiclab/nginx-certbot:1.1
├─ Cert domain: dev.ethiclab.it (wildcard *.dev.ethiclab.it)
├─ team@ethiclab.it auto-renew
│
├─ feature-edu.dev.ethiclab.it → 10.0.1.50:8010 (Edu laptop)
├─ feature-fulvio.dev.ethiclab.it → 10.0.1.51:8010 (Fulvio laptop)
├─ feature-onboarding.dev.ethiclab.it → 10.0.1.52:8010 (new hire Ari)
│
└─ Daily auto-build ci/cd: new features auto-added to vhost
```

**Flow CI/CD**:
```yaml
# GitLab CI
deploy_feature:
  after_script:
    - ssh staging "easy proxy new https feature-$CI_BRANCH_NAME.dev.ethiclab.it dev.ethiclab.it http://$BUILDHOST:8010"
    - ssh staging "easy proxy reload"
```

---

## Quick start (pragmatico)

### 1. Verificare base image

```bash
docker pull ethiclab/nginx-certbot:1.1
# Se fallisce → problema critico, vedi CLAUDE.md Sezione 6

# Alternativa: rebuild
# cd lab/easy-proxy
# docker build -t ethiclab/nginx-certbot:1.1 easyhome/
# ⚠️ (Dockerfile in easyhome non trovato in repository…)
```

### 2. Install + test basic

```bash
npm install -g /Users/montoyaedu/ethiclab/lab/easy-proxy

easy --version           # → 1.0.24
easy proxy help
easy proxy build         # Test build

# Setup env vars
export EASY_LETSENCRYPT_DIR=~/test-easy/letsencrypt
export EASY_DOMAINS_DIR=~/test-easy/domains
mkdir -p $EASY_LETSENCRYPT_DIR $EASY_DOMAINS_DIR

# Create proxy
easy proxy create
# → attendi 10s e verifica logs
easy proxy status
easy proxy logs
```

### 3. Add primo vhost

```bash
# App test (simple http server)
python3 -m http.server 8888 &

# Configure vhost
easy proxy new http localhost-test.demo.local demo.local http://localhost:8888

# Verify config
docker exec $(easy proxy id) cat /domains/demo.local/localhost_test.conf

# Test
curl http://localhost/  # ← should work (porta 80 exposed)
```

### 4. Test SSL (self-signed prima di Let's Encrypt)

```bash
# [TBD] Aggiungere script per self-signed certs in easy
# Per adesso: manuale
docker exec $(easy proxy id) bash

# Inside container
cd /etc/letsencrypt/live/demo.local
sudo openssl req -x509 -newkey rsa:4096 -nodes -out fullchain.pem -keyout privkey.pem -days 1 -subj "/CN=*.demo.local"

# Exit container
exit

# Reload
easy proxy reload

# Test
curl -k https://localhost   # ← -k skips cert verification
```

---

## Conclusion

**easy-proxy** è uno strumento lightweight ottimo per:
- Dev environment locale con SSL
- Demo/staging realistico
- Learning nginx + certbot

**Non è per**:
- Produzione multi-availability-zone (use Traefik/ALB)
- Microservices con 100+ istanze (use Kubernetes)

**Prossimi step immediati**:
1. Recover o rebuild base image `ethiclab/nginx-certbot:1.1`
2. Test flow completo: create → new → certbot → reload
3. Decidere: Usare come tool singolo o integrare in `devel/bin/mini`?

---

**Documento**: ANALISI TECNICA EASY-PROXY
**Data**: 2026-04-01
**Autore**: Claude
