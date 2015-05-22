package Net::Netconf::Trace;

use strict;
use Carp;
our $VERSION ='1.02';
use constant DEBUG_LEVEL => 1;
use constant TRACE_LEVEL => 2;
use constant INFO_LEVEL => 3;
use constant WARNING_LEVEL => 4;
use constant ERROR_LEVEL => 5;
use constant CRITICAL_LEVEL => 6;

sub new
{
    my($class, $level) = @_;
    my $self;

    $self->{'level'} = $level;
    $class = ref($class) || $class;

    bless $self, $class;
    $self;
}

sub trace
{
    my $self = shift;
    confess 'Usage: ' . __PACKAGE__ . '::trace <level> <message>' 
    unless @_ == 2;
    my ($level, $msg) = @_;
    if ($level >= $self->{'level'}) {
        $msg .= "\n" unless $msg =~ /\n$/;
        print $msg;
    }
}

1;

__END__

=head1 NAME

Net::Netconf::Trace

=head1 SYNOPSIS

The Net::Netconf::Trace module provices tracing levels and enables tracing based
on the requested debug level.

=head1 DESCRIPTION

The Net::Netconf::Trace module provides the following tracing levels:

=over 4

=item *

DEBUG_LEVEL = 1

=item *

TRACE_LEVEL = 2

=item *

INFO_LEVEL = 3

=item *

WARNING_LEVEL = 4

=item *

ERROR_LEVEL = 5

=item *

CRITICAL_LEVEL = 6

=back

The trace level is set when instantiating a Net::Netconf::Trace object.

=head1 CONSTRUCTOR

new($level)

It takes a single argument - the trace level.

=head1 METHODS

=over 4

=item trace()

This takes two arguments, the trace level and the message. The message is
displayed on STDOUT only if level is greater than the trace level selected.

=back

=head1 SEE ALSO

=head1 AUTHOR

Juniper Networks Perl Team, send bug reports, hints, tips and suggestions to
netconf-support@juniper.net
