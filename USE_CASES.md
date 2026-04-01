# easy-proxy — USE CASES PER EDU

> Proposte di utilizzo di easy-proxy nel workflow EthicLab
> Priorità: Determine basato su urgency Edu + synergy con cluster attivi
> Data: 2026-04-01

---

## UC1: Local SSL development (ELEVEN/BGOL)

**Urgency**: 🟡 MEDIO
**Effort**: 1 giorno
**ROI**: Alto (SSL realistico per OAuth/Cognito testing)

### Problema attuale
- Developerindividuali testano localhost:XXXX (HTTP)
- Integrazioni esterno (e.g., Cognito, DocuSign) richiedono HTTPS + FQDNs reali
- Self-signed certs causano browser warnings
- Setup attuale: niente proxy locale

### Soluzione con easy-proxy

```bash
# Unique per developer:
export EASY_LETSENCRYPT_DIR=~/tmp/easy-letsencrypt
export EASY_DOMAINS_DIR=~/tmp/easy-domains

# Setup once
easy proxy create

# Aggiungere servizi locali
easy proxy new https platform.dev.local dev.local http://localhost:8010
easy proxy new https api.dev.local dev.local http://localhost:8011
easy proxy new https ui.dev.local dev.local http://localhost:3000

# Self-signed certs per test rapido
docker exec $(easy proxy id) bash
# → generate self-signed in /etc/letsencrypt/live/dev.local/
# [TBD: script easy proxy selfsigned-generate]

easy proxy reload
echo "127.0.0.1 platform.dev.local api.dev.local ui.dev.local" >> /etc/hosts

# →  Ora OAuth/Cognito vede HTTPS realistico
```

### Success criteria
- [ ] Cognito oauth login works with https://platform.dev.local
- [ ] Certificate warning is self-signed only (not localhost)
- [ ] easy proxy logs show zero errors
- [ ] Setup repeatable in < 5 mins

### Blocchi
- Base image `ethiclab/nginx-certbot:1.1` non trovata → test impossibile fino a fix

---

## UC2: Multi-developer staging (ELEVEN backoffice team)

**Urgency**: 🟡 MEDIO
**Effort**: 2-3 giorni (+ setup server)
**ROI**: Altissimo (team velocity, realistic demo)

### Problema attuale
- Staging unico per tutti
- Feature demo complicate per reviewer (no dedicated URL)
- Merge conflict quando multipli feature in deploy
- Client vede "staging" generico, poco professionale

### Soluzione con easy-proxy

**Infrastructure**:
```
AWS EC2 t3.medium (Staging Server)
├─ easy-proxy container (persistent)
├─ Domain: dev.ethiclab.it (wildcard cert *.dev.ethiclab.it)
│
├─ Vhost: feature-edo.dev.ethiclab.it → builder 1 (Edu branch)
├─ Vhost: feature-fulvio.dev.ethiclab.it → builder 2 (Fulvio branch)
├─ Vhost: feature-onboarding.dev.ethiclab.it → builder 3 (new hire)
│
└─ CI/CD: Auto-add vhost per nuova branch feature-*
```

**GitLab CI integration**:
```yaml
deploy_stage:
  stage: deploy
  script:
    - ssh staging.ethiclab.it "easy proxy new https feature-${CI_COMMIT_BRANCH}.dev.ethiclab.it dev.ethiclab.it http://builder-${BUILD_NUM}:8010"
    - ssh staging.ethiclab.it "easy proxy reload"
  only:
    - branches
    - tags: skip
```

**Workflow**:
```
Developer: git push feature/new-dashboard
     ↓
GitLab CI: build image
     ↓
SSH execute: easy proxy new https feature-new-dashboard.dev.ethiclab.it ...
     ↓
Reviewer: apre link feature-new-dashboard.dev.ethiclab.it in browser
     ↓
QA: testa 3 features in parallelo (diverse URL, niente contaminazione)
     ↓
Merge main: Pulisci vhost (easy proxy destroy feature-...)
```

### Success criteria
- [ ] 3 features simultanee su diverse URL (zero contaminazione)
- [ ] Auto-deploydopo push (< 2 mins)
- [ ] SSL cert valido da Let's Encrypt
- [ ] NO manual nginx config editing

### Blocchi
- Require: AWS EC2 + elastico IP pubblico
- Require: Zone DNS delegata a AWS Route53

---

## UC3: Demo roadshow / event (ELEVEN + BGOL showcase)

**Urgency**: 🟠 BASSO (event-driven)
**Effort**: 4 hours (setup + rehearsal)
**ROI**: Medio (professionalità demo, customer experience)

### Problema attuale
- Demo ambiente non nome realistico
- Certificati problematici (self-signed → browser warnings)
- Difficile di gestire multi-ambiente (Eleven, BGOL, Etica showcase)
- Unprofessional vs competitor demo

### Soluzione con easy-proxy

**Pre-event setup (2 days before)**:

```bash
# DNS records (update roadshow.ethiclab.it wildcard)
roadshow.ethiclab.it      IN A 192.0.2.100  (AWS staging server IP)

# easy-proxy on that server
easy proxy create

# Add vhost per each cluster / product
easy proxy new https platform.roadshow.ethiclab.it roadshow.ethiclab.it http://eleven-staging:8010
easy proxy new https gameapi.roadshow.ethiclab.it roadshow.ethiclab.it http://bgol-staging:9999
easy proxy new https eval.roadshow.ethiclab.it roadshow.ethiclab.it http://etica-staging:3000

# Get real SSL certs
export EASY_LETSENCRYPT_EMAIL=sales@ethiclab.it
export EASY_LETSENCRYPT_DOMAIN=roadshow.ethiclab.it
easy proxy certbot    # ← Let's Encrypt wildcard
```

**Event day (live demo)**:
```bash
# Laptop/screen share presenter
# Navigate to: platform.roadshow.ethiclab.it
# ✓ HTTPS (green lock icon)
# ✓ Real domain name
# ✓ No warnings, professional
# Zero latency (local network / VPN)

# Switch between products:
# - gameapi.roadshow.ethiclab.it (BGOL)
# - eval.roadshow.ethiclab.it (ETICA)
```

**Post-event**: Cleanup e repurpose
```bash
easy proxy destroy
easy proxy new https demo-april.roadshow.ethiclab.it roadshow.ethiclab.it http://platform-demo:8010
# → Keep Roadshow 2.0 running per extended demo window
```

### Success criteria
- [ ] Zero SSL certificate warnings (real cert)
- [ ] No network latency (co-located server)
- [ ] Multi-product showcase (Eleven, BGOL, Etica)
- [ ] Professional domain names in URL bar

### Blocchi
- Require: Pre-booking event date + AWS infra
- Require: Set CNAME roadshow.ethiclab.it to AWS IP 1 week before

---

## UC4: Partner/reseller integration (FUTURE)

**Urgency**: ⚪ BASSO (future, not roadmap 2026-Q2)
**Effort**: 5-7 giorni (API + automation)
**ROI**: Alto (partner enablement, white-label potential)

### Concetto
- Partner istalla easy-proxy su proprio server
- EthicLab provision vhost automagicamente
- Partner espone Eleven/BGOL suite sotto suo dominio

### Example
```
Partner: "Cassa di Risparmio" (banca regionale)
Domain: fintech.cariplo.it (loro infra)

WhiteLabel setup:
├─ fintech.cariplo.it/platform → Eleven lending suite
├─ fintech.cariplo.it/esg → ESG evaluation tool
└─ fintech.cariplo.it/support → Help desk integration
```

### Implementation (future phase)
1. easy-proxy REST API wrapper
2. IAM integration (who can provision vhost?)
3. Branding layer (CSS customization per partner)
4. Billing/metering (SaaS model)

---

## Comparison: easy-proxy vs Traefik

| Scenario | easy-proxy | Traefik | Winner |
|----------|-----------|---------|--------|
| **Dev local SSL** ✓ | ✓ | ✓ | easy-proxy (simpler) |
| **Multi-team staging** | ⚠️ Manual automation | ✓ Native | Traefik |
| **Kubernetes prod** | ✗ | ✓✓✓ | Traefik |
| **Legacy VPS prod** | ✓✓ | ⚠️ Overkill | easy-proxy |
| **Learning tool** | ✓✓✓ | ⚠️ Complex | easy-proxy |

**Raccomandazione EthicLab**:
- **2026**: easy-proxy per UC1 (local SSL dev) + UC3 (event demo)
- **2027+**: Traefik se scale a Kubernetes o multi-region

---

## Implementation roadmap (Edu timing)

### Phase 0: Recovery (urgent)
- [ ] Locate o rebuild `ethiclab/nginx-certbot:1.1` base image
- [ ] Test locale: `easy proxy create` → working
- Estimated: 1-2 hours (blocca tuttaltro)

### Phase 1: UC1 local dev (IMMEDIATE, high ROI)
- [ ] Setup scripts `.env.example` + quickstart docs
- [ ] Test OAuth integration in ELEVEN + BGOL
- [ ] Share con Fulvio per parallel testing
- Estimated: 1 day total work

### Phase 2: UC3 event demo (EVENT-DRIVEN)
- [ ] Pre-event 48h: Deploy easy-proxy su staging server
- [ ] Setup vhost per Roadshow 2026
- [ ] Rehearsal + QA
- Estimated: 4 hours pre-event

### Phase 3: UC2 staging automation (FUTURE, if team grows)
- [ ] GitLab CI integration
- [ ] Auto-vhost provisioning per branches
- Estimated: 2-3 days + infra cost

---

## Decisioni Edu

**Cosa approvi subito?**
1. ✅ UC1: Local SSL dev (low risk, high value for dev team)
2. ✅ UC3: Demo roadshow (event-driven, professionalità)
3. ❓ UC2: Multi-team staging (decide if hiring incoming year)
4. ⏸ UC4: Partner white-label (future 2027+)

**Action items**:
- [ ] Localize base image docker `ethiclab/nginx-certbot:1.1`
- [ ] Approve UC1 + UC3 per implementation timeline
- [ ] Schedule: when to demo easy-proxy to Fulvio?

---

**Documento**: USE CASES EASY-PROXY
**Data**: 2026-04-01
**Per**: Edu (decisioni)
