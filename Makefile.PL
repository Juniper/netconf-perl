use ExtUtils::MakeMaker;

our $VERSION ='1.04';
use 5.006;

WriteMakefile(
    NAME         => 'Net-Netconf',
    AUTHOR       => 'Juniper Networks, Inc',
    VERSION_FROM => 'Makefile.PL',
    PREREQ_PM => {'XML::LibXML' => '0', 'File::Which' => '0', 'Net::SSH2' => '0'},
    ABSTRACT     => 'NETCONF client library for Perl',
    LICENSE    => apache,
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
              type => 'git',
              web  => 'https://github.com/Juniper/netconf-perl',
              url  => 'https://github.com/Juniper/netconf-perl.git',
            },
        },
    },
   
);

