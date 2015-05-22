use ExtUtils::MakeMaker;

our $VERSION ='1.02';
use 5.006;

WriteMakefile(
    NAME         => 'Net-Netconf',
    AUTHOR       => 'Juniper Networks, Inc',
    VERSION_FROM => 'Makefile.PL',
    PREREQ_PM => {'XML::LibXML' => '0', 'File::Which' => '0', 'Net::SSH2' => '0'},
    ABSTRACT     => 'netconf libraries for perl',
    #LICENSE      => 'perl', ???
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

