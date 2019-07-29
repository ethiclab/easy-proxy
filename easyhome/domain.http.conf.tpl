server {
 # this is the internal Docker DNS, cache only for 30s
 resolver 127.0.0.11 valid=30s;

 server_name $server_name;
 location $location_path {
  set \$upstream $location_target;
  proxy_pass \$upstream;
 }
 listen 80;
}
