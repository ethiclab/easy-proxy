# GitHub Copilot Instructions — easy-proxy

## Progetto

CLI bash+Docker per nginx reverse proxy con SSL Let's Encrypt automatico via DNS-01.
Versione: 2.0.0 | Stack: bash, Node.js 20, nginx 1.26, certbot, Docker Alpine.

## Pattern chiave

**Aggiungere comandi**: modificare `commands/proxy.sh` — segui il pattern `if [[ "nome" == "$2" ]]`.

**Template nginx**: `easyhome/templates/*.conf` — variabili in stile `$server_name`. Usare `\$upstream` per variabili nginx (vengono unescapate da `skeleton.js`).

**Credenziali**: sempre da `pass CLI` (`pass ionos/api-key`) con fallback su env vars (`IONOS_API_KEY`). Mai hardcoded.

**docker exec**: NON usare `-it` nei comandi non-interattivi (rompe script e CI). Solo `easy proxy sh` usa `-it`.

**user nginx**: nginx su Alpine usa `user nginx;` — NON cambiare a `www-data`.

## File principali

| File | Scopo |
|------|-------|
| `commands/proxy.sh` | Tutti i comandi `easy proxy *` |
| `easyhome/skeleton.js` | Renderer template nginx (zero deps, Node.js) |
| `easyhome/ionos-config-helper.sh` | Genera credenziali certbot-dns-ionos |
| `Dockerfile` | Build immagine `nginx-easy`, self-contained (aggiungere DNS providers qui) |

## Aggiungere un DNS provider (template)

1. `Dockerfile` → `pip install certbot-dns-<provider>`
2. `commands/proxy.sh` → aggiungi `if [[ "certbot-<provider>" == "$2" ]]` (copia da `certbot-ionos`)
3. `easyhome/<provider>-config-helper.sh` → crea file credenziali con `chmod 600`
4. Rebuild: `easy proxy build`

## Test rapido (senza credenziali)

```bash
export EASY_DIR="$PWD" EASY_LETSENCRYPT_DIR=~/.easy-proxy/letsencrypt EASY_DOMAINS_DIR=~/.easy-proxy/domains EASY_LETSENCRYPT_EMAIL=test@ethiclab.it
export PATH="$EASY_DIR:$PATH"
mkdir -p ~/.easy-proxy/{letsencrypt,domains}
easy proxy create && easy proxy new http test.ethiclab.it ethiclab.it http://host.docker.internal:8010 && easy proxy reload
curl -s -o /dev/null -w "%{http_code}" http://localhost/   # 404 = OK
easy proxy destroy
```
