# Dockerfile — ethiclab/nginx-easy
#
# A self-contained image: nginx + certbot with multi-DNS provider support,
# built directly from the official certbot base. `easy proxy build` produces it
# with a single `docker build` — no pre-existing custom base image required.
#
# Build:
#   easy proxy build
#   # or, directly:  docker build -t ethiclab/nginx-easy .

FROM certbot/certbot:latest

LABEL maintainer="EthicLab <dev@ethiclab.it>"
LABEL description="Nginx reverse proxy + Certbot with multi-DNS provider support (IONOS, Route53, Cloudflare, DigitalOcean, RFC2136)"
LABEL version="2.0"

# nginx + system deps + certbot DNS provider plugins
RUN apk add --no-cache \
    nginx \
    bash \
    nodejs \
    npm \
    sudo \
    py3-pip \
    ca-certificates \
    && pip install --no-cache-dir \
    certbot-dns-ionos \
    certbot-dns-route53 \
    certbot-dns-cloudflare \
    certbot-dns-digitalocean \
    && rm -rf /var/cache/apk/*

# Verify the install
RUN certbot plugins && nginx -v

# Reset certbot's ENTRYPOINT so CMD runs directly
ENTRYPOINT []

VOLUME ["/domains", "/etc/letsencrypt", "/usr/local/share/easy", "/var/cache/certbot", "/var/www/certbot"]

EXPOSE 80 443

CMD ["/usr/local/share/easy/easy-proxy-start"]
