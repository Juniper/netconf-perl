package Net::Netconf::Constants;

our $VERSION ='1.02';
# Netconf server: minimum version
use constant NC_VERS_MIN => 7.5;
# Constants pertaining to the Netconf states
use constant NC_STATE_DISCONN => 0;
use constant NC_STATE_CONN => 1;
use constant NC_STATE_HELLO_RECVD => 2;
use constant NC_STATE_HELLO_SENT => 3;
use constant NC_STATE_REQ_SENT => 4;
use constant NC_STATE_REQ_RECVD => 5;
use constant NC_DEFAULT_PORT => 830;

# Netconf tags of interest to us
use constant NC_HELLO_TAG => qq(hello);
use constant NC_REPLY_TAG => qq(rpc-reply);
use constant NC_DEFAULT_CAP => 
  qq(<capability>urn:ietf:params:xml:ns:netconf:base:1.0</capability>
  <capability>urn:ietf:params:xml:ns:netconf:base:1.0#candidate</capability>
  <capability>urn:ietf:params:xml:ns:netconf:base:1.0#confirmed-commit</capability>
  <capability>urn:ietf:params:xml:ns:netconf:base:1.0#validate</capability>
  <capability>urn:ietf:params:xml:ns:netconf:base:1.0#url?protocol=http,ftp,file</capability>);

1;


__END__

=head1 NAME

Net::Netconf::Constants

=head1 SNOPSIS

The Net::Netconf::Constants module declares all the Netconf constants.

=head1 SEE ALSO

=over 4

=item *

Net::Netconf::Manager

=item *

Net::Netconf:Device

=back

=head1 AUTHOR

Juniper Networks Perl Team, send bug reports, hints, tips and suggestions to
netconf-support@juniper.net
