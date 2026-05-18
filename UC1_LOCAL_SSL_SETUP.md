# UC1: Local SSL Development with IONOS DNS Automation

> Easy-proxy setup for local HTTPS development with automated Let's Encrypt certificate generation via IONOS DNS-01 challenge.

**Goal**: Develop against ELEVEN/BGOL services locally with valid SSL certificates, DNS-managed by IONOS API.

**Timeline**: 5-10 minutes after setup.

---

## Prerequisites

1. **easy-proxy running locally**
   ```bash
   cd ~/ethiclab/lab/easy-proxy
   export EASY_LETSENCRYPT_DIR=~/.easy-proxy/letsencrypt
   export EASY_DOMAINS_DIR=~/.easy-proxy/domains
   export EASY_LETSENCRYPT_EMAIL=admin@ethiclab.it
   mkdir -p $EASY_LETSENCRYPT_DIR $EASY_DOMAINS_DIR
   easy proxy create
   easy proxy status  # Should return container ID
   ```

2. **IONOS API credentials**
   - Get from IONOS.it → Account → API → Create token
   - Keep API Key + Secret secure

3. **pass CLI installed** (recommended for credential storage)
   ```bash
   brew install pass            # macOS
   pass init "your-gpg-key-id"  # First time only
   ```

---

## Step 1: Store IONOS Credentials

### Option A: Using `pass` (Recommended)
```bash
pass insert ionos/api-key
# Paste API Key, then Ctrl+D

pass insert ionos/api-secret
# Paste API Secret, then Ctrl+D

# Verify
pass ionos/api-key
pass ionos/api-secret
```

### Option B: Environment Variables
```bash
export IONOS_API_KEY="your-api-key"
export IONOS_API_SECRET="your-api-secret"
```

---

## Step 2: Generate SSL Certificate

**Generate wildcard cert for dev subdomain** (e.g., `dev.ethiclab.it`):

```bash
cd ~/ethiclab/lab/easy-proxy

export EASY_LETSENCRYPT_EMAIL=admin@ethiclab.it
export IONOS_API_KEY="$(pass ionos/api-key)"      # or set directly
export IONOS_API_SECRET="$(pass ionos/api-secret)" # or set directly

# Generate cert for dev.ethiclab.it and *.dev.ethiclab.it
easy proxy certbot-ionos dev.ethiclab.it
```

**What happens**:
1. ✅ Credentials validated (from `pass` or env vars)
2. ✅ `/etc/letsencrypt/ionos.ini` created inside container (mode 600)
3. ✅ Let's Encrypt sends DNS-01 challenge to certbot
4. ✅ certbot calls IONOS API to add TXT record `_acme-challenge.dev.ethiclab.it`
5. ✅ Let's Encrypt verifies TXT record
6. ✅ Certificate issued → `/etc/letsencrypt/live/dev.ethiclab.it/`

**Expected output**:
```
Generating certificate for dev.ethiclab.it and *.dev.ethiclab.it via IONOS DNS...
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Registering account
Requesting a certificate for dev.ethiclab.it and *.dev.ethiclab.it
Waiting for verification...
Cleaning up challenges

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/dev.ethiclab.it/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/dev.ethiclab.it/privkey.pem
```

---

## Step 3: Create Local Virtual Hosts

Map ELEVEN/BGOL services to `*.dev.ethiclab.it`:

```bash
# Platform (ELEVEN backend on 8010)
easy proxy new https platform.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:8010

# Once API (ELEVEN intake on 8011)
easy proxy new https once.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:8011

# OnceUI (ELEVEN frontend on 3000)
easy proxy new https onceui.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:3000

# Backoffice UI (ELEVEN ops on 3001)
easy proxy new https backoffice.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:3001

# GameAPI (BGOL backend on 9999)
easy proxy new https gameapi.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:9999

# GameMan (BGOL dashboard on 8080)
easy proxy new https gameman.dev.ethiclab.it dev.ethiclab.it http://host.docker.internal:8080
```

Then reload nginx:
```bash
easy proxy reload
```

---

## Step 4: Test Local HTTPS

From your machine (not in Docker):

```bash
# Add to /etc/hosts (or use dnsmasq for split-view later)
# 127.0.0.1  platform.dev.ethiclab.it onceui.dev.ethiclab.it ...

curl -k https://platform.dev.ethiclab.it/
# Should proxy to http://localhost:8010 with valid SSL cert

openssl s_client -connect platform.dev.ethiclab.it:443 2>/dev/null | grep -A2 "subject="
# Subject: CN = dev.ethiclab.it
```

Browser:
```
https://onceui.dev.ethiclab.it
→ Green lock ✅ (cert valid for *.dev.ethiclab.it)
→ Proxied to local onceui instance
```

---

## Step 5: Renew Certificates

Certbot auto-renews 30 days before expiry:

```bash
# Manual renewal (if needed)
easy proxy certbot-ionos dev.ethiclab.it

# Check cert expiry
openssl x509 -in ~/.easy-proxy/letsencrypt/live/dev.ethiclab.it/fullchain.pem -noout -enddate
# notAfter=Apr  1 02:28:19 2026 GMT
```

---

## Troubleshooting

### Cert generation fails: "DNS provider error"

**Check**: IONOS credentials validity
```bash
pass ionos/api-key   # Verify stored correctly
echo $IONOS_API_KEY  # Verify env var (if using that method)
```

**Check**: easy-proxy container running
```bash
easy proxy status  # Should return container ID
docker logs $(easy proxy id)
```

### Can't reach `https://platform.dev.ethiclab.it`

**Check**: /etc/hosts entry
```bash
# Add if missing:
echo "127.0.0.1 platform.dev.ethiclab.it" | sudo tee -a /etc/hosts
```

**Check**: Backend service running
```bash
# From devel/
./bin/mini up eleven  # Start ELEVEN services locally
```

**Check**: Vhost created
```bash
docker exec $(easy proxy id) ls -la /domains/dev.ethiclab.it/
# Should list: https.dev.ethiclab.it.conf, https.platform.dev.ethiclab.it.conf, etc.
```

### Browser shows "cert not trusted" (not self-signed)

**This is OK** — certificate is valid Let's Encrypt (not self-signed).
Add to browser trust, or use `curl -k` (insecure mode) for testing.

### "easy proxy certbot-ionos" command not found

**Check**: Version >= 2.0.0
```bash
cd ~/ethiclab/lab/easy-proxy && npm list | head -1
# Should show "@ethiclab/easy-cli@2.0.0"
```

**If stale**: Rebuild the image
```bash
easy proxy build
```

---

## Advanced: Split-View DNS (Phase 3, Deferred)

Once UC1 validated, add local DNS resolver (dnsmasq/bind9) to serve `*.ethiclab.it` → `127.0.0.1` locally, while upstream sees public IP for production.

**Related**: See `devel/decisions.md` for split-view architecture decision.

---

## Summary

| Step | Command | Time |
|------|---------|------|
| 1 | Credentials → pass/env | 2 min |
| 2 | `easy proxy certbot-ionos dev.ethiclab.it` | 3 min (DNS propagation ~1-2 min) |
| 3 | `easy proxy new https ...` × N vhosts | 2 min |
| 4 | `curl -k https://...` | 30 sec |
| **Total** | **~8 minutes first run** | |

On renewal: 2-3 minutes for cert refresh (DNS automated).

---

## See Also

- `easy-proxy/README.md` — Full easy-proxy documentation
- `easy-proxy/commands/proxy.sh` — Command implementation
- `devel/CLAUDE.md` § 4 — Local service ports reference
- IONOS API docs: https://ionos-api-documentation.readthedocs.io/
