# getting started

    export PATH=$(pwd):$PATH
    easy

You should see and output like:

    2019-08-08 12:43:01.303524194 - [INFO ] - EASY_DIR is not set!
    2019-08-08 12:43:01.305866455 - [INFO ] - trying to detect it...
    2019-08-08 12:43:01.313189982 - [INFO ] - found EASY_DIR=/home/someuser/docker-nginx-http-proxy
    2019-08-08 12:43:01.314281920 - [INFO ] - EASY_LETSENCRYPT_DIR is not set!
    2019-08-08 12:43:01.315325243 - [INFO ] - using /home/someuser/.letsencrypt
    2019-08-08 12:43:01.316717161 - [INFO ] - Invalid command: 
    2019-08-08 12:43:01.317742360 - [INFO ] - Available commands are:
        proxy

To avoid seeing this all the time, just define the following environment variables into your profile file:

    export EASY_DIR=/path_where_you_cloned_this_repo
    export PATH=$PATH:$EASY_DIR
    export EASY_LETSENCRYPT_DIR=/some_persistent_backed_up_folder

Then when you execute the `easy` command you get:

    2019-08-08 12:53:13.849889079 - [INFO ] - Invalid command: 
    2019-08-08 12:53:13.852380349 - [INFO ] - Available commands are:
        proxy    

# help

For obtaining a list of possible commands that you can use with `easy proxy` you can try the command `easy proxy help`

    easy proxy help
    usage:
        easy proxy sh
        easy proxy log
        easy proxy build
        easy proxy new
        easy proxy status
        easy proxy stop
        easy proxy destroy
        easy proxy restart
        easy proxy reload
        easy proxy certbot
        easy proxy help

# easy proxy

The undocumented command `easy proxy` starts the nginx proxy.

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
