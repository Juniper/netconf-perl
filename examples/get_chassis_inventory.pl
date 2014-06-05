################################################################
# get_chassis_inventory.pl
# 
# Description
#    Run a JUNOScript operation mode command:
#    <rpc>
#      <get-chassis-inventory>
#        <detail/>
#      </get-chassis-inventory>
#    </rpc>
#    Steps:
#      Connect to a Netconf server
#      Run "get_chassis_inventory"
#      Display the result
#      Disconnect from the Netconf server
# ##############################################################

use strict;
use Carp;
use Getopt::Std;
use Term::ReadKey;
use Net::Netconf::Manager;

################################################################
# output_usage
#
# Description:
# print the usage of this script
#   - on error
#   - when the user requests for help
################################################################
sub output_usage
{
    my $usage = "Usage: $0 [options] <target>

Where:

  <target>   The hostname of the target router.

Options:

  -l <login>    A login name accepted by the target router.
  -p <password> The password for the login name.
  -m <access>   Access method. The only supported method is 'ssh'.
  -d <level>    Debug level [1-6]\n\n";

    croak $usage;
}

################################################################
# print_response
#
# Description:
# print the server response to '$xmlfile'
################################################################
sub print_response
{
    my ($xmlfile, $reply) = @_;
    my $FD;
    open(FD, "> $xmlfile") or die "Could not open file";
    $reply =~ s/<rpc-reply xmlns=.*>//g;
    $reply =~ s/<\/rpc-reply>//g;
    print FD $reply;
    close(FD);
}

################################################################
# Get the user input
################################################################
# Set AUTOFLUSH to true
$| = 1;


# Set AUTOFLUSH to true
$| = 1;

# get the user input and display usage on error
# or when user wants help
my %opt;
getopts('l:p:d:m:h', \%opt) || output_usage();
output_usage() if $opt{'h'};

# Get the hostname
my $hostname = shift || output_usage();

# Get the access method, can be ssh only
my $access = $opt{'m'} || 'ssh';
use constant VALID_ACCESS_METHOD => 'ssh';
output_usage() unless (VALID_ACCESS_METHOD =~ /$access/);

# Get the debug level
my $debug_level = $opt{'d'};

# Check for login name. If not provided, prompt for it
my $login = "";
if ($opt{'l'}) {
    $login = $opt{'l'};
} else {
    print STDERR "login: ";
    $login = ReadLine 0;
    chomp $login;
}

# Check for password. If not provided, prompt for it
my $password = "";
if ($opt{'p'}) {
    $password = $opt{'p'};
} else {
    print STDERR "password: ";
    ReadMode 'noecho';
    $password = ReadLine 0;
    chomp $password;
    ReadMode 'normal';
    print STDERR "\n";
}

# Now create the device information to send to Net::Netconf::Manager
my %deviceinfo = (
        'access' => $access,
        'login' => $login,
        'password' => $password,
        'hostname' => $hostname,
);

if ($debug_level) {
    $deviceinfo{'debug_level'} = $debug_level;
}

# connect to the Netconf server
my $jnx = new Net::Netconf::Manager(%deviceinfo);
unless (ref $jnx) {
    croak "ERROR: $deviceinfo{hostname}: failed to connect.\n";
}

my $query = "get_chassis_inventory";

# send the command and get the server response
my $res = $jnx->$query;
print "Server request: \n $jnx->{'request'}\n Server response: \n $jnx->{'server_response'} \n";

# See if you got an error
if ($jnx->has_error) {
    croak "ERROR: in processing request \n $jnx->{'request'} \n";
} else {
print "Server request is : \n $jnx->{'request'}\n Server response is: \n $jnx->{'server_response'} \n";

print "Rpc reply from server.\n";
print ">>>>>>>>>>\n";
print $res;
print "<<<<<<<<<<\n";

}

# Disconnect from the Netconf server
$jnx->disconnect();
