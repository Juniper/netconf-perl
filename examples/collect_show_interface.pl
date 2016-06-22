#!/usr/bin/perl

use Net::Netconf::Manager;
use warnings;
use strict;
use XML::XPath;

my $hostname = "10.254.254.100";
my $login= "lab";
my $pass = "lab123";

my $jnx = new Net::Netconf::Manager( 'access' => 'ssh',
              'login' => $login,
              'password' => $pass,
              'hostname' => $hostname);

if(! $jnx ) {
  print STDERR "Unable to connect to Junos device \n";
  exit 1;
}

print "Connection established: " . $jnx->get_session_id . "\n";

my $query = "get_interface_information";

my %queryargs = ( 'interface-name' => 'ge-0/0/0' );

my $reply=$jnx->$query(%queryargs);

if ($jnx->has_error) {
  print "ERROR: in processing request\n";
  # Get the error
  my $error = $jnx->get_first_error();
  $jnx->print_error_info(%$error);
  exit 1;
}

open(FILEOUTPUT, ">interface_output.xml");

print FILEOUTPUT $jnx->{'server_response'};

close(FILEOUTPUT);

# this parsing is specifically for <get-interface-information> tag
# you can write your own application in similar way
# parsing reply from server

print "\n\n\n";
print "Example using XML::XPath\n----------------------------------------------\n\n";
my $interfaceOutput = XML::XPath->new(filename => 'interface_output.xml');

my $interfaceDescription = $interfaceOutput->find('/rpc-reply/interface-information/physical-interface/description');
my $interfaceIPv4Address = $interfaceOutput->find('/rpc-reply/interface-information/physical-interface/logical-interface/address-family/interface-address/ifa-local');

# Parsing using XML::XPath

print "Interface description = $interfaceDescription\n";
print "Interface address = $interfaceIPv4Address\n";

print "\n\n\n\n";

print "Example using DOM\n----------------------------------------------\n\n";
my $XMLOutput= $jnx->get_dom();
my $res= $XMLOutput->getElementsByTagName("description")->item(0)->getFirstChild->getData;
my $res2= $XMLOutput->getElementsByTagName("ifa-local")->item(0)->getFirstChild->getData;
print "\n";
print "DOM - Interface description:  " . $res . "\n";
print "DOM - Interface address  ". $res2 . "\n";
print "\n";

$jnx->disconnect();
