package Net::Netconf::Manager;

use Carp;
our $VERSION ='1.02';

# This instantiates a Junoscript or a Netconf device depending on the 'server'
# specified. Default is Netconf.
sub new
{
    my($class, %args) = @_;
    my $self = { %args };
    my $device = undef;

    # Junoscript session
    if (defined $self->{'server'} && $self->{'server'} eq 'junoscript') {
        eval 'require JUNOS::Device';
        if ($@) {
            croak 'Error: ' . $@;
        }
        $device = new JUNOS::Device(%args);
    } else { # Netconf session
        eval 'require Net::Netconf::Device';
        if ($@) {
            croak 'Error: ' . $@;
        }
        $device = new Net::Netconf::Device(%args);
    }
    $device;
}

1;

__END__

=head1 NAME

Net::Netconf::Manager

=head1 SYNOPSIS

The Net::Netconf::Manager module instantiates a JUNOSCript device or a Netconf
device based on which 'server' is requested. Default is 'netconf'.

=head1 DESCRIPTION

The Net::Netconf::Manager module instantiates and returns a JUNOScript device or
a Netconf device based on which 'server; is requested for. The 'server' can take
the values 'junoscript' or 'netconf'. The default value is 'netconf'.

=head1 EXAMPLE

This example connects to a Netconf server, locks the candidate database, updates
the router's configuration, commits the changes and closes the Netconf session.
It also does error handling.

    use Net::Netconf::Manager;

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
      'private_keyfile' => 'private_keyfile',
      'public_keyfile' => 'public_keyfile',
      'access' => 'ssh',
      'server' => 'netconf',
      'command' => 'junoscript netconf',
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

    my $device = new Net::Netconf::Manager(%deviceargs);
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

The constructor accepts a hash table %ARGS. It looks at the 'server' key and
instantiates either:

=over 4

=item JUNOScript device

if the 'server' value is 'junoscript.

=item Netconf device

if the 'server' value is 'netconf'.

=back

=head1 SEE ALSO

=over 4

=item *

Net::Netconf::Device

=item *

Net::Netconf::Access

=item *

Net::Netconf::Access::ssh

=back

=head1 AUTHOR

Juniper Networks Perl Team, send bug reports, hints, tips and suggestions to
netconf-support@juniper.net.

