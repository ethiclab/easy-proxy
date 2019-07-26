server {
 # this is the internal Docker DNS, cache only for 30s
 resolver 127.0.0.11 valid=30s;

 server_name $server_name;
 location $location_path {
  set \$upstream $location_target;
  proxy_pass \$upstream;
 }
 listen 80;
 # listen 443 ssl;
 # ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
 # ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
 # include /etc/letsencrypt/options-ssl-nginx.conf;
 # ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
