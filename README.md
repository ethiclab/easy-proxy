# inspired by

This project was initially loosly inspired by https://github.com/jwilder/nginx-proxy 

# what

The idea behind this project is to be able to provision web interfaces and expose them through a reverse proxy by using a CLI interface.

If you are a network administrator within your company, or if you only need to setup a test environment, this proxy can be useful.

For instance, let's say that you have a joomla server running on port 8888 somewhere in your network, for instance at address 192.168.1.123, and let's say that you have an http server running on port 80 in a server that is configured to be reached from internet by accessing the root domain example.com as well as the subdomains; for instance, a.example.com, b.example.com, etc.

If you want to expose your joomla instance, you have to setup a reverse proxy within the exposed http server so that every request to myjoomla.example.com, for instance, is transparently forwarded to 192.168.1.123:8888

In order to do that you have to manually edit nginx configuration or add a manually created file within the sites-available folder.

Things get more complicated if you want to use SSL.

This project tries to solve this by providing a CLI interface that allows you to provision a new subdomain site without editing any nginx configuration file manually.

# getting started

    npm install -g @ethiclab/easy-cli
    easy

You should see and output like:

    2019-08-08 12:43:01.303524194 - [INFO ] - EASY_DIR is not set!
    2019-08-08 12:43:01.305866455 - [INFO ] - trying to detect it...
    2019-08-08 12:43:01.313189982 - [INFO ] - found EASY_DIR=/home/someuser/.nvm/versions/node/v10.16.2/lib/node_modules/@ethiclab/easy-cli
    2019-08-08 12:43:01.314281920 - [INFO ] - EASY_LETSENCRYPT_DIR is not set!
    2019-08-08 12:43:01.315325243 - [INFO ] - using /home/someuser/.letsencrypt
    2019-08-08 12:43:01.316717161 - [INFO ] - Invalid command: 
    2019-08-08 12:43:01.317742360 - [INFO ] - Available commands are:
        proxy

To avoid seeing this all the time, just define the following environment variables into your profile file:

    export EASY_DIR=/home/someuser/.nvm/versions/node/v10.16.2/lib/node_modules/@ethiclab/easy-cli
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

If you obtain something like:

    easy proxy
    Unable to find image 'ethiclab/nginx-easy:latest' locally
    docker: Error response from daemon: manifest for ethiclab/nginx-easy:latest not found.
    See 'docker run --help'.
    
It means that you need to build the docker image first. Please execute the following command first:

    easy proxy build

# create domains folder

A `domains` folder has to be created under `$EASY_DIR/easyhome` and write access has to be enabled for `others`.

    mkdir $EASY_DIR/easyhome/domains
    chmod o+w $EASY_DIR/easyhome/domains

# start nginx proxy (needs docker)

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
