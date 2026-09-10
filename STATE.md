# easy-proxy — STATE.md

> Stato attuale e blocchi del progetto
> Aggiornato: 2026-09-10
>
> Qui solo lo stato dello **strumento**. Lo stato delle installazioni (host, siti,
> certificati, decisioni operative) sta nel repo ops privato di chi le gestisce.

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
| **Rilascio npm su registry** | 🟡 PENDING | `npm publish` — serve `npm login` sullo scope `@ethiclab` (in prod si usa l'install da git tag) |

---

## Blocchi attivi

| Blocco | Gravità | Next step |
|--------|---------|-----------|
| **`certbot/certbot:latest` deriva i flag/config certbot** | 🟡 RICORRENTE | Valutare il pin dell'immagine a un tag fisso invece di `:latest` |

Nessun blocco tecnico aperto nel repo.

---

## Fatto in questa fase

### Sessione 2026-09-10 (operativa, lezioni riportate nello strumento)

- Rinnovo automatico verificato in produzione: deploy hook + timer systemd (documentati in [SERVER_RUNBOOK.md](SERVER_RUNBOOK.md)).
- Dominio con DNS senza plugin certbot convertito da DNS-01 manuale a HTTP-01 webroot sullo stesso lineage.
- [SERVER_RUNBOOK.md](SERVER_RUNBOOK.md) reso generico: layout host, scelta della challenge per provider DNS, HTTP-01, rinnovo, collegamento degli stack alla rete edge.
- Knowledge base: lezioni su template (niente WebSocket/ACME), alias Compose sulla rete edge, `-f` che ignora l'override, versioning di `EASY_DOMAINS_DIR` sì / `EASY_LETSENCRYPT_DIR` no; corretta la decisione sul wildcard (`certbot-dns-ionos` non segue i CNAME).

### Sessione 2026-06-09

| PR | Versione | Cosa |
|----|----------|------|
| #35 | 2.3.1 | Flag certbot: rimosso `--manual-public-ip-logging-ok`, `--dns-ionos` → `--authenticator dns-ionos` |
| #36 | 2.3.2 | `ionos.ini` nel formato del plugin attuale (`dns_ionos_prefix`/`secret`/`endpoint`) |

### Storico precedente (sessione 2026-05-17/18)

PR #9–#17: lint ShellCheck, CI Bash/Docker, harness test bats, container per nome
(`easy-proxy`, issue #5), README/CHANGELOG, LICENSE + allowlist npm, Dockerfile
self-contained. PR #28–#34: `verify`/`recover`/`doctor`/`networks`,
`EASY_PROXY_NETWORK`, `EASY_PROXY_DOCKER_RUN_OPTS`, release 2.1.0→2.3.0.

---

## Prossimi step

1. **Template con supporto WebSocket e ACME HTTP-01** (flag su `easy proxy new`, o include di `common.conf` in `nginx.conf`) — oggi i vhost reali si scrivono a mano
2. **`easy proxy renew`** — sostituirebbe il `docker exec ... certbot renew` nel timer, con stato per singolo lineage
3. **`easy proxy certbot-webroot <domain>`** — HTTP-01 per i DNS senza plugin
4. **`doctor`**: segnalare `proxy_pass` con hostname letterale; non segnalare `upstream` su IP; segnalare cert in `live/` senza `renewal/`
5. **Pin immagine certbot** a un tag fisso
6. **`ionos-config-helper.sh`** — allineare al formato prefix/secret/endpoint (oggi codice morto con le chiavi vecchie)
7. **`npm publish`** di `@ethiclab/easy-cli`

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
