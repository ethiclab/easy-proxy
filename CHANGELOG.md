# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.3.0] — 2026-05-19

### Added

- `EASY_PROXY_DOCKER_RUN_OPTS` — extra options passed through to the `docker run`
  of `easy proxy create` (extra published ports, resource limits, etc.).

## [2.2.0] — 2026-05-18

### Added

- `easy proxy verify` — checks the proxy container is actually running and
  surfaces the startup error if it crashed. `easy proxy create` now runs this
  check automatically, so it no longer reports success when nginx failed to
  start.
- `easy proxy recover` — break-glass network recovery. Scans the vhost configs
  for backend hostnames, tallies the Docker networks they live on, connects the
  proxy to them and restarts. Reports the de-facto edge network (the one most
  backends share) and the outliers; `--consolidate` attaches the backends to
  the edge network instead.

## [2.1.0] — 2026-05-18

### Added

- `easy proxy doctor` — read-only pre-flight diagnostic. Flags non-standard
  vhost configs (`upstream {}` blocks, deprecated `listen ... http2`), runs the
  nginx config test when the proxy is running, and lists the proxy's Docker
  networks.
- `EASY_PROXY_NETWORK` — when set, `easy proxy create` joins that Docker network
  (created if missing), so recreating the proxy keeps its connectivity to the
  backends. New commands: `easy proxy attach`/`detach <container>` to connect a
  site to the edge network, and `easy proxy networks [prune]` to audit and clean
  up the proxy's network membership.

## [2.0.0] — 2026-05-18

A major release: automatic Let's Encrypt SSL with multi-DNS-provider support.

### Added

- `easy proxy certbot-ionos <domain>` — automated wildcard SSL certificates via
  the IONOS DNS-01 challenge.
- Multi-DNS provider support for the DNS-01 challenge: Route53, Cloudflare,
  DigitalOcean and RFC2136/BIND.
- bats test suite (`npm test`) and ShellCheck lint (`npm run lint`), enforced by
  CI and the `.husky/pre-push` hook.

### Changed

- **BREAKING — container identity.** The proxy container is identified by the
  fixed Docker name `easy-proxy`, queried directly from Docker, instead of a
  `.id` state file. A container created by `1.x` is not visible to `2.0`: remove
  it with `docker rm -f <container>` and run `easy proxy create` again ([#5]).
- **BREAKING — Docker image.** The container image is rebuilt from scratch on
  `certbot/certbot:latest` — a single self-contained `Dockerfile` adds nginx,
  Node and the certbot DNS plugins. `easy proxy build` produces it with one
  `docker build`, with no custom base image required. Run `easy proxy build`
  to rebuild.
- Template engine rewritten from Python 2 (`skeleton.py`) to a zero-dependency
  Node.js renderer (`skeleton.js`).

### Fixed

- `easy proxy create` no longer writes a state file into the install directory.
  After `npm install -g` that directory is root-owned, so non-root users got
  `Permission denied` ([#5]).
- `easy --version` and `easy proxy help` now work before the runtime env vars
  (`EASY_LETSENCRYPT_DIR`, `EASY_DOMAINS_DIR`) are set — they no longer fail
  with `... is not set!`, so a freshly installed CLI can be inspected.
- Argument quoting hardened across the `easy` dispatcher and `commands/proxy.sh`
  (ShellCheck cleanup).

## [1.0.24] — 2021-11-17

### Added

- `--version` flag.

[#5]: https://github.com/ethiclab/easy-proxy/issues/5
