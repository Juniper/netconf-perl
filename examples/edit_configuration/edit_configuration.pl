################################################################
# edit_configuration.pl
# 
# Description:
#    Load a configuration given in some XML or text file.
#    Steps:
#      Lock the candidate database
#      Load the configuration
#      Commit the changes
#        On failure:
#          - discard the changes made
#       
#      Unlock the candidate database
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
    my $usage = "Usage: $0 [options] <request> <target>

Where:

  <request>  name of a specific file containing the configuration
             in XML or text format.

             Example of contents of the file in XML format:

             <configuration>
               <system>
                 <host-name>my-host-name</host-name>
               </system>
             </configuration>

             Example of contents of the file in text format:

             system {
               host-name my-host-name;
             }

  <target>   The hostname of the target router.

Options:

s:l:p:t:x:
  -s <hostname> hostname /server name 
  -l <login>    A login name accepted by the target router
  -p <password> The password for the login name
  -t            Loading a text configuration 
  -x            Loading a XML configuration
   h            help";

    croak $usage;
}

#################################################################
# graceful_shutdown
#
# Description:
#   We can be in one of the three states: 
#     STATE_CONNECTED, STATE_LOCKED, STATE_CONFIG_LOADED
#   Take actions depending on the current state
#################################################################
sub graceful_shutdown
{
   my ($jnx, $state, $success) = @_;
   if ($state >= STATE_CONFIG_LOADED) {
       # We have already done an <edit-config> operation
       # - Discard the changes
       print "Discarding the changes made ...\n";
       $jnx->discard_changes();
       if ($jnx->has_error) {
           print "Unable to discard <edit-config> changes\n";
       }
   }

   if ($state >= STATE_LOCKED) {
       # Unlock the configuration database
       $jnx->unlock_config();
       if ($jnx->has_error) {
           print "Unable to unlock the candidate configuration\n";
       }
   }

   if ($state >= STATE_CONNECTED) {
       # Disconnect from the Netconf server
       $jnx->disconnect();
   }

   if ($success) {
       print "REQUEST succeeded !!\n";
   } else {
       print "REQUEST failed !!\n";
   }
   exit;
}

#################################################################
# read_xml_file
#
# Description:
#   Open a file for reading, read and return its contents; Skip
#   xml header if exists
#################################################################
sub read_xml_file
{
    my $input_file = shift;
    my $input_string = "";
    open(FH, $input_file) || return;
    while(<FH>) {
        next if /<\?xml.*\?>/;
        $input_string .= $_;
    }
    close(FH);
    return $input_string;
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

# Lock the configuration database before making any changes
print "Locking configuration database ...\n";
my %queryargs = ( 'target' => 'candidate' );

$res = $jnx->lock_config(%queryargs);
print "\nlock-reply from server $res \n";

# See if you got an error
if ($jnx->has_error) {
    print "ERROR: in processing request \n $jnx->{'request'} \n";
    graceful_shutdown($jnx, STATE_CONNECTED, REPORT_FAILURE);
}

%queryargs = ( 
                 'target' => 'candidate'
             );

#Check we are in xml mode
if ($opt_x)
{
my $xmlfile =$opt_x;
my $config = read_xml_file($xmlfile);
$queryargs{'config'} = $config;

}

# If we are in text mode, use config-text arg with wrapped configuration-text
if ($opt_t) 
{
my $text_file = $opt_t;
my $config1="";
open(FH, $text_file) ||return;

while(<FH>)
{
$config1.=$_;
}
close(FH);

$queryargs{'config-text'} = '<configuration-text>' . $config1
    . '</configuration-text>';
} 

$res = $jnx->edit_config(%queryargs);
print "\nedit_config reply from server $res \n";

# See if you got an error
if ($jnx->has_error) {
    print "ERROR: in processing request\n";
    # Get the error
    my $error = $jnx->get_first_error();
    get_error_info(%$error);
    # Disconnect
    graceful_shutdown($jnx, STATE_LOCKED, REPORT_FAILURE);
}

# Commit the changes
print "Committing the <edit-config> changes ...\n";
$com=$jnx->commit();
print "\n commit reply from server $com \n\n";
if ($jnx->has_error) {
    print "ERROR: Failed to commit the configuration.\n";
    graceful_shutdown($jnx, STATE_CONFIG_LOADED, REPORT_FAILURE);
}

# Unlock the configuration database and 
# disconnect from the Netconf server
print "Disconnecting from the Netconf server ...\n";
graceful_shutdown($jnx, STATE_LOCKED, REPORT_SUCCESS);
