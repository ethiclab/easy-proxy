# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.0.0] — unreleased

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
- Argument quoting hardened across the `easy` dispatcher and `commands/proxy.sh`
  (ShellCheck cleanup).

## [1.0.24] — 2021-11-17

### Added

- `--version` flag.

[#5]: https://github.com/ethiclab/easy-proxy/issues/5
