FROM ethiclab/nginx-certbot:1.1
VOLUME ["/etc/letsencrypt", "/usr/local/share/easy"]
CMD ["/usr/local/share/easy/easy-proxy-start"]
