# easy-proxy

> A CLI for running an nginx reverse proxy with automatic Let's Encrypt SSL — no
> hand-edited nginx config, no manual certificate juggling.

`easy-proxy` (npm: [`@ethiclab/easy-cli`](https://www.npmjs.com/package/@ethiclab/easy-cli))
runs an nginx + certbot container and lets you add reverse-proxy vhosts and
obtain wildcard HTTPS certificates from a single command.

## What it does

Say you have services running on local ports — a dashboard on `:8080`, an API on
`:8081` — and you want to reach them at real hostnames over HTTPS
(`app.example.com`, `api.example.com`) instead of `localhost:8080`.

`easy-proxy`:

1. runs an nginx reverse proxy in Docker (ports 80/443);
2. generates nginx vhosts from templates — `easy proxy new http|https ...`;
3. obtains Let's Encrypt SSL certificates via the DNS-01 challenge, automated for
   supported DNS providers (IONOS, Route53, Cloudflare, DigitalOcean, RFC2136).

No nginx configuration files to edit by hand.

## Requirements

- **Docker** 20.10+
- **Node.js** — the CLI ships as an npm package

## Installation

```bash
npm install -g @ethiclab/easy-cli
```

Set these environment variables (add them to `~/.zshrc` or `~/.bashrc` so they
persist):

```bash
export EASY_LETSENCRYPT_DIR="$HOME/.easy-proxy/letsencrypt"   # certificates (persistent)
export EASY_DOMAINS_DIR="$HOME/.easy-proxy/domains"           # generated vhosts
export EASY_LETSENCRYPT_EMAIL="you@example.com"               # Let's Encrypt account email
mkdir -p "$EASY_LETSENCRYPT_DIR" "$EASY_DOMAINS_DIR"
```

Then build the image and start the proxy:

```bash
easy proxy build      # build the ethiclab/nginx-easy image
easy proxy create     # start the proxy on :80 and :443
easy proxy status     # prints the container id when running
```

> **Note — v2.0.0 is in active development.** The Docker images
> (`ethiclab/nginx-certbot:2.0`, `ethiclab/nginx-easy`) are not yet published to
> a registry, so they must be built locally. See [CLAUDE.md](CLAUDE.md) for the
> full build steps, including the base image.

## Quick start — HTTP

```bash
easy proxy create
easy proxy new http app.example.com example.com http://host.docker.internal:8080
easy proxy reload
```

`http://app.example.com` is now proxied to your service on port 8080.
`app.example.com` must resolve to the host running the proxy — via DNS, or via
`/etc/hosts` for local testing.

## Quick start — HTTPS with Let's Encrypt

Obtain a wildcard certificate for your domain via the DNS-01 challenge, then add
an HTTPS vhost. Example with IONOS:

```bash
# IONOS API credentials — via environment variables...
export IONOS_API_KEY="..."
export IONOS_API_SECRET="..."
# ...or via the `pass` password manager:
#   pass insert ionos/api-key
#   pass insert ionos/api-secret

easy proxy certbot-ionos example.com     # wildcard cert: example.com + *.example.com
easy proxy new https app.example.com example.com http://host.docker.internal:8080
easy proxy reload
```

For manual DNS-01 with any provider use `easy proxy certbot`; for RFC2136/BIND
use `easy proxy rfc2136`.

## Commands

Run `easy proxy help` for the full list.

| Command | Description |
|---|---|
| `easy proxy create` | Start the proxy container on ports 80/443 |
| `easy proxy build` | Build the `ethiclab/nginx-easy` image |
| `easy proxy new http\|https <fqdn> <domain> <target>` | Add a reverse-proxy vhost |
| `easy proxy certbot-ionos <domain>` | Wildcard SSL cert via IONOS DNS-01 (automated) |
| `easy proxy certbot` | SSL cert via manual DNS-01 (interactive) |
| `easy proxy rfc2136` | SSL cert via RFC2136/BIND DNS |
| `easy proxy reload` | Reload nginx after adding or changing vhosts |
| `easy proxy status` | Container id if running, empty if stopped |
| `easy proxy id` | Container id (running or stopped) |
| `easy proxy start` / `stop` / `restart` | Container lifecycle |
| `easy proxy sh` | Interactive shell in the container |
| `easy proxy log` | Follow the container logs |
| `easy proxy destroy` | Stop and remove the container |

## Upgrading to 2.0

`2.0.0` is a major release with breaking changes from `1.x`:

- **Container identity.** The proxy container is identified by the fixed name
  `easy-proxy` instead of a `.id` state file. A container created by `1.x` is
  not visible to `2.0` — remove it with `docker rm -f <container>` and run
  `easy proxy create` again.
- **Docker base image.** Upgraded to `ethiclab/nginx-certbot:2.0`. Run
  `easy proxy build` to rebuild.
- **Template engine.** Rewritten from Python 2 to Node.js (internal).

See **[CHANGELOG.md](CHANGELOG.md)** for the full history.

## Development

```bash
git clone git@github.com:ethiclab/easy-proxy.git
cd easy-proxy
. ./configure-local-devenv     # put the repo on PATH

npm test                       # bats test suite
npm run lint                    # ShellCheck
```

The full developer guide — architecture, the IONOS automation flow, gotchas — is
in **[CLAUDE.md](CLAUDE.md)**.

## Credits

Originally inspired by [jwilder/nginx-proxy](https://github.com/jwilder/nginx-proxy).

## License

MIT
