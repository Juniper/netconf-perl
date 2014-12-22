package Net::Netconf::Access::ssh;

use Net::SSH2;
use Net::Netconf::Trace;
use Net::Netconf::Constants;
use Carp;

use parent 'Net::Netconf::Access';

our $VERSION = '1.00';

# Just for convenience
sub trace {
    my $self = shift;
    $self->{'trace_obj'}->trace(Net::Netconf::Trace::TRACE_LEVEL,
                                sprintf("[%s] %s", __PACKAGE__, @_));
}

# Initialises an Net::SSH2 object, connects and authenticates to the Netconf
# server. Net::SSH2 object is stored in $self->{'ssh2'}, channel in
# $self->{'chan'}.
sub start {
    my $self = shift;

    $self->{'server'} ||= 'netconf';

    my $port = ($self->{'server'} eq 'netconf') ?
               Net::Netconf::Constants::NC_DEFAULT_PORT :
               (getservbyname('ssh', 'tcp'))[2];

    my $ssh2 = Net::SSH2->new();
    croak "Failed to create a new Net::SSH2 object" unless(ref $ssh2);

    $self->trace("Making SSH connection to '$self->{'hostname'}:$port'...");
    $ssh2->connect($self->{'hostname'}, $port);
    croak "SSH connection failed: " . $ssh2->error() if($ssh2->error());
    $self->trace("SSH connection succeeded!");

    $self->trace("Performing SSH authentication");
    $ssh2->auth(username => $self->{'login'},
                password => $self->{'password'});
    croak "SSH authentication failed" if(!$ssh2->auth_ok() or $ssh2->error());
    $self->trace("Authentication succeeded!");

    $self->trace("Requesting SSH channel...");
    my $chan = $ssh2->channel();
    croak "Failed to create SSH channel" if(!ref $chan or $ssh2->error());
    $self->trace("Successfully created SSH channel!");

    $self->trace("Starting subsystem '$self->{'server'}'...");
    $chan->subsystem($self->{'server'})
        or croak "Failed to start subsystem '$self->{'server'}'";
    $self->trace("Successfully started subsystem!");

    $self->{'ssh2'} = $ssh2;
    $self->{'chan'} = $chan;
    return $self;
}

# Gracefully disconnect from Netconf server
sub disconnect {
    my $self = shift;

    my $ssh2 = $self->{'ssh2'};
    $ssh2->disconnect("Bye bye from $0 [" . __PACKAGE__ . " v$VERSION]");
    $self->trace("Disconnected from SSH server");

    undef $self;
}

# Writes an XML request to the Netconf server.
sub send {
    my ($self, $xml) = @_;

    $xml .= ']]>]]>';

    my $len = length($xml);

    $self->trace("Will write $len bytes to the SSH channel:");
    $self->trace("$xml");

    # Make the channel blocking, so the write() call below waits until there
    # is available buffer space. Otherwise we'll end up busy-looping.
    $self->{'chan'}->blocking(1);

    my $written = 0;
    while($written != $len) {
        my $nbytes = $self->{'chan'}->write($xml)
            or croak "Failed to write XML data to SSH channel!";
        $written += $nbytes;
        $self->trace("Wrote $nbytes bytes (total written: $written).");
        substr($xml, 0, $nbytes) = '';
    }
    $self->trace("Successfully wrote $written bytes to SSH channel!");
    return 1;
}

# Reads an XML reply from the Netconf server.
sub recv {
    my $self = shift;
    my $ssh2 = $self->{'ssh2'};
    my $chan = $self->{'chan'};

    # Make the channel non-blocking, so that read() below allows for partial
    # reads (as we can't possibly know if the data we're about to receive is an
    # exact multiple of the buffer size argument, and doing it one character at
    # a time instead would be terribly inefficient).
    $chan->blocking(0);

    $self->trace("Reading XML response from Netconf server...");
    my ($resp, $buf);
    do {
        # Wait up to 10 seconds for data to become available before attempting
        # to read anything (in order to avoid busy-looping on $chan->read())
        my @poll = ({ handle => $chan, events => 'in' });
        $ssh2->poll(10000, \@poll);

        $nbytes = $chan->read($buf, 65536) || 0;
        $self->trace("Read $nbytes bytes from SSH channel: '$buf'");
        $resp .= $buf;
    } until($resp =~ s/]]>]]>$//);
    $self->trace("Received XML response '$resp'");

    return $resp;
}

# Checks if the server sent us an EOF
sub eof {
    my $self = shift;
    return $self->{'chan'}->eof();
}

1;

__END__

=head1 NAME

Net::Netconf::Access::ssh

=head1 SYNOPSIS

The Net::Netconf::Access::ssh module is used internally to provide SSH access to
a Net::Netconf::Access instance, using Net::SSH2.

=head1 DESCRIPTION

This is a subclass of Net::Netconf::Access class that manages an SSH connection
with the destination host. The underlying mechanics for managing the SSH
connection is based on Net::SSH2.

=head1 CONSTRUCTOR

new($ARGS)

Please refer to the constructor of Net::Netconf::Access class.

=head1 SEE ALSO

=over 4

=item *

Net::SSH2

=item *

Net::SSH2::Channel

=item *

Net::Netconf::Access

=item *

Net::Netconf::Manager

=item *

Net::Netconf::Device

=back

=head1 AUTHOR

Tore Anderson <tore@redpill-linpro.com>

Net::Netconf is maintained by the Juniper Networks Perl Team, send bug reports,
hints, tips and suggestions to netconf-support@juniper.net.

# vim: syntax=perl tw=80 ts=4 et:
