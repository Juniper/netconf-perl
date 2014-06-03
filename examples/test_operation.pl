use Net::Netconf::Manager;

print"\nhostname:  ";
my $hostname = <>;
print"\nusername: ";
my $login= <>;
print"\npassword: ";
my $pass = <>;
chomp($hostname);
chomp($login);
chomp($pass);

$jnx = new Net::Netconf::Manager( 'access' => 'ssh',
        'login' => $login,
        'password' => $pass,
        'hostname' => $hostname);

if(! $jnx ) {
print STDERR "Unable to connect to Junos device \n";
exit 1;
}

print "Connection established: " . $jnx->get_session_id . "\n";

#my $reply = $jnx->get_route_information(destination => '192.168/16');
#my $reply=$jnx->get_aallwlarm_information();
my $reply=$jnx->get_system_information();

print "Server request is : \n $jnx->{'request'}\n Server response is: \n $jnx->{'server_response'} \n";

print "Rpc reply from server.\n";
print ">>>>>>>>>>\n";
print $reply;
print "<<<<<<<<<<\n";

if ($jnx->has_error) {
    print "ERROR: in processing request\n";
    # Get the error
    my $error = $jnx->get_first_error();
    $jnx->print_error_info(%$error);
    exit 1;
}

#parsing reply from server
#by using XML::LibXMl::DOM function
print "\n using XML::LibXMl::DOM function\n";
my $config= $jnx->get_dom();
$res= $config->getElementsByTagName("hardware-model")->item(0)->getFirstChild->getData;
$res2= $config->getElementsByTagName("os-name")->item(0)->getFirstChild->getData;
$res3= $config->getElementsByTagName("host-name")->item(0)->getFirstChild->getData;
print "\nhardware information  ". $res ."\n";
print "os-name  " .$res2 . "\n";
print "host-name  ". $res3. "\n";

#by using xml::libxml::xpathcontext
print "\n using xpath \n";
my $config= $jnx->get_dom();
my $xpc = XML::LibXML::XPathContext->new($config);
$val1=$xpc->findnodes('/*[local-name()="rpc-reply"]/*[local-name()="system-information"]/*[local-name()="hardware-model"]');
$val2=$xpc->findnodes('/*[local-name()="rpc-reply"]/*[local-name()="system-information"]/*[local-name()="os-name"]');
$val3=$xpc->findnodes('/*[local-name()="rpc-reply"]/*[local-name()="system-information"]/*[local-name()="host-name"]');

print "\nhardware information  ". $val1 ."\n";
print "os-name  " .$val2 . "\n";
print "host-name  ". $val3. "\n";

$jnx->close_session();
$jnx->disconnect();
