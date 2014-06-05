################################################################
# diagnose_bgp.pl
# 
# Description:
#    Run a JUNOScript operation mode command
#    <rpc>
#      <get-bgp-neighbor-information/>
#    </rpc>
#    Steps:
#      Connect to a Netconf server
#      Run "get_bgp_neighbor_information"
#      Display the result
#      Disconnect from the Netconf server
# ##############################################################

use Carp;
use Getopt::Std;
use Net::Netconf::Manager;

# query execution status constants
use constant REPORT_SUCCESS => 1;
use constant REPORT_FAILURE => 0;
use constant STATE_CONNECTED => 1;
use constant STATE_LOCKED => 2;
use constant STATE_CONFIG_LOADED => 3;

################################################################
# output_usage
#
# Description:
#   print the usage of this script
#     - on error
#     - when user wants help
################################################################
sub output_usage
{
   
    my $usage = "Usage: $0 [options] <target>

Where:

  <target>   The hostname of the target router.

Options:

  -s <hostname> hostname of target router
  -l <login>    A login name accepted by the target router.
  -p <password> The password for the login name.
  -m <access>   Access method. The only supported method is 'ssh'.
  -x <xmlfile>  The name of the XML file to print server response to";
  
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
# get_error_info
#
# Description:
#   Print the error information
################################################################
sub get_error_info
{
    my %error = @_;
    print "\nERROR: Printing the server request error ...\n";

    # Print 'error-severity' if present
    if ($error{'error_severity'}) {
        print "ERROR SEVERITY: $error{'error_severity'}\n";
    }

    # Print 'error-message' if present
    if ($error{'error_message'}) {
        print "ERROR MESSAGE: $error{'error_message'}\n";
    }

    # Print 'bad-element' if present
    if ($error{'bad_element'}) {
        print "BAD ELEMENT: $error{'bad_element'}\n\n";
    }
}

################################################################
# Get the user input
################################################################

# Set AUTOFLUSH to true
$| = 1;
my %opt;
our ($opt_x, $opt_t,$opt_s, $opt_l, $opt_p, $opt_h);
# get the user input and display usage on error 
# or when user wants help
getopts('s:l:p:ht:x:') || output_usage();
output_usage() if $opt_h;

my $hostname = $opt_s ||output_usage();
my $login=  $opt_l ||output_usage();
my $pass =  $opt_p ||output_usage;

my $jnx = new Net::Netconf::Manager( 'access' => 'ssh',
        'login' => $login,
        'password' => $pass,
        'hostname' => $hostname);
print "\n reply from server\n";

unless (ref $jnx) {
    croak "ERROR: $deviceinfo{hostname}: failed to connect.\n";
}

my $query = "get_bgp_neighbor_information";

# send the command and get the server response
my $res = $jnx->$query();

# See if you got an error
if ($jnx->has_error) {
    print "ERROR: in processing request\n";
    # Get the error
    my $error = $jnx->get_first_error();
    get_error_info(%$error);
    
} 
else {
print "Server request is : \n $jnx->{'request'}\n Server response is: \n $jnx->{'server_response'} \n";
print "Rpc reply from server.\n";
print ">>>>>>>>>>\n";
print $res;
print "<<<<<<<<<<\n";

# print the server response into xmlfile
#if xml file is defined then print the response in it
if ($opt_x)
{
print_response($opt_x, $res);
}
}

# Disconnect from the Netconf server
$jnx->disconnect();

