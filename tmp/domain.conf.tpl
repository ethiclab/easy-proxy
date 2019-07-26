  server {
    server_name $domain;
    listen 80;
    error_page 404 /404.html;
    location = /404.html {
      root /tmp/default;
      internal;
    }
    location / {
      root /tmp/dontexist;
    }
  }
  server {
    server_name *.$domain;
    listen 80;
    error_page 404 /404.html;
    location = /404.html {
      root /tmp/default;
      internal;
    }
    location / {
      root /tmp/dontexist;
    }
  }
