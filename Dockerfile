FROM ethiclab/nginx-certbot:2.0
VOLUME ["/domains", "/etc/letsencrypt", "/usr/local/share/easy"]
CMD ["/usr/local/share/easy/easy-proxy-start"]
