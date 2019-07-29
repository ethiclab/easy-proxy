  server {
    server_name $domain;
    listen 80;
    error_page 404 /404.html;
    location = /404.html {
      root /usr/local/share/easy/default;
      internal;
    }
    location / {
      root /usr/local/share/easy/dontexist;
    }
  }
  server {
    server_name *.$domain;
    listen 80;
    error_page 404 /404.html;
    location = /404.html {
      root /usr/local/share/easy/default;
      internal;
    }
    location / {
      root /usr/local/share/easy/dontexist;
    }
  }
