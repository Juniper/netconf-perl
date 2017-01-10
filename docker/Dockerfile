FROM ubuntu:14.04

RUN apt-get update && apt-get install -y perl libssh2-1-dev zlib1g-dev libyaml-appconfig-perl \
  libconfig-yaml-perl make libxml2 libxml2-dev libnet-ssh2-perl libfile-which-perl libxml-libxml-perl

COPY . /src

RUN cd /src && perl Makefile.PL && make && make install

WORKDIR /scripts

ENTRYPOINT ["/bin/bash"]
