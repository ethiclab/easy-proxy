FROM ethiclab/nginx-certbot:1.2
VOLUME ["/domains", "/etc/letsencrypt", "/usr/local/share/easy"]
CMD ["/usr/local/share/easy/easy-proxy-start"]
