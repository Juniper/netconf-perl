FROM ubuntu:14.04

RUN apt-get update && apt-get install -y perl libssh2-1-dev zlib1g-dev libyaml-appconfig-perl \
  libconfig-yaml-perl make libxml2 libxml2-dev libnet-ssh2-perl libfile-which-perl libxml-libxml-perl

COPY . /src

WORKDIR /src

RUN perl Makefile.PL && make && make install

ENTRYPOINT ["/bin/bash"]

#  && PERL_MM_USE_DEFAULT=true cpan install Net::SSH2 \
#  && PERL_MM_USE_DEFAULT=true cpan install File::Which \
#  && PERL_MM_USE_DEFAULT=true cpan install XML::LibXML \
