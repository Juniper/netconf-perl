package Net::Netconf::SAXHandler;

use strict;
use Carp;
our $VERSION ='1.02';

use base qw(XML::SAX::Base);

sub attlist_decl
{
    my $self = shift;
}

sub ignorable_whitespace
{
    my $self = shift;
}

sub start_document
{
    my ($self) = shift;
}

sub end_document
{
    my ($self) = shift;
}

sub comment
{
    my $self=shift;
}

#change %rpc_errors = undef into %rpc_errors=()
#overriding start_element class of handler
sub start_element
{
    my($self, $data) = @_;
    if ($data->{'LocalName'} eq 'hello') {
       $self->{'seen_hello'} = 1;
    } elsif ($data->{'LocalName'} eq 'package-information') {
        $self->{'get_pkg'} = 1;
    } elsif ($self->{'get_pkg'} && ($data->{'LocalName'} eq 'comment')) {
        $self->{'get_junos_ver'} = 1;
    } elsif ($data->{'LocalName'} eq 'rpc-reply') {
        $self->{'found_error'} = 0;
        $self->{'no_error'} = 0;
        $self->{'rpc_errors'} = ();
    } elsif ($data->{'LocalName'} eq 'capability') {
        $self->{'add_capability'} = 1;
    } elsif (($data->{'LocalName'} eq 'session-id') 
             && ($self->{'seen_hello'})) {
        $self->{'get_session_id'} = 1;
    } elsif ($data->{'LocalName'} eq 'rpc-error') {
	$self->{'found_error'}++;
        $self->{'get_error'} = 1;
    } elsif ($data->{'LocalName'} eq 'ok') {
        $self->{'no_error'} = 1;
    } elsif ($self->{'get_error'}) {
        # Insert this field into the hash
        $self->{'capture_error'} = $data->{'LocalName'};
    }
   $self->SUPER::start_element($data);
}

sub end_element
{
    my ($self, $data) = @_;
    if ($data->{'LocalName'} eq 'capability') {
        if ($self->{'current_cap'}) {
            push @{$self->{'parsed_cap'}}, $self->{'current_cap'};
            undef $self->{'current_cap'};
        }
        $self->{'add_capability'} = 0;
    } elsif (($data->{'LocalName'} eq 'session-id') 
             && ($self->{'get_session_id'})) {
        $self->{'seen_hello'} = 0;
        $self->{'get_session_id'} = 0;
    } elsif ($data->{'LocalName'} eq 'package-information') {
        $self->{'get_pkg'} = 0;
        $self->{'get_junos_ver'} = 0;
    } elsif ($data->{'LocalName'} eq 'rpc-error') {
        $self->{'get_error'} = 0;
        $self->{'capture_error'} = undef;
    }     
    $self->SUPER::end_element($data);
}

sub characters
{
    my ($self, $data) = @_;
    if ($self->{'add_capability'} && $data->{'Data'} =~ /\S/) {
        my $capability = $data->{'Data'};
        my $cap_urn;
        ($cap_urn,) = split(/\?/, $capability) if ($capability);
        $capability = $cap_urn;
        $self->{'current_cap'} .= $capability;
    } elsif ($self->{'get_session_id'}) {
        if ($data->{'Data'} =~ /\S/) {
            $self->{'session_id'} = $data->{'Data'};
        }
    } elsif ($self->{'get_pkg'} && $self->{'get_junos_ver'}) {
        if ($data->{'Data'} =~ /JUNOS Base OS/) {
            my @comment;
            @comment = split(/\[/, $data->{'Data'});
            $self->{'junos_version'} = $comment[1];
            $self->{'junos_version'} = substr($self->{'junos_version'}, 0, 3);
        }
    } elsif ($self->{'get_error'}) { #Get the error value
        if ($data->{'Data'} =~ /\S/) {
            $self->{'capture_error'} =~ s/-/_/gs;
            $self->{'rpc_errors'}{$self->{'found_error'}}{$self->{'capture_error'}}=$data->{'Data'};
        }
    }
    $self->SUPER::characters($data);
}

sub fatal_error
{
    my ($self) = shift;
    carp 'Parser FATAL ERROR: ' . @_ . "\n";
}

sub error
{
    my ($self) = shift;
    carp 'Parser ERROR: ' . @_ . "\n";
}

sub warning
{
    my ($self) = shift;
    carp 'Parser WARNING: ' . @_ . "\n";
}

sub parse
{
    my ($self, $data) = @_;
    eval {
        if (ref($data)) {
            $self->parse({'Source' => {'ByteStream' => $data}});
        } else {
            $self->parse({'Source' => {'String' => $data}});
        }
    };
    if (@_) {
        carp 'Parser ERROR: ' . $@ . "\n";
    }
}

1;

__END__

=head1 NAME

Net::Netconf::SAXHandler

=head1 SYNOPSIS

The Net::Netconf::SAXHandler module is used to parse responses from a Netconf
server.

=head1 DESCRIPTION

The Net::Netconf::SAXHandler module is a SAX-based parser used to parse
responses from a Netconf server.

=head1 METHODS

Implements all SAX handles.

=head1 SEE ALSO

=over 4

=item *

Net::Netconf::Manager

=item *

Net::Netconf::Device

=back

=head1 AUTHOR

Juniper Networks Perl Team, send bug reports, hints, tips and suggestions to
netconf-support@juniper.net.
