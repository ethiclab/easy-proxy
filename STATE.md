# easy-proxy — STATE.md

> Stato attuale e blocchi del progetto
> Aggiornato: 2026-06-09

---

## Versione corrente

| Aspetto | Valore |
|---------|--------|
| **Versione** | 2.3.2 (tag `v2.3.2`) |
| **npm** | `@ethiclab/easy-cli` — registry ancora a `1.0.24`; in produzione si installa da git tag |
| **Branch** | `master` |
| **Remote** | `git@github.com:ethiclab/easy-proxy.git` |
| **Immagine** | `ethiclab/nginx-easy` — build locale da `Dockerfile` self-contained (`FROM certbot/certbot:latest`) |

---

## WIP corrente

| Task | Stato | Note |
|------|-------|------|
| **Deploy fix certbot su ethicserver** | 🟡 IN CORSO | CLI aggiornata a 2.3.2; resta da ricreare il container + cert IONOS. Vedi [SERVER_RUNBOOK.md](SERVER_RUNBOOK.md) |
| **Cert IONOS wildcard auto-rinnovabile** | 🟡 PENDING | `easy proxy certbot-ionos ethiclab.it` dopo il recreate del container |
| **Rilascio npm su registry** | 🟡 PENDING | `npm publish` — serve `npm login` sullo scope `@ethiclab` (in prod si usa l'install da git tag) |

---

## Blocchi attivi

| Blocco | Gravità | Next step |
|--------|---------|-----------|
| **`certbot/certbot:latest` deriva i flag/config certbot** | 🟡 RICORRENTE | Valutare il pin dell'immagine a un tag fisso invece di `:latest` per fermare la deriva della CLI ai rebuild |
| **`rfc2136` rotto su ethicserver** | 🟢 SERVER-SIDE | `/etc/letsencrypt/secret.txt`: `dns_rfc2136_server` deve essere un IP, non un hostname; `chmod 600`. Non è un bug del repo |

Nessun blocco tecnico aperto nel repo.

---

## Fatto in questa fase (sessione 2026-06-09)

Fix degli errori certbot emersi su `ethicserver` (certbot moderno + reinstall CLI):

| PR | Versione | Cosa |
|----|----------|------|
| #35 | 2.3.1 | Flag certbot: rimosso `--manual-public-ip-logging-ok`, `--dns-ionos` → `--authenticator dns-ionos` |
| #36 | 2.3.2 | `ionos.ini` nel formato del plugin attuale (`dns_ionos_prefix`/`secret`/`endpoint`) |

- Aggiunto [SERVER_RUNBOOK.md](SERVER_RUNBOOK.md): recovery del proxy dopo upgrade CLI.
- Knowledge base aggiornata con due gotcha: deriva flag di `certbot:latest`; `npm install -g` a container attivo rompe il bind mount di `easyhome` (causa del fallimento di `reload`).
- Suite bats: 55/55. Tag `v2.3.2` pushato.

### Storico precedente (sessione 2026-05-17/18)

PR #9–#17: lint ShellCheck, CI Bash/Docker, harness test bats, container per nome
(`easy-proxy`, issue #5), README/CHANGELOG, LICENSE + allowlist npm, Dockerfile
self-contained. PR #28–#34: `verify`/`recover`/`doctor`/`networks`,
`EASY_PROXY_NETWORK`, `EASY_PROXY_DOCKER_RUN_OPTS`, release 2.1.0→2.3.0.

---

## Prossimi step

1. **Completare il deploy su ethicserver** — [SERVER_RUNBOOK.md](SERVER_RUNBOOK.md): recreate container + `certbot-ionos`
2. **Pin immagine certbot** a un tag fisso (evita deriva CLI ai rebuild)
3. **`npm publish`** — pubblicare `@ethiclab/easy-cli` sul registry (azione manuale, `npm login`)
4. **`easy proxy renew`** — comando di auto-rinnovo certificati (roadmap)
5. **Split-view DNS** con dnsmasq (UC1 Phase 2)

---

## Quick resume

```bash
cd ~/ethiclab/easy-proxy
export EASY_DIR="$PWD"
export EASY_LETSENCRYPT_DIR="$HOME/.easy-proxy/letsencrypt"
export EASY_DOMAINS_DIR="$HOME/.easy-proxy/domains"
export EASY_LETSENCRYPT_EMAIL="admin@ethiclab.it"
export PATH="$EASY_DIR:$PATH"
easy proxy status   # container running?
```
