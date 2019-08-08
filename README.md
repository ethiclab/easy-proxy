# getting started

    export PATH=$(pwd):$PATH
    easy

# start nginx proxy (needs docker)

    easy proxy build
    easy proxy
    docker network create network1
    docker run -d --name server1 nginx
    docker network connect network1 $(easy proxy status)
    docker network connect network1 server1
    easy proxy new http server1.example.com example.com http://server1
    easy proxy reload

now visit: http://server1.example.com

IMPORTANT: Remember that server1.example.com must resolve to the ip address where the proxy is running.

# development

## start a local dns

    docker run -d -p 53:53/tcp -p 53:53/udp -p10000:10000/tcp sameersbn/bind

## visit webmin

  open https://localhost:10000
  with user root and password password
  
configure a new domain with wildcard support.

## Mac OSX

    networksetup -listallnetworkservices
    networksetup -getdnsservers <networkservice>
    networksetup -setdnsservers <networkservice> <dns1> [dns2] [...]
