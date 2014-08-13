# child of Access

package Net::Netconf::Access::ssh;

use Expect;
use Net::Netconf::Trace;
use Net::Netconf::Access;
use Net::Netconf::Constants;
use Carp;
use File::Which;
our $VERSION ='0.01';

use vars qw(@ISA);
@ISA = qw(Net::Netconf::Access);

sub disconnect
{
    my ($self) = shift;
    $self->{'ssh_obj'}->hard_close();
}

sub start
{
    my($self) = @_;
    my $sshprog;

    # Get ssh port number if it exists
    my $rport = (getservbyname('ssh', 'tcp'))[2];
    $rport = Net::Netconf::Constants::NC_DEFAULT_PORT unless ( defined $self->{'server'} && $self->{'server'} eq 'junoscript');

    $self->{'server'} = 'netconf' unless $self->{'server'};

    my $echostate = 'stty -echo;';
    if (exists($self->{'sshprog'})) {
        $sshprog = $self->{'sshprog'};
    } else {
        $sshprog = which('ssh');
        if (defined($sshprog) && ($sshprog ne '')) {
            chomp($sshprog);
        } else {
            croak "Could not find sshclient on the system";
        }
    }

    # This implementation assumes OpenSSH.
    my $command = $echostate . $sshprog . ' -l ' . 
                  $self->{'login'} . ' -p ' . $rport . 
                  ' -s ' . $self->{'hostname'} . 
                  ' ' . $self->{'server'};

    
    # take expect object from user ow build your own
    my $exp = new Expect unless ($self->{'exp_obj'});
    my $ssh=$exp->spawn($command);

    # Create the Expect object
    # my $ssh = Expect->spawn($command); 
    # Turn off logging to stdout
    $ssh->log_stdout(0);
    $ssh->log_file($self->out);

    # Send our password or passphrase
    if ($ssh->expect(10, 'password:', 'Password:', '(yes/no)?', '-re', 'passphrase.*:')) {
	my $m_num = $ssh->match_number();
	 
        SWITCH: {
	      if (($m_num == 1) || ($m_num == 2) || ($m_num == 4)) {
	          print $ssh "$self->{'password'}\r"; 
                  last SWITCH;
	      }
	      if ($m_num == 3) {
                  # Host-key authenticity.
                  print $ssh "yes\r";
	          if ($ssh->expect(10, 'password:', 'Password:', '-re', 'passphrase.*:')) {
		      print $ssh "$self->{'password'}\r";
	          } 
	          # After the yes/no option, expect the line: 'Warning: 
	          # Permanently added <....> to the list of known hosts.' 
	          $ssh->expect(10, 'known hosts.'); 
	          last SWITCH;
	      }
	} # SWITCH   
	# If password prompted second time, it means user has give invalid password
        if ($ssh->expect(10, 'password:', 'Password:', '-re', 'passphrase.*:'))
        {
            print "Failed to login to $self->{'hostname'}\n";
            $self->{'seen_eof'} = 1;
        }
    } 
    else {
	if ($ssh->expect(10, '-re', '<!(.*?)>')) {
	    # Things are good. Do nothing.
	} else {    
	    $self->{'seen_eof'} = 1;
	}
    }

    $self->{'ssh_obj'} = $ssh;
    $self;
}

sub send
{
    my ($self, $xml) = @_;
    my $ssh = $self->{'ssh_obj'};
    $xml .= ']]>]]>';
    print $ssh "$xml\r";
    1;
}

sub recv
{
    my $self = shift;
    my $xml;
    my $ssh = $self->{'ssh_obj'};
    if ($ssh->expect(600, ']]>]]>')) {
        $xml = $ssh->before() . $ssh->match();
    } else {
        print "Failed to login to $self->{'hostname'}\n";
        $self->{'seen_eof'} = 1;
    }
    $xml =~ s/]]>]]>//g;
    $xml;
}

sub out
{
    my $self = @_;
    foreach $line (@_) {
        if ($line =~ /Permission\ denied/) {
          print "Login failed: Permission Denied\n";
          $self->{'ssh_obj'}->hard_close();
          $self->{'seen_eof'} = 1;
        }
    }
}

1;

__END__

=head1 NAME

Net::Netconf::Access::ssh

=head1 SYNOPSIS

The Net::Netconf::Access::ssh module is used internally to provide ssh access to
a Net::Netconf::Access instance.

=head1 DESCRIPTION

This is a subclass of Net::Netconf::Access class that manages an ssh connection
with the destination host. The underlying mechanics for managing the ssh
connection is based on OpenSSH.

=head1 CONSTRUCTOR

new($ARGS)

Please refer to the constructor of Net::Netconf::Access class.

=head1 SEE ALSO

=over 4

=item *

Expect.pm

=item *

Net::Netconf::Access

=item *

Net::Netconf::Manager

=item *

Net::Netconf::Device

=back

=head1 AUTHOR

Juniper Networks Perl Team, send bug reports, hints, tips and suggestions to
netconf-support@juniper.net.

