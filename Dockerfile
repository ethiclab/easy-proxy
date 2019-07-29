FROM ubuntu:18.10
USER root
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
&& apt-get update \
&& apt-get install -y software-properties-common \
&& add-apt-repository ppa:certbot/certbot \
&& apt-get update \
&& apt-get install -y nginx python-certbot-nginx python-pip vim sudo \
&& pip install Cheetah3 \
&& echo "www-data ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data
USER www-data
VOLUME ["/etc/letsencrypt", "/usr/local/share/easy"]
CMD ["/usr/local/share/easy/easy-proxy-start"]
