# easy-proxy — STATE.md

> Stato attuale e blocchi del progetto
> Aggiornato: 2026-05-18

---

## Versione corrente

| Aspetto | Valore |
|---------|--------|
| **Versione** | 2.0.0 (npm `@ethiclab/easy-cli` — pubblicato: ancora `1.0.24`) |
| **Branch** | `master` |
| **Remote** | `git@github.com:ethiclab/easy-proxy.git` |
| **Immagine** | `ethiclab/nginx-easy` — build locale da `Dockerfile` self-contained (`FROM certbot/certbot:latest`) |

---

## WIP corrente

| Task | Stato | Note |
|------|-------|------|
| **Rilascio npm 2.0.0** | 🟡 PENDING | `npm publish` — serve `npm login` sullo scope `@ethiclab` |
| **Test clean-room install** | 🟡 PIANIFICATO | Install pulito in container Docker, dopo il publish |
| **Test reale IONOS** | 🔴 PENDING | Richiede API key IONOS in `pass` |

---

## Blocchi attivi

| Blocco | Gravità | Next step |
|--------|---------|-----------|
| **API key IONOS non in `pass`** | 🔴 BLOCCANTE per test reale | `pass insert ionos/api-key` + `pass insert ionos/api-secret` dalla console IONOS |

Nessun blocco tecnico aperto — il bootstrap di build e push è risolto.

---

## Fatto in questa fase (sessione 2026-05-17/18)

Lavoro svolto con metaswarm, una PR per cambiamento:

| PR | Cosa |
|----|------|
| #9 | Script lint ShellCheck (`npm run lint`) |
| #11 | Fix workflow CI per progetto Bash/Docker (ShellCheck pinnato a v0.11.0) |
| #12 | Harness test bats (`test/`, 20 test) + tooling coverage |
| #13 | Cleanup dei finding ShellCheck baselined (zero direttive `disable`) |
| #14 | Container identificato per nome `easy-proxy`, non più file `.id` (issue #5) |
| #15 | README riscritto user-facing + `CHANGELOG.md` |
| #16 | `LICENSE` (MIT) + `files` allowlist npm (pacchetto 66 → 25 file) |
| #17 | `Dockerfile` self-contained — un solo build, nessuna immagine base custom |

Tutte le issue aperte (#5–#10) sono chiuse. `git push` passa col pre-push hook (lint + test bats).

---

## Prossimi step

1. **`npm publish`** — pubblicare `@ethiclab/easy-cli@2.0.0` (azione manuale, `npm login`)
2. **Test clean-room** — install pulito in un container Docker da zero
3. **Ottenere API key IONOS** → `pass insert ionos/api-key`
4. **Test reale**: `easy proxy certbot-ionos dev.ethiclab.it`
5. **Split-view DNS** con dnsmasq (Phase 2)

---

## Quick resume

```bash
cd ~/ethiclab/lab/easy-proxy
export EASY_DIR="$PWD"
export EASY_LETSENCRYPT_DIR="$HOME/.easy-proxy/letsencrypt"
export EASY_DOMAINS_DIR="$HOME/.easy-proxy/domains"
export EASY_LETSENCRYPT_EMAIL="admin@ethiclab.it"
export PATH="$EASY_DIR:$PATH"
easy proxy status   # container running?
```
