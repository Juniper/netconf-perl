# Net::Netconf::Device - Implements a remote Netconf device

package Net::Netconf::Device;
use strict;
use Net::Netconf::Trace;
use Net::Netconf::Constants;
use Net::Netconf::Access;
use XML::LibXML;
use XML::LibXML::SAX;
use XML::LibXML::SAX::Parser;
use Net::Netconf::SAXHandler;
use File::Basename;
use Carp;
no strict 'subs';
require Exporter;

use vars qw(@EXPORT);
use vars qw(@ISA);
use vars qw($AUTOLOAD);

our $VERSION ='1.02';
my $NO_ARGS = bless {}, 'NO_ARGS';
my $TOGGLE = bless { 1 => 1 }, 'TOGGLE';
my $TOGGLE_NO = bless {}, 'TOGGLE';
my $STRING = bless {}, 'STRING';
my $DOM = bless {}, 'DOM';
my $ATTRIBUTE = bless {}, 'ATTRIBUTE';

my $URL_STRING = bless {}, 'URL_STRING';
my $DOM_STRING = bless {}, 'DOM_STRING';
my $message_id = 1; # message-id for the rpc request

# Capabilities supported
my $capability = 'http://xml.juniper.net/netconf/junos/1.0';

my %methods = (
    'get_xnm_information' => {
	'type' => $STRING,
	'namespace' => $STRING
    },
    'get' => {
        filter => $DOM
    },
    'lock_config' => {
        'tag_name' => 'lock',
        'target'  => $DOM_STRING,
        'target_url' => $URL_STRING 
    },
    'unlock_config' => {
        'tag_name' => 'unlock',
        'target'  => $DOM_STRING,
        'target_url' => $URL_STRING 
    },
    'kill_session' => {
        'session_id' => $STRING
    },
    'close_session' => $NO_ARGS,
    'get_config' => {
        'source' => $DOM_STRING,
        'source_url' => $URL_STRING,
        'filter' => $DOM
    },
    'edit_config' => {
        'operation' => $ATTRIBUTE,
        'target'  => $DOM_STRING,
        'default_operation' => $STRING,
        'test-option' => $STRING,
        'error-option' => $STRING,
        'url' => $STRING,
        'config' => $DOM,
        'config-text' => $STRING
    },
    'copy_config' => {
        'target'  => $DOM_STRING,
        'target_url' => $URL_STRING,
        'source' => $DOM_STRING,
        'source_url' => $URL_STRING,
   },
   'delete_config' => {
        'target'  => $DOM_STRING,
        'target_url' => $URL_STRING,
   },
   'discard_changes' => $NO_ARGS,
   'commit' => {
       'confirmed' => $TOGGLE,
       'confirm_timeout' => $STRING
   },
   'validate' => {
        'source' => $DOM_STRING,
        'source_url' => $URL_STRING,
   },
   'get_database_status_information' => $NO_ARGS,
);

#client's capabilities
my %capabilities = (
    'urn:ietf:params:xml:ns:netconf:base:1.0' =>
        [ 'get', 'get_config', 'edit_config', 'copy_config', 'delete_config',
          'lock_config', 'unlock_config', 'close_session', 'kill_session',
          'discard_changes'],
    'urn:ietf:params:xml:ns:netconf:capability:candidate:1.0' => [ 'commit' ],
    'urn:ietf:params:xml:ns:netconf:capability:confirmed-commit:1.0' => [],
    'urn:ietf:params:xml:ns:netconf:capability:validate:1.0' => [ 'validate' ],
    'urn:ietf:params:xml:ns:netconf:capability:url:1.0?protocol=http,ftp,file' => [],
);

# get the message id
sub get_msg_id {
    return $message_id++;
}

# Create a new Netconf device object
# Connect to the Netconf server
sub new
{
    my ($class, %args) = @_;
    my $self = { %args };

    # Make sure we have 'login', 'hostname' and 'password'
    croak 'missing information <hostname>' unless exists $args{'hostname'};
    croak 'missing information <login>' unless exists $args{'login'};
    croak 'missing information <password>' unless exists $args{'password'};

    # SAX Parser
    my $handler = new Net::Netconf::SAXHandler('ErrorContext' => 5);
    my $saxparser = new XML::LibXML::SAX::Parser('Handler' => $handler)
                 || croak 'Cannot create parser: ' . $!;
    $self->{'sax_parser'} = $saxparser;

    # DOM parser
    my $domparser = XML::LibXML->new();
    $self->{'dom_parser'}= $domparser;

    # Bless ourselves
    $class = ref($class) || $class;
    bless $self, $class;

    # Connection state
    $self->{'conn_state'} = Net::Netconf::Constants::NC_STATE_DISCONN;
    
    # Default trace level: WARNING_LEVEL
    $self->{'debug_level'} = Net::Netconf::Trace::WARNING_LEVEL unless
    $self->{'debug_level'};

    # Create the trace object
    $self->{'trace_obj'} = new Net::Netconf::Trace($self->{'debug_level'});

    # Now bring up the connection
    return $self->connect() unless $self->{'do_not_connect'};
    $self;
}

# Open a connection to the Netconf server
sub connect
{
   my($self) = @_;
    my $conn;
    my $trace_obj = $self->{'trace_obj'};
    $trace_obj->trace(Net::Netconf::Trace::TRACE_LEVEL, 'preparing to connect');

    # If we are already connected, we have the connection object
    # in $self->{conn_obj}
    return $self if $self->{'conn_obj'};

    eval {
        $conn = new Net::Netconf::Access($self);    # $self = ssh , connect to ssh 
    };

    if ($@ || !ref($conn)) {
        croak 'unable to create Access object' . $@;
    }

    eval 'use ' . ref($conn);
    if ($@) {
        croak 'unable to create Access object using ' . $self->{'access'} . $@;
    }

    $self->{'conn_obj'} = $conn;
    unless (defined ($conn->connect())) {
        croak 'unable to connect to the Netconf server';
    }

    $self->send_and_recv_hello();
    $self;
}

# - If the user specifies client capabilities, it uses that to generate 
# the client hello. Else, it uses the default capability list given
# by Net::Netconf::Constants::NC_DEFAULT_CAP.
# - Does the hello exchange
# - Parses the server hello to get the server capabilities
# - Initializes the Netconf API based on the server capabilities
sub send_and_recv_hello
{
    my($self) = shift;
    my $msg;
    my $conn = $self->{'conn_obj'};
    my $traceobj = $self->{'trace_obj'};
    my @server_capabilities;

    # Generate the client capability using the capabilities passed to it
    my $client_capability = <<EOF;
<hello>
  <capabilities>
EOF

    my $cap = $self->{'client_capabilities'};
    if ($cap) { # Client has specified some capability use that
        foreach my $capelmt (@$cap) {
            $client_capability .= <<EOF;
    <capability>$capelmt</capability>
EOF
        }
    } else { # Use the default capability
        my $default_capability = Net::Netconf::Constants::NC_DEFAULT_CAP;
        $client_capability .= "    $default_capability\n";
    }
    $client_capability .= <<EOF;
  </capabilities>
</hello>
EOF

    # Send our capabilities to the Netconf server
    # Get the server capability
    my $server_cap = $self->send_and_recv_rpc($client_capability, 
            Net::Netconf::Constants::NC_HELLO_TAG,
            Net::Netconf::Constants::NC_STATE_HELLO_SENT,
            Net::Netconf::Constants::NC_STATE_HELLO_RECVD);

    $self->{'conn_state'} = Net::Netconf::Constants::NC_STATE_CONN;

    # Tracing what is going on
    $traceobj->trace(Net::Netconf::Trace::DEBUG_LEVEL, <<EOF);
Client capability sent:
$client_capability
Server capability received:
$server_cap
EOF

    # Parse the server hello to extract the capabilities
 
     eval {
        $self->{'sax_parser'}->parse_string($server_cap);
};

    if ($@) {
    $self->report_error(1, 'error in parsing server capability');
 }

    # Now save the session-id and server capabilities
    $self->{'session_id'} = $Net::Netconf::SAXHandler::session_id;
    @{$self->{'server_capabilities'}} = @Net::Netconf::SAXHandler::parsed_cap;

    # See if any errors were emitted and save them
    $self->{'found_rpc_errors'} = $Net::Netconf::SAXHandler::found_error;
    if ($self->{'found_rpc_errors'}) {
       %{$self->{'rpc_errors'}} = (%Net::Netconf::SAXHandler::rpc_errors);
   }
    $self;
}

# This returns the server capability for Netconf session
sub get_server_cap
{
    my ($self) = @_;
    return @{$self->{'server_capabilities'}};
}

# Disconnect from the Netconf server
# Free up resources
sub disconnect
{
    my($self) = @_;
    my $conn = $self->{'conn_obj'};
    $conn->disconnect if ($conn and $self->{'conn_state'} !=
    Net::Netconf::Constants::NC_STATE_DISCONN && not $conn->eof);
}

# Helper function for sending and receiving Netconf commands and responses
# $xml = the xml string to send
# $endtag = we should read data till we find this tag (optional)
# $state_sent = state after we sent the data (optional)
# $state_recv = state after we receive data (optional)
sub send_and_recv_rpc
{
my($self, $xml, $endtag, $state_sent, $state_recv) = @_;
    return unless ($xml);
    my $conn = $self->{'conn_obj'};
    my $traceobj = $self->{'trace_obj'};
    my $in = '';
    my $msg;
    return unless ($xml);

    # Set the default values
    $state_sent = Net::Netconf::Constants::NC_STATE_REQ_SENT 	unless ($state_sent);
    $state_recv = Net::Netconf::Constants::NC_STATE_REQ_RECVD   unless ($state_recv);
    $endtag 	= Net::Netconf::Constants::NC_REPLY_TAG 		unless ($endtag);

    # Send the request to the Netconf server
    unless ($conn->send($xml)) {
        carp 'failed to send user request';
        return;
    };
    
    $self->{'conn_state'} = $state_sent;
	
    # Get a response from the Netconf server   
    $in = $self->read_rpc( $endtag );
	$self->parse_response( $in );
}

# Helper function to read RPC response until end tag
sub read_rpc 
{
	my $self 	= shift;
	my $endtag 	= shift;
	
	my $conn 	= $self->{'conn_obj'};
	my $in 		= '';
	
	while ( $self->{'conn_state'} != Net::Netconf::Constants::NC_STATE_HELLO_RECVD ) 
	{
		if ($conn->eof) {
			$self->report_error(1, 'connection to Netconf server lost');
			return undef;
		}
        
		$in .= $conn->recv();
		# Check to see if you received the end-tag
		if ($in =~ /<\/\s*$endtag\s*>/gs)
		{
           $self->{'conn_state'} = Net::Netconf::Constants::NC_STATE_HELLO_RECVD;
		} 
		elsif ($conn->eof)
		{
			$self->report_error(1, 'connection to Netconf server lost');
			return undef;
		}
    }
	
	return $in;
}

# Once we receive the response from the server, we call this method before passing
# the response to the parser. We strip the response off the namespace values.
sub parse_response
{
    my ($self, $response) = @_;
    return unless $response;
    $self->{'found_rpc_errors'} = 0;
    $self->{'rpc_errors'} = undef;
    # For junos:style, junos:format stuff which gives error while parsing
    $response =~ s/junos://g;
    $self->{'server_response'} = $response;
    eval {
        $self->{'sax_parser'}->parse_string($response);
    };
    if ($@) { #parse error
        carp 'error in parsing server response ' . "\n" . $response . "\n" . $@;
        return $self->{'server_response'};
    }

    # Save the total number of <rpc-error>s received and error information

    $self->{'found_rpc_errors'} = $Net::Netconf::SAXHandler::found_error; 
    # found_error an attribute of SAXHandler

    $self->{'no_error'} = $Net::Netconf::SAXHandler::no_error;
    #no_error an attribute of SAXHandler

    # We should not get both <rpc-error> and <ok/>
    #if ($self->{'found_rpc_errors'} && $self->{'no_error'}) {
            #    carp 'error in server response: has both <rpc-error> and <ok/> ' . 
            #"\n" . $response . "\n" . $@;
            #return $self->{'server_response'};
            #}

    if ($self->{'found_rpc_errors'}) {
        %{$self->{'rpc_errors'}} = (%Net::Netconf::SAXHandler::rpc_errors);
    }
    # Then we return the response as a string
  return $self->{'server_response'};
}

# This creates a DOM tree from the server response and returns it
# This is useful for <get> and <get-config> operations
sub get_dom
{
    print "inside dom object";
    my($self) = @_;
    # Create a DOM object and return that.
    # Server response is in: $self->{server_response} 
    my $doc = $self->{'dom_parser'}->parse_string($self->{'server_response'});
    $self->{'doc'} = $doc;
    return $self->{'doc'};
}

# This returns the session ID for this Netconf session
sub get_session_id
{
    my ($self) = @_;
    return $self->{'session_id'};
}

# This returns the number of errors returned by the server
sub has_error
{
    my ($self) = shift;
    return $self->{'found_rpc_errors'};
}

# This returns the first <rpc-error> emitted by the server as a hash reference.
# This also prints the errors in debug mode
sub get_first_error
{
    my($self) = shift;
    return unless ($self->{'found_rpc_errors'});
    $self->print_error_info(1);
    return $self->{'rpc_errors'}{1};
}

# This returns all the errors emitted by the server as a hash reference
# This also prints the errors in debug mode
sub get_all_errors
{
    my($self) = @_;
    return unless ($self->{'found_rpc_errors'});
    my $indx = 1;
    while ($indx <= $self->{'found_rpc_errors'}) {
        $self->print_error_info($indx);
        $indx++;
    }
    return $self->{'rpc_errors'};
}

# This prints the server error messages if in DEBUG_LEVEL
sub print_error_info
{
    my $self = shift;
    confess 'Usage: ' . __PACKAGE__ . '::print_error_info <key>' unless @_ == 1;
    my $key = @_;
    my $trace_obj = $self->{'trace_obj'};
    my @error_tag = (
            'error_type',
            'error_tag',
            'error_severity',
            'error_path',
            'error_message',
            'error_info');
    $trace_obj->trace(Net::Netconf::Trace::DEBUG_LEVEL, 
                      'Server response HAD ERRORS ....');
    foreach my $tag (@error_tag) {
        if ($self->{'rpc_errors'}{$key}{$tag}) {
            $trace_obj->trace(Net::Netconf::Trace::DEBUG_LEVEL, 
                    $tag . '=' . $self->{'rpc_errors'}{$key}{$tag});
        }
    }
}

# This prints the error message and quits the program based on $level
# $level > 0  means this is a fatal error, so quit
sub report_error
{
    my $self = shift;
    confess 'Usage: ' . __PACKAGE__ . '::report_error <level> <message>' 
    unless @_ == 2;
    my ($level, $msg) = @_;
    if ($level) {
        $self->{'conn_obj'} = undef;
        $self->{'trace_obj'} = undef;
      #  $self->{'sax_parser'} = undef;
        croak $msg;
    }
    carp $msg;
}

#This function generate rpc and call send_and recv_rpc() method
sub generate_rpc
{
    my ($self,$fn, %args) = @_;
    my $bindings = $methods{ $fn };
    my $output = "";
    my $tag = "";
    my $attrs = "";
    my $url = "";
    my $msg_id = &get_msg_id;

    foreach my $field (keys(%args)) {
	my $type = $bindings->{ $field };
	my $value = $args{ $field };

	($tag = $field) =~ s/_/-/g;

	if (ref($type) eq 'TOGGLE' || ref($value) eq 'TOGGLE' || $value eq 'True') {
	    if ($value ne '0') {
		$output .= "    <$tag/>\n";
	    }

	} elsif (ref($value) eq 'TOGGLE_NO') {
	    if ($value eq '0') {
		$output .= "    <no-$tag/>\n";
	    } else {
		$output .= "    <$tag/>\n";
	    }

	} elsif (ref($type) eq 'STRING') {
	    $output .= "    <${tag}>${value}</${tag}>\n";

	} elsif (ref($type) eq 'URL_STRING') {
            ($tag, $url) = split(/[-_]/, $field);
	    $output .= "    <${tag}><${url}>${value}</${url}></${tag}>\n";
  	}elsif (ref($type) eq 'DOM_STRING') {
            if ($value =~ '<\/') {
                $output .= "    <${tag}>${value}</${tag}>\n";
            } else {
                $output .= "    <${tag}><${value}/></${tag}>\n";
            }
       	}elsif ($type =~ /(\d)+\.\.(\d)+/) {
	    $output .= "    <${tag}>${value}</${tag}>\n";

	} elsif (ref($type) eq 'DOM') {
	    $output .= $value->toString;
	    $output .= "\n";

	} elsif (ref($type) eq 'ATTRIBUTE') {
	    $attrs .= " ${tag}=\"${value}\"\n";

	} elsif (ref($value)) {
	    $output .= $value->toString;
	    $output .= "\n";

	} else {
	    $output .= "    <${tag}>${value}</${tag}>\n";
	}
    }
 	if ($bindings->{'tag_name'}) {
        $fn = $bindings->{'tag_name'};
    }
	
	($tag = $fn) =~ s/_/-/g;

        if ($output) {
	$output = "<rpc message-id=\'$msg_id\'>\n  <${tag}${attrs}>\n${output}  </${tag}>\n</rpc>\n";
    } 
        else {
	$output = "<rpc message-id=\'$msg_id\'>\n  <${tag}${attrs}/>\n</rpc>\n";
    }
       $self->{'request'} = $output;      
       my $response = $self->send_and_recv_rpc($output);
       my $traceobj = $self->{'trace_obj'};
       $traceobj->trace(Net::Netconf::Trace::DEBUG_LEVEL,<<EOF);
       SERVER REQUEST:
       $output
       SERVER RESPONSE:
       $response
EOF
}

# This will be removed after the <get-config> accepts parameters in any order
sub get_config
{
    my ($self,%args) = @_;
    my $msg_id = &get_msg_id;
    my $request = '<rpc message-id=\'' . $msg_id . '\'>';
    $request .= '<get-config> <source>';
    if (exists $args{'source_url'}) {
        $request .= '<url> <';
        $request .= $args{'source_url'};
        $request .= '/> </url> </source>';
    } elsif (exists $args{'source'}) {
        $request .= '<';
        $request .= $args{'source'};
        $request .= '/> </source>';
    }
    $request .= $args{filter};
    $request .= '</get-config> </rpc>';
    $self->send_and_recv_rpc($request);
}

# This will be removed after the <edit-config> accepts parameters in any order
sub edit_config
{
    my ($self,%args) = @_; 
    my $msg_id = &get_msg_id;
    my $request = '<rpc message-id=\'' . $msg_id;
    if (exists $args{'operation'}) {
        $request = 'operation=\'' . $args{'operation'};
    }
    $request .= '\'>';
    $request .= '<edit-config> <target>';
    if (exists $args{'target'}) {
        $request .= '<';
        $request .= $args{'target'};
        $request .= '/> </target>';
    }

    if (exists $args{'default_operation'}) {
        $request .= '<default-operation>';
        $request .= $args{'default_operation'};
        $request .= '</default-operation>';
    }

    if (exists $args{'test_option'}) {
        $request .= '<test-option>';
        $request .= $args{'test_option'};
        $request .= '</test-option>';
    }
    
    if (exists $args{'error_option'}) {
        $request .= '<error-option>';
        $request .= $args{'error_option'};
        $request .= '</error-option>';
    }

    if (exists $args{'url'}) {
        $request .= '<url>' . $args{'url'} . '</url>';
    } elsif (exists $args{'config-text'}) {
        $request .= '<config-text>' . $args{'config-text'} . '</config-text>';
    } else {
        $request .= '<config>' . $args{'config'} . '</config>';
    }
    $request .= '</edit-config> </rpc>';
    $self->send_and_recv_rpc($request);
}

sub AUTOLOAD
{
    my ($self, @args) = @_;
    my $fn = substr($AUTOLOAD, rindex($AUTOLOAD, '::') + 2);
    return if $AUTOLOAD =~ /::DESTROY$/;
    $self->generate_rpc($fn, @args);
}

1;

__END__

=head1 NAME

Net::Netconf::Device - Implements a remote Netconf device

=head1 SYNOPSIS

The Net::Netconf::Device module implements a remote Netconf device. It can be
used to connect and talk to a Netconf server.

=head1 DESCRIPTION

The Net::Netconf::Device module implements an object-oriented interface to the
Netconf API supported by Juniper Networks. Objects of this class represent the
local side of connection to a Juniper Networks device running JUNOS, over which
the Netconf protocol will be spoken.

=head1 EXAMPLE

This example connects to a Netconf server, locks the candidate database, updates
the router's configuration, commits the changes and closes the Netconf session.
It also does error handling.

    use Net::Netconf::Device;

    # State information constants
    use constant STATE_CONNECTED => 0;
    use constant STATE_LOCKED => 1;
    use constant STATE_EDITED => 2;

    # Variables used
    my $response;

    my %deviceargs = (
      'hostname' => 'routername',
      'login' => 'loginname',
      'password' => 'secret',
      'access' => 'ssh',
      'server' => 'netconf',
      'debug_level' => 1,
      'client_capabilities' => [
        'urn:ietf:params:xml:ns:netconf:base:1.0',
        'urn:ietf:params:xml:ns:netconf:capability:candidate:1.0',
        'urn:ietf:params:xml:ns:netconf:capability:confirmed-commit:1.0',
        'urn:ietf:params:xml:ns:netconf:capability:validate:1.0',
        'urn:ietf:params:xml:ns:netconf:capability:url:1.0?protocol=http,ftp,file',
        'http://xml.juniper.net/netconf/junos/1.0',
          ]
    );

    my $device = new Net::Netconf::Device(%deviceargs);
    print 'Could not create Netconf device' unless $device;

    # Lock the configuration datastore
    $response = $device->lock_config(target => 'candidate');
    graceful_shutdown($device, STATE_CONNECTED) if ($device->has_error);

    # Edit the configuration
    my %editargs = (
        target => 'candidate',
        config => '<config>
                     <configuration>
                       <interfaces>
                         <interface>
                           <name>fe-0/0/0</name>
                           <mtu>1200</mtu>
                         </interface>
                       </interfaces>
                     </configuration>
                   </config>'
    );

    $response = $device->edit_config(%editargs);
    graceful_shutdown($device, STATE_LOCKED) if ($device->has_error);

    # Commit the changes
    $response = $device->commit();
    graceful_shutdown($device, STATE_EDITED) if ($device->has_error);

    # Close the session
    $response = $device->close_session();
    print 'Unable to close the Netconf session' if ($device->has_error);
    # Disconnect
    $device->disconnect();

    sub graceful_shutdown
    {
        my ($device, $state) = @_;

        # Could not commit
        if ($state >= STATE_EDITED) {
            print "Failed to commit changes..So, discarding the changes...\n";
            $device->discard_changes();
        }

        # Could not edit the config
        if ($state >= STATE_LOCKED) {
            print "Failed to edit the configuration...\n";
            $device->unlock();
        }

        # Could not lock the candidate config
        if ($state >= STATE_CONNECTED) {
            print "Failed to lock the candidate datastore...\n";
            $device->close_session();
            $device->disconnect();
        }
        exit 0;
    }

=head1 CONSTRUCTOR

new(%ARGS)

The constructor accepts a hash table %ARGS containing the following keys:

=over 4

=item hostname

Name of Juniper box to connect to.

=item login

Username to log into box as.

=item password

Password for login username.

=item access

Access method - can be 'ssh' only.

=item server

The server to connect to. Default is 'netconf'.

=item debug_level

The debugging level. Debug level = 1, Trace level = 2, Information level = 3,
Warning level = 4, Error level = 5, Critical level = 6.

=item client_capabilities

The capabilities supported by the client as an array reference.

=back

=head1 METHODS

=over 4

=item  connect()

This is called by the constructor to connect to a Netconf server.

=item disconnect()

Disconnects from a Netconf server and performs other clean-up operations.

=item has_error

Returns the number of <rpc-error> tags seen in the Netconf server response.

=item get_first_error

Returns a hash containing the first <rpc-error> message returned by the Netconf
server on the last request. The hash keys include error_severity, error_message
etc.

=item get_all_errors

Returns a hash containing all the <rpc-error> messages returned by the Netconf
server key-ed by the error number.

=head1 SEE ALSO

=over 4

=item *

Net::Netconf::Manager

=item *

Net::Netconf:Trace

=back
=head1 AUTHOR

Juniper Networks Perl Team, send bug reports, hints, tips and suggestions to
netconf-support@juniper.net.

