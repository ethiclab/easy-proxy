# easy-proxy — STATE.md

> Stato attuale e blocchi del progetto
> Aggiornato: 2026-04-01

---

## Status repository

| Aspetto | Stato | Note |
|---------|-------|------|
| **Ultimmo commit** | 2021-11-17 (v1.0.24) | Stabile da ~4.5 anni |
| **Branch attivo** | N/A (trunk-only) | Nessun branching, sempre `main` |
| **Remote** | ✅ GitHub attivo | `git@github.com:ethiclab/easy-proxy.git` |
| **Size** | 272 KB | Piccolissimo, niente node_modules in git |
| **Publish** | ✅ npm attivo | `@ethiclab/easy-cli` su NPM registry |

---

## WIP corrente

| Task | Stato | Descrizione |
|------|-------|-------------|
| **Base image recovery** | 🔴 BLOCKED | `ethiclab/nginx-certbot:1.1` — non trovata in Docker Hub |
| **Locale test** | ⏳ PENDING | Attendere risoluzione base image |
| **Documentation update** | ⏳ PENDING | README aggiornato dopo test locale |

---

## Blocchi attivi

| Blocco | Gravità | Descrizione | Next step |
|--------|---------|-----------|-----------|
| **Base image ethiclab/nginx-certbot:1.1 non disponibile** | 🔴 CRITICO | Docker build fallisce se image non trovato. Blocca test locale | Cercare su Docker Hub historical versions o rebuildarla da source |
| **EASY_* environment variables non documentati nel setup** | 🟡 ALTO | Setup manuale richiede 4 env vars, facile sbagliare | Add `.env.example` al repo |
| **No tests** | 🟡 MEDIO | package.json test script è dummy | Add Jest tests per comandi principali (create, new, status) |

---

## Dipendenze esterne critiche

```
easy-proxy/Dockerfile
  └─ FROM ethiclab/nginx-certbot:1.1  ← ⚠️ IMAGE NON TROVATA
     └─ nginx
     └─ certbot
     └─ rfc2136 DNS solver
     └─ sudo, CA certs
```

**Azione**: Controllare:
1. Docker Hub `ethiclab/nginx-certbot` old tags
2. Local Docker images history
3. Se persa: ricreareilla da Dockerfile template (nginx + certbot + dependencies)

---

## Utilizzo previsto (vicino)

### Priorità per Edu:
1. **Dev environment Eleven**: easy-proxy per SSL locale durante sviluppo
2. **Demo roadshow**: Sottodomini temporanei per presentazioni client
3. **Lab tool**: Learning resource per team su nginx/certbot

### Priorità per integrazione devel:
- Valutare se aggiungere `mini proxy [create|new|...]` commands
- Oppure tenerlo separato e documentare in README del workspace

---

## Prossimi step (ordine)

1. **Setup recovery**: Locate o rebuild base image
2. **Locale test**: `npm install -g .` + quick commands
3. **Documentation**: Add QUICKSTART.md + .env.example
4. **Test automation**: Add yarn test (Jest)
5. **Modernization**: Consider Node.js CLI rewrite (Phase 2 CLAUDE.md)

---

## Note storiche

- **2021-11**: Última release ufficiale (v1.0.24 -- add --version flag)
- **2019**: Stabilizzazione e rilascio pubblico
- **2015-2019**: Sviluppo attivo (24 release identificate in git log)
- **Original inspiration**: jwilder/nginx-proxy (reference)

---

## Per la prossima sessione

Ricordare:
- [ ] Cercary base image `ethiclab/nginx-certbot:1.1`
- [ ] Se non trovata, creare ticket per rebuild
- [ ] Test locale prima di roadmap implementazione
